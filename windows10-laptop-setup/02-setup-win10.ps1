# Launch Powershell as Administrator prior to running script

# Source location of WSL2 kernel update
$source = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
# Destination to save the WSL2 kernel update
$destination = 'C:\Users\barry\Downloads\wsl_update_x64.msi'
# Download the WSL2 kernel update
Invoke-WebRequest -Uri $source -OutFile $destination

# Install the WSL2 kernel update - check if still required for your OS version via: Get-ComputerInfo OsName,OsVersion,OsBuildNumber,WindowsVersion
cd C:\Users\barry\Downloads
msiexec /package wsl_upate_x64.msi /quiet

# Set the WSL default version
wsl --set-default-version 2

# Install the WSL2 distro
Invoke-WebRequest -Uri https://aka.ms/wslubuntu2004 -OutFile Ubuntu.appx -UseBasicParsing
Add-AppxPackage .\Ubuntu.appx