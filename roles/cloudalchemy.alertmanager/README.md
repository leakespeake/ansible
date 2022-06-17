# Ansible Role: Alertmanager

The Alertmanager handles alerts sent by client applications such as the Prometheus server. It takes care of deduplicating, grouping, and routing them to the correct receiver integration such as email or Slack. It also takes care of silencing and inhibition of alerts. Full features are listed at;

https://prometheus.io/docs/alerting/latest/alertmanager/

This is the third and final part of the Prometheus stack, comprising Prometheus, Grafana and AlertManager for a complete monitoring, visualization and alerting solution. I will utilize the `import_role` directives via a **prometheus-stack.yml** file to load and run them in the correct order.

I have chosen Ansible to deploy and configure this solution, rather than `docker-compose`, as I have no requirement for data persistence via Docker volumes.

## Description

Deploy and manage Prometheus Alertmanager using ansible-galaxy and a quality role provided by cloudalchemy.

## Requirements

None - already actioned via the Prometheus role.

## Usage

Firstly, ensure Ansible comms are setup and functioning correctly between the Control Node of remote host - see the Ansible Control Node - communications section in the Ansible readme file in the main repository. Then we install the role to the roles/ directory with the ansible-galaxy command and use our main playbook (prometheus-stack.yml - created under the Prometheus role);

```
cd ~/ansible/
ansible-galaxy role install -p roles/ cloudalchemy.alertmanager

ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml
```

## Prometheus Configuration Dependency

Firstly, we should note the configuration that must be added to the Prometheus role - the following added to `vars:` in ****prometheus-stack.yml****

```
prometheus_alertmanager_config:
  - scheme: http
    static_configs:
      - targets: ["localhost:9093"]
```
Also note **defaults/main.yml** in the Prometheus role will conatin the `prometheus_alert_rules:` where we can add new rules or amend existing ones to conform to the Alertmanager route configuration - such as adding an additional label like `email: true` 

## Alertmanager Configuration

The Alertmanager configuration is handled by the code blocks within **defaults/main.yml** although see **prometheus-stack.yml** as we will overide many of them here with the salient parts such as;

alertmanager_receivers: (the notification receiver configuration - in this case the smtp smarthost and email credentials for authentication)
alertmanager_route: (define the notification receiver to use and the alerting parameters under which it will be sent)

When a rule threshold is breached, Prometheus will register the alert in a "pending" state before moving to a "firing" state. At this point the alert will be sent to Alertmanager and appear there with its associated labels. Alertmanager will then pass the alert to the configured receiver via the specified route.

Since this particular setup uses email and associated authentication creds, it isn't recommended you use your personal password for security. Instead you'll need an app password created for this use.

## App Passwords

An app password is a long, randomly generated password that you provide only once instead of your regular password when signing in to an app or device that doesn't support two-step verification. Consult your email providers own setup details for this.

## Role Variables

All variables which can be overridden are stored in **defaults/main.yml** and explained within https://galaxy.ansible.com/cloudalchemy/alertmanager

Recommended to backup first `cp main.yml main.yml.bak` - notable changes made via our prometheus-stack.yml playbook vars:

alertmanager_version: latest
alertmanager_receivers:
alertmanager_route:

## Additional Code

The Ubuntu Server 20.04 LTS VMs are preconfigured and locked down via Packer and Ansible, so will require the following additional code to reach the web interface.

`tasks/configure.yml`
```
# ansible -i ~/ansible/inventory.ini all -m setup -a "filter=ansible_distribution"
- name: configure ufw rules to allow web access
  ufw: rule={{ item.rule }} port={{ item.port }} proto={{ item.proto }}
  with_items:
    - { rule: 'allow', port: 9093, proto: 'tcp' }
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

## Troubleshooting
```
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --syntax-check
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --check 
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --vvvv
```