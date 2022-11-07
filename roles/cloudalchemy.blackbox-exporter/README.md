# Ansible Role: Blackbox Exporter

The Blackbox exporter is a tool that allows you to monitor HTTP, DNS, TCP and ICMP endpoints. Results can be visualized in modern dashboard tools such as Grafana.

Normal use case - run on the Prometheus nodes alongside Prometheus, Grafana and AlertManager. However, the Blackbox exporter is a standalone tool.

It provides metrics about HTTP latencies, DNS lookup latencies as well as statistics about SSL certificates expiration.

The best usage of Blackbox exporter is to monitor the expiry of your public SSL certs. As such, the blackbox.yml http module has been tailored to probe these metrics from the public VIP endpoints.

Full features are listed at; 

https://github.com/prometheus/blackbox_exporter

The intention of this role is to compliment the existing Prometheus stack - a complete monitoring, visualization and alerting solution. I will utilize the `import_role` directives via a **prometheus-stack.yml** file to load and run them in the correct order. 

I have chosen Ansible to deploy and configure this solution, rather than `docker-compose`, as I have no requirement for data persistence via Docker volumes.


## Description

Provision and manage Blackbox exporter for analytics and monitoring using `ansible-galaxy` and a quality role provided by cloudalchemy.

## Requirements

None.

## Usage

Firstly, ensure Ansible comms are setup and functioning correctly between the Control Node of remote host - see the `Ansible Control Node - communications` section in the Ansible readme file in the main repository. Then we install the role to the roles/ directory with the `ansible-galaxy` command and use our main playbook - prometheus-stack.yml;

```
cd ~/ansible/
ansible-galaxy role install -p roles/ cloudalchemy.blackbox-exporter

ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml
```

## Blackbox exporter Configuration

This configuration is handled within **defaults/main.yml** where we add our module and target endpoints.


## Role Variables

All variables which can be overridden are stored in **defaults/main.yml** and explained within https://galaxy.ansible.com/cloudalchemy/blackbox-exporter

Recommended to backup first `cp main.yml main.yml.bak` - notable changes made via our prometheus-stack.yml playbook `vars:`

- blackbox_exporter_version: latest


## Testing and Debugging

Curl the local Blackbox port with the probe target and module to use - these examples probe our local Prometheus instance, then one of our own internal https endpoints, then a random public one;

```
curl -s "localhost:9115/probe?target=https://www.prometheus.io/&module=http_2xx"
curl -s "localhost:9115/probe?target=https://php-ipam-prd-01.int.mycompany.com&module=http_2xx"
curl -s "localhost:9115/probe?target=https://www.sportbusiness.com/&module=http_2xx"
```

Adding **debug=true** to our curl command will output much more interesting content, under three sections;

- Logs for the probe:
- Metrics that would have been returned:
- Module configuration:

These probe connection logs, endpoint metrics and local module configuration are helpful in shaping the http module whilst writing it (to identify probe failures etc) - or for general analysis of any http(s) endpoints;

```
curl -s "localhost:9115/probe?debug=true&target=https://jenkins-prd-01.int.mycompany.com&module=http_2xx"
curl -s "localhost:9115/probe?debug=true&target=https://www.cnn.com&module=http_2xx"
```
Note that the **debug=true** cli option must be enabled in this Ansible Galaxy role configuration - within **defaults/main.yml** and the `blackbox_exporter_cli_flags: {}` block.


## General Troubleshooting
```
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --syntax-check
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --check 
ansible-playbook -i ~/ansible/inventory.ini prometheus-stack.yml --vvvv

systemctl status blackbox_exporter
journalctl -xn -u blackbox_exporter
```

## Grafana Dashboard

I have added the following Grafana dashboard to visualize all HTTP and DNS latencies as well as the all important SSL certificate expiration data;

```
grafana_dashboards:
  - dashboard_id: '14928'          # Prometheus Blackbox Exporter
    revision_id: '6'
    datasource: 'Prometheus'
```
