# Windows 10 Laptop Setup

WORK IN PROGRESS...

The purpose of this Ansible project is to locally automate (as much as possible) the software installation, updates and configuration for my Windows 10 development laptop and covers the following 2 environments;

- Windows 10 Home (OS)
- Ubuntu 20.04 (WSL2)

This will become useful to re-create my dev environment in the event that I switch to or use additional hardware. It also serves as an interesting project for local automation, as the majority in this Ansible repo will involve remote connections.

# VERSIONS

 - Ansible 2.9                  # ansible --version
 - Python 3.8                   # ansible --version
 - Powershell 5.1               # $PSVersionTable
 - .NET Framework 4.8           # reg query "HKLM\SOFTWARE\Microsoft\Net Framework Setup\NDP" /s

# CONTENT

- **01-setup-win10.ps1** --> setup WinRM for Ansible comms > enable WSL2 and Virtual Machine Platform > reboot
- **02-setup-win10.ps1** --> download and install the WSL2 kernel update > set default version of WSL to 2 > install the WSL2 Ubuntu distro
- **03-setup-ubuntu.sh** --> update & upgrade packages > install pip, Ansible and pywinrm > update /etc/hosts
- **04-configure-ubuntu.yml** --> install personal essential packages (apt) > install the ansible.windows plugin collection
- **05-configure-win10.yml** --> install personal essential packages (Chocolatey) > configure Powershell profile and environment variables > configure system paths
- **06-configure-ubuntu.yml** --> amend ~/.bashrc > import dotfiles > import /etc configuration files
- **07-site-yml** --> use the import_playbook directive to run all playbooks sequentially

# USAGE

The static nature of this project doesn't lend itself to the use of {{ ansible.variables }} or roles - however, we can use the **import_playbook** directive to run the seperate playbooks back-to-back. Powershell scripts can be tested by appending **-WhatIf** and likewise **--check** for the playbooks. 

.\01-setup-win10.ps1

.\02-setup-win10.ps1

./03-setup-ubuntu.sh

ansible-playbook 07-site.yml -i hosts --ask-become-pass --verbose

# WinRM 

The Ansible control node running in WSL2 will use the WinRM management protocol to communicate with the Windows OS. Ansible uses the **pywinrm** package to do this. There are several authentication options that utilize certificates, but I have chosen the simplist method - basic authentication with HTTP - reason being that all comms are local and use local accounts.

# /etc/hosts

We will create 2 seperate hostnames for localhost (127.0.0.1) in /etc/hosts, one for 'windows' and the other for 'wsl2' via **03-setup-ubuntu.sh** - this is because they use different local connection methods;

```
[windows:vars]
ansible_connection=winrm

[wsl2:vars]
ansible_connection=local
```

This will allow us to target either one for a particular PLAY when we run a playbook - i.e. **hosts: windows** or **hosts: wsl2** - it also allows us to utilize a single hosts inventory file. Test each one via;

```
ansible -i hosts -m ping wsl2
ansible -i hosts -m win_ping windows
```