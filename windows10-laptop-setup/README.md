# Windows 10 Laptop Setup

WORK IN PROGRESS...

The purpose of this Ansible project is to locally automate (as much as possible) the software installation, updates and configuration for my Windows 10 development laptop and covers the following 2 environments;

- Windows 10 Home (OS)
- Ubuntu 20.04 (WSL2)

This will become useful to re-create my development environment in the event that I switch to or use additional hardware. It also serves as an interesting project for local automation, as the majority in this Ansible repo will involve remote connections.

---
# VERSIONS

 - Ansible 2.9                  # ansible --version
 - Python 3.8                   # ansible --version
 - Powershell 5.1               # $PSVersionTable
 - .NET Framework 4.8           # reg query "HKLM\SOFTWARE\Microsoft\Net Framework Setup\NDP" /s

---
# CONTENT

- **01-setup-win10.ps1** --> setup WinRM for Ansible comms > enable WSL2 and Virtual Machine Platform > reboot
- **02-setup-win10.ps1** --> download and install the WSL2 kernel update > set default version of WSL to 2 > install the WSL2 Ubuntu distro
- **03-setup-ubuntu.sh** --> update & upgrade packages > install Ansible, pip and pywinrm > update /etc/hosts
- **04-configure-ubuntu.yml** --> install personal essential packages (apt) > install the ansible.windows plugin collection
- **05-configure-win10.yml** --> install personal essential packages (Chocolatey) > configure Powershell profile and environment variables > configure system paths
- **06-configure-ubuntu.yml** --> amend ~/.bashrc > import dotfiles > import /etc configuration files
- **07-site-yml** --> use the import_playbook directive to run the seperate playbooks back-to-back

---
# USAGE

The static nature of this project doesn't lend itself to the use of {{ ansible.variables }} or roles - however, we can use the **import_playbook** directive to run the seperate playbooks back-to-back.

01-
02-
./03-setup-ubuntu.sh
ansible-playbook 04-configure-ubuntu.yml -i hosts --ask-become-pass --verbose
ansible-playbook 05-configure-win10.yml -i hosts --ask-become-pass --verbose
ansible-playbook 06-configure-ubuntu.yml -i hosts --ask-become-pass --verbose
ansible-playbook 07-site.yml -i hosts --ask-become-pass --verbose

---
# WinRM 

The Ansible control node running in WSL2 will use the WinRM management protocol to communicate with the Windows OS. Ansible uses the **pywinrm** package to do this. There are several authentication options that utilize certificates, but I have chosen the simplist method - basic authentication using HTTP - reason being that all comms are local and use local accounts.

```
winrm quickconfig
winrm set winrm/config/service/auth @{Basic="true"}
```
This method also automatically opens the firewall ports and starts the WinRM service.


---
# /etc/hosts

We will create 2 seperate hostnames for localhost in /etc/hosts using the **lineinfile** module - one for Windows and the other for WSL2. This is because they use different **ansible_connection** methods, so this will allow us to target either one for particular tasks when we run a playbook. It also allows us to utilize a single hosts inventory file. Test each via;

```
ansible -i hosts -m ping wsl2
ansible -i hosts -m win_ping windows
```

