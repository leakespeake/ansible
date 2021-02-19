# Launch Powershell as Administrator prior to running script

# Setup WinRM for Ansible comms - automatically opens the firewall ports and starts the WinRM service
Enable-PSRemoting
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true


# Enable WSL2 and Virtual Machine Platform then reboot
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Restart-Computer