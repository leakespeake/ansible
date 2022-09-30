<p><img src="https://cdn.worldvectorlogo.com/logos/prometheus.svg" alt="prometheus logo" title="prometheus" align="right" height="60" /></p>

# Ansible Role: Prometheus

Prometheus is an open-source, community driven, systems monitoring and alerting toolkit. It collects and stores its metrics as time series data, i.e. metrics information is stored with the timestamp at which it was recorded, alongside optional key-value pairs called labels. Additional features are listed at; 

https://prometheus.io/docs/introduction/overview/

This is the first part of the Prometheus stack, the intention being to also install and configure Grafana and AlertManager for a complete monitoring, visualization and alerting solution. I will utilize the `import_role` directives via a **prometheus-stack.yml** file to load and run them in the correct order. 

I have chosen Ansible to deploy and configure this solution, rather than `docker-compose`, as I have no requirement for data persistence via Docker volumes.


## Description

Deploy [Prometheus](https://github.com/prometheus/prometheus) monitoring system using `ansible-galaxy` and a quality role provided by cloudalchemy.

## Requirements
```
sudo apt-get install python3-jmespath
```

## Usage

Firstly, ensure Ansible comms are setup and functioning correctly between the Control Node of remote host - see the `Ansible Control Node - communications` section in the Ansible readme file in the main repository. Then we install the role to the roles/ directory with the `ansible-galaxy` command and create our main playbook;

```
cd ~/ansible/
ansible-galaxy role install -p roles/ cloudalchemy.prometheus
touch prometheus-stack.yml

ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml
```

## Target and Scrape Configuration

This configuration is handled by the following 2 blocks within **defaults/main.yml** - this method uses file-based service discovery (file_sd) as opposed to using an external source such as Consul.

- prometheus_targets:
This configuration is a map, used to create multiple .yml files for each individual target, located in **{{ prometheus_config_dir }}/file_sd** - anything set here must be mapped to `prometheus_scrape_configs` otherwise there will be an error in the preflight checks

- prometheus_scrape_configs:
This configuration loads the .yml file created from `prometheus_targets`


## Role Variables

All variables which can be overridden are stored in **defaults/main.yml** and explained within https://galaxy.ansible.com/cloudalchemy/prometheus

Recommended to backup first `cp main.yml main.yml.bak` - notable changes made via our prometheus-stack.yml playbook `vars:`

- prometheus_version: 2.34.0 (or state "latest")
- prometheus_storage_retention: "15d" (changed from "30d")
- prometheus_web_external_url: "http://{{ ansible_host }}:9090" (add a fully qualified URL)


## Additional Code - UFW

The Ubuntu Server 20.04 LTS VMs are preconfigured and locked down via Packer and Ansible, so will require the following additional code to reach the web interface.

`tasks/configure.yml`
```
# ansible -i ~/ansible/inventory.ini all -m setup -a "filter=ansible_distribution"
- name: configure ufw rules to allow web access
  ufw: rule={{ item.rule }} port={{ item.port }} proto={{ item.proto }}
  with_items:
    - { rule: 'allow', port: 9090, proto: 'tcp' }
  when: ansible_facts['distribution'] == 'Ubuntu'
  notify:
    - restart ufw
```
`handlers/main.yml`
```
- name: restart ufw
  service:
    name: ufw
    state: restarted
```
Also note that Prometheus did not have any built-in security features in the past, however, basic authentication and TLS were added in version 2.24.0 to secure the API and UI endpoints - more information at https://prometheus.io/docs/guides/basic-auth/

## Additional Code - TLS 

Prometheus supports Transport Layer Security (TLS) encryption for connections to Prometheus instances. The following assumes you already have a full chain certificate and private key files. Couple of mandatory manual steps involved here;

- create a **files/** folder in the Prometheus role directory to use with the Ansible **copy** feature (Ansible will automatically use `files/` to look for filenames stated with `src:`)
- create **web-config.yml** inside the `files/` folder - with this configuration, Prometheus will serve all its endpoints behind TLS

Then adapt the existing code to include;

`prometheus-stack.yml`
```
prometheus_web_external_url: "https://{{ ansible_host }}:9090"
```
`defaults/main.yml`
```
prometheus_web_config_file: "{{ prometheus_config_dir }}/web-config.yml"
```
`templates/prometheus.service.j2`
```
--web.config.file={{ prometheus_web_config_file }} \
```
`tasks/preflight.yml`
```
- prometheus_config_flags_extra['web.config.file'] is not defined
- 'web.config.file'
```
`tasks/install.yml`
```
- name: copy web configuration for TLS encryption
  copy:
    src: web-config.yml
    dest: "{{ prometheus_config_dir }}"
    owner: root
    group: prometheus
    mode: 0644
  notify:
    - restart prometheus
```
After re-running `prometheus-stack.yml` we can test via `curl -v https://localhost:9090`

## Troubleshooting
```
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --syntax-check
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --check 
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --vvvv
sudo ufw status numbered
```
