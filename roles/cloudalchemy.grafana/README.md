# Ansible Role: Grafana

Grafana is an open-source platform for monitoring and observability. It allows you to query, visualize, alert on and understand your metrics no matter where they are stored. Create, explore, and share dashboards to foster a data-driven culture.

Full features are listed at; 

https://grafana.com/docs/grafana/latest/

This is the second part of the Prometheus stack, the intention being to also install and configure AlertManager for a complete monitoring, visualization and alerting solution. I will utilize the `import_role` directives via a **prometheus-stack.yml** file to load and run them in the correct order. 

I have chosen Ansible to deploy and configure this solution, rather than `docker-compose`, as I have no requirement for data persistence via Docker volumes.


## Description

Provision and manage Grafana for analytics and monitoring using `ansible-galaxy` and a quality role provided by cloudalchemy.

## Requirements
None - already actioned via the Prometheus role.

## Usage

Firstly, ensure Ansible comms are setup and functioning correctly between the Control Node of remote host - see the `Ansible Control Node - communications` section in the Ansible readme file in the main repository. Then we install the role to the roles/ directory with the `ansible-galaxy` command and use our main playbook (prometheus-stack.yml - created under the Prometheus role);

```
cd ~/ansible/
ansible-galaxy role install -p roles/ cloudalchemy.grafana

ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml
```

## Grafana Configuration

This configuration is handled by the following blocks within **defaults/main.yml**

```
# Datasources to configure
grafana_datasources:
  - name: "Prometheus"
    type: "prometheus"
    access: "proxy"
    url: "http://{{ ansible_host }}:9090"
    basicAuth: false

# Dashboards from https://grafana.com/dashboards - remember to check and amend the revision_id to the latest if required
grafana_dashboards:
  - dashboard_id: '1860'           # Node Exporter Full
    revision_id: '26'
    datasource: 'Prometheus'        

# Local directory on Ansible Control Node containing dashboards in json format
# Uploads to /var/lib/grafana/dashboards on Prometheus host
grafana_dashboards_dir: "/home/$USER/ansible/roles/cloudalchemy.grafana/files/json-dashboards"
```
The last option requires a manual directory creation on your local Ansible Control Node via `mkdir ~/ansible/roles/cloudalchemy.grafana/files/json-dashboards` - you may want to add a `.gitkeep` file here to create the directory placeholder on first commit, in the absence of any custom dashboards.


## Role Variables

All variables which can be overridden are stored in **defaults/main.yml** and explained within https://galaxy.ansible.com/cloudalchemy/grafana

Recommended to backup first `cp main.yml main.yml.bak` - notable changes made via our prometheus-stack.yml playbook `vars:`

- grafana_version: latest



## Additional Code - UFW

The Ubuntu Server 20.04 LTS VMs are preconfigured and locked down via Packer and Ansible, so will require the following additional code to reach the web interface.

`tasks/configure.yml`
```
# ansible -i ~/ansible/inventory.ini all -m setup -a "filter=ansible_distribution"
- name: configure ufw rules to allow web access
  ufw: rule={{ item.rule }} port={{ item.port }} proto={{ item.proto }}
  with_items:
    - { rule: 'allow', port: 3000, proto: 'tcp' }
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

## Additional Code - TLS 

Adapt the `grafana_datasources:` block to ensure we connect to our Prometheus datasource via https;

`defaults/main.yml`
```
url: "https://{{ ansible_host }}:9090"
    jsonData:
      tlsAuth: false
      tlsAuthWithCACert: false
      tlsSkipVerify: true
```
After re-running `prometheus-stack.yml` we can test via the `Test` button on the datasources page in the UI.


## Troubleshooting
```
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --syntax-check
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --check 
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --vvvv
sudo ufw status numbered
```
