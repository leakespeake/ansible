#!/bin/bash -ex

# This shell script is intended to prep the Ubuntu WSL2 environment to run the Ansible control node ops.
# Debugging options; sudo tail -f /home/ubuntu/log.out - or - sudo cat /home/ubuntu/log.out

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/ubuntu/log.out 2>&1

echo "UPDATE AND UPGRADE"
sudo apt update && sudo apt -y upgrade

sleep 10

echo "INSTALL ANSIBLE"
sudo apt install python-pip -y
sudo pip install ansible "pywinrm>=0.3.0"

echo "UPDATE SYSTEM HOSTS FILE"
echo "127.0.0.1 windows.local windows" | sudo tee -a /etc/hosts
echo "127.0.0.1 wsl2.local wsl2" | sudo tee -a /etc/hosts