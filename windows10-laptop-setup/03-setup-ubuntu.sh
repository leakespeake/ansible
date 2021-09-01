#!/bin/bash -ex

# This shell script is intended to prep the Ubuntu WSL2 environment to run the Ansible control node ops.
# It will also prep the system to start Docker on boot - required as WSL2 doesn't run systemd and no 'enable' equivalent for /etc/init.d
# Debugging options; sudo tail -f $HOME/log.out - or - sudo cat $HOME/log.out

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$HOME/log.out 2>&1

echo "UPDATE AND UPGRADE"
sudo apt update && sudo apt -y upgrade

sleep 10

echo "INSTALL ANSIBLE"
sudo apt install python3-pip -y
sudo pip install ansible "pywinrm>=0.3.0"

echo "REMOVE LOCAL WINDOWS IP IN /ETC/HOSTS IF PRE-EXISTING"
echo '' >> ~/.bashrc
echo '# Remove local windows IP in /etc/hosts (if pre-existing) prior to dynamic assignment.' >> ~/.bashrc
echo "sudo sed '/windows/d' -i /etc/hosts" >> ~/.bashrc
echo '' >> ~/.bashrc

echo "UPDATE SYSTEM HOSTS FILE (WINDOWS) - WILL PERSIST DUE TO WSL.CONF NETWORK SETTINGS"
echo '# Dymanically add the IP assigned to Ethernet adapter vEthernet (WSL) into /etc/hosts.' >> ~/.bashrc
echo '# Allows WinRM port connection from Ubuntu/WSL2 to Windows localhost.' >> ~/.bashrc
cat <<EOT >> ~/.bashrc
export windows=$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')
if [ ! -n "$(grep -P "[[:space:]]windows" /etc/hosts)" ]; then
        printf "%s\t%s\n" "$windows" "windows        windows.local" | sudo tee -a "/etc/hosts"
fi
EOT

echo "UPDATE SYSTEM HOSTS FILE (WSL2) - WILL PERSIST DUE TO WSL.CONF NETWORK SETTINGS"
echo "127.0.0.1       wsl2           wsl2.local" | sudo tee --append /etc/hosts

echo "PREP UBUNTU TO START DOCKER ON BOOT"
echo '' >> ~/.bashrc
echo '# Start Docker daemon automatically when logging in if not running.' >> ~/.bashrc
echo 'RUNNING=`ps aux | grep dockerd | grep -v grep`' >> ~/.bashrc
echo 'if [ -z "$RUNNING" ]; then' >> ~/.bashrc
echo '    sudo dockerd > /dev/null 2>&1 &' >> ~/.bashrc
echo '    disown' >> ~/.bashrc
echo 'fi' >> ~/.bashrc