# Prometheus Node Exporter role

The Prometheus Node Exporter exposes a variety of hardware and kernel related metrics that Prometheus can scrape from.

The purpose of this Ansible role is to automate the install of the Prometheus Node Exporter. The skeleton directory structure for this role was created with Ansible Galaxy;

```
ansible-galaxy role init node-exporter
```
The role has been fully tested on Ubuntu Server 20.04 LTS. Most of the tasks are self documenting in the main.yaml files but the saliant parts are;

- add the Node Exporter service user and group
- use the stat module to determine if Node Exporter is already installed and register result to **prometheus_node_exporter_install_path.stat**
- use the **when** directive to ensure the download and install tasks only run when **not prometheus_node_exporter_install_path.stat.exists**
- create a symbolic link for /opt/node_exporter
- use the service template file to install Node Exporter as a service / unit within systemd
- ensure node exporter is started and enabled on boot

Node Exporter is installed to **/opt** since this is the ideal location for pre-packaged third party software - although **/usr/local/bin** is still fine.

## Usage
Normally loaded from **site.yml** - otherwise use the following;
```
ssh-copy-id -i ~/.ssh/id_rsa.pub username@fqdn
ansible -i ~/ansible/inventory.ini ubuntu_20_04_prd -m ping
ansible-playbook -i ~/ansible/inventory.ini -u ubuntu --ask-become-pass node-exporter.yml
```

## Troubleshooting
```
systemctl status node_exporter 

curl http://localhost:9100/metrics
```