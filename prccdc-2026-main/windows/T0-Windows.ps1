# Eternal Blue Shmoue
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Account Creation
$Password = Read-Host -AsSecureString "Enter password for johnsmith"
New-LocalUser -Name "johnsmith" -Password $Password -Description "Local Administrator Account"
Add-LocalGroupMember -Group "Administrators" -Member "johnsmith"

# Admin Account Password Reset
try {
    Set-ADAccountPassword -Identity Administrator -NewPassword (Read-Host -AsSecureString) -Reset -ErrorAction Stop
} catch {
    Write-Host "Not domain-joined or AD unavailable. Use Set-LocalUser instead."
}

# SMB Sharing 
Get-SMBShare
Write-Output "To remove: Remove-SmbShare -Name <smb_share_name> -Force"

# Domain Joined
systeminfo | findstr "Domain" 
Write-Output "If it's not part of domain: Add-Computer -DomainName [DOMAIN] -Restart"

# Disable PowerShell 2
Disable-WindowsOptionalFeature -Online -FeatureName "PowerShell-V2" -NoRestart -ErrorAction Stop

