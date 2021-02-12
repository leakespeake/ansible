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

- **win10-host-setup.ps1** --> 

---
# USAGE

winrm enumerate winrm/config/Listener