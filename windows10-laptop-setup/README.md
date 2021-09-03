# Windows 10 Laptop Setup

The purpose of this Ansible project is to locally automate the software installation, updates and configuration for my Windows 10 development laptop. This is useful in re-creating my dev environment should I re-install the OS or switch to additional hardware. It also serves as an interesting project for local automation, as the majority in this Ansible repo will involve remote connections. We cover the following 2 environments;

- Windows 10 Home (OS)
- Ubuntu 20.04 (WSL2)

## Versions

 - Ansible 2.9                  # ansible --version
 - Python 3.8                   # ansible --version
 - Powershell 5.1               # $PSVersionTable
 - .NET Framework 4.8           # reg query "HKLM\SOFTWARE\Microsoft\Net Framework Setup\NDP" /s

## Content

You can use **git clone git@github.com:leakespeake/ansible.git** from your desired Windows/Powershell and WSL2/Ubuntu directories then utilise the scripts applicable for each environment (numbered by order) - which are; 

- **01-setup-win10.ps1** --> setup WinRM to accept comms from Ansible > enable WSL2 and Virtual Machine Platform features > reboot
- **02-setup-win10.ps1** --> download then install the WSL2 kernel update > set default version of WSL to 2 > install the WSL2 Ubuntu distro
- **03-setup-ubuntu.sh** --> update & upgrade packages > install pip, Ansible and pywinrm > update /etc/hosts with entries for 'windows' and 'wsl2' > prep Ubuntu to have Docker start on boot (required here as systemd doesn't run under WSL2 Ubuntu)
- **04-configure-ubuntu.yml** --> install favourite base packages with apt > add Docker stable repository > install Docker CE > add user to docker group to avoid use of sudo
- **05-configure-win10-winrm.ps1** --> configure the WinRM service > install Chocolatey
- **06-configure-win10.yml** --> install favourite base packages with choco > show hidden system files and file extensions
- **07-configure-ubuntu.yml** --> add favourite aliases to ~/.bashrc > import dotfiles > import /etc configuration files
- **08-site-yml** --> option to use the 'import_playbook' directive to run all Ansible playbooks sequentially and back-to-back

Supporting files;

- **inventory** --> contains the 'windows' and 'wsl2' hosts (entered into /etc/hosts) and their Ansible connection method variables
- **wsl.conf** --> copy this file to **/etc** - controls the functionality of WSL, in this case it ensures /etc/hosts is not overwritten each time WSL launches

## Usage

Simply change into the 'windows10-laptop-setup' and run the applicable script. All shell, Powershell and Ansible playbook files are written to pull the current users username value for flexibility. It is assumed you are logged on with the accounts you intend to use day-to-day. In the case of Ubuntu, this should be the initial account you create at setup as this is added to sudoers by default.

Powershell scripts can be tested by appending **-WhatIf** and likewise **--check** for the playbooks (or **-vvvv** for verbose output). Examples; 

```
.\01-setup-win10.ps1

./03-setup-ubuntu.sh

ansible-playbook -i /home/ubuntu/ansible/windows10-laptop-setup/inventory -u ubuntu --ask-become-pass 06-configure-win10.yml
```

## WinRM 

The Ansible control node running in WSL2 will use the WinRM management protocol to communicate with the Windows OS. Ansible uses the **pywinrm** package to do this. There are several authentication options and I have chosen the simplist - basic authentication with HTTPS - reason being that all comms are local and use local Windows accounts. When configuring WinRM to authenticate remotely and/or against a Windows domain, then certificates will be required.

Note the seperate local connection methods in our inventory file;

```
[windows:vars]
ansible_connection=winrm

[wsl2:vars]
ansible_connection=local
```

This allows us to target either one for a particular PLAY when we run a playbook - i.e. **hosts: windows** or **hosts: wsl2** - it also allows us to utilize a single inventory file. After the **03-setup-ubuntu.sh** shell script runs, cat /etc/hosts and make sure these hosts have been appended. Assuming we have cloned the ansible repo to our home directory - run ad-hoc tests for each one using their ping modules - via;

```
ansible -i $HOME/ansible/windows10-laptop-setup/inventory wsl2 -m ping
ansible -i $HOME/ansible/windows10-laptop-setup/inventory windows -m win_ping
```

## WinRM Troubleshooting (from WSL2)

```
curl -v {/etc/hosts windows IP}:5986
```

## WinRM Troubleshooting (from Windows)

```
telnet localhost 5986

winrm enumerate winrm/config/listener

winrm get winrm/config

winrs -r:http://127.0.0.1:5985/wsman -u:ansible -p:password ipconfig
```

## General Troubleshooting

```
choco list --localonly
```