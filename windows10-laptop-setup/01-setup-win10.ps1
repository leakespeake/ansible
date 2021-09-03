# Assumes execution policy has been changed from the default (restricted) to unrestricted - as per;
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted

# Launch Powershell as Administrator via UAC prompt
param([switch]$Elevated)
function Check-Admin {
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Check-Admin) -eq $false) {
if ($elevated)
{
# could not elevate, quit
}
else {
Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}
exit
} 

# Setup WinRM for local Ansible comms - automatically opens firewall ports and starts the WinRM service
# 'winrm quickconfig -force -quiet' is not required as 'Enable-PSRemoting' performs the same tasks and more!
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Set-Item -Force WSMan:\localhost\Client\Auth\Basic -Value $true
Set-Item -Force WSMan:\localhost\Client\TrustedHosts -Value '*'
Set-Item -Force WSMan:\localhost\Service\Auth\Basic -Value $true

#Set-Item -Force -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow

# Enable WSL2 and Virtual Machine Platform then reboot
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Restart-Computer