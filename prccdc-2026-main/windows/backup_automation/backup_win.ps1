## Member
Write-Output "Backing up Windows Member"

# Timestamped backup folder
$timestamp = Get-Date -Format "yyyy-MM-dd_HH"
$backupRoot = "C:\temp\$timestamp"

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot\GPOBackup | Out-Null
Write-Output "Created Timestamped Backup folder at $backupRoot"

# Scheduled Tasks (Full Restore Capable)
# restore command example: Register-ScheduledTask -Xml (Get-Content task.xml | Out-String) -TaskName "Name"
Write-Output "Copying Scheduled Tasks"
$tasksPath = "$backupRoot\ScheduledTasks"
New-Item -ItemType Directory -Force -Path $tasksPath | Out-Null

Get-ScheduledTask | ForEach-Object {
    $safeName = ($_.TaskPath + $_.TaskName) -replace '[\\/:*?"<>|]', '_'
    Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath |
        Out-File "$tasksPath\$safeName.xml"
}

# firewall rules (Full Restore Capable)
# restore command example: netsh advfirewall import "Firewall.wfw"
Write-Output "Copying Firewall Rules"
netsh advfirewall export "$backupRoot\Firewall.wfw"

# Services
Write-Output "Copying Services"
Get-CimInstance Win32_Service |
Select Name, DisplayName, StartMode, State, StartName, PathName |
Export-Csv "$backupRoot\Services.csv" -NoTypeInformation
# Additionally export raw service registry keys (more complete restore capability)
reg export HKLM\SYSTEM\CurrentControlSet\Services "$backupRoot\ServicesRegistry.reg"

# Snapshot of running services
Write-Output "Copying Running Services"
Get-Service |
Where {$_.Status -eq "Running"} |
Export-Csv "$backupRoot\RunningServices.csv" -NoTypeInformation

# Get privileged groups
Write-Output "Copying Privileged Groups"
$privGroups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Schema Admins",
    "Administrators"
)

$results = foreach ($group in $privGroups) {
    Get-ADGroupMember $group -Recursive |
    Select-Object @{
        Name="Group"; Expression={$group}
    }, Name, SamAccountName, ObjectClass
}

$results | Export-Csv "$backupRoot\PrivilegedGroups.csv" -NoTypeInformation

# Autoruns
Write-Output "Copying Autoruns registry keys"
reg export HKLM\Software\Microsoft\Windows\CurrentVersion\Run "$backupRoot\Run_HKLM.reg"
reg export HKCU\Software\Microsoft\Windows\CurrentVersion\Run "$backupRoot\Run_HKCU.reg"
reg export HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce "$backupRoot\RunOnce_HKLM.reg"

## DC
Write-Output "Beginning Backup for DC"
# System State Backup (REAL restore ability) -- requires a separate storage drive though!
# wbadmin start systemstatebackup -backuptarget:C: -quiet

# GPOBackup if Domain Joined. Requires the "Windows Server Backup" feature
Write-Output "Running Backup-GPO"
Install-WindowsFeature GPMC
Import-Module GroupPolicy
Backup-GPO -All -Path "$backupRoot\GPOBackup"

# Use the below if image is locked down and we cannot install windows featuers
Write-Output "Copying SYSVOL"
Copy-Item "C:\Windows\SYSVOL" "$backupRoot\SYSVOL_Backup" -Recurse

# AD groups
Write-Output "Copying AD Users and Groups"
Import-Module ActiveDirectory
$Groups = (Get-AdGroup -filter * | Where {$_.name -like "**"} | select name -ExpandProperty name)
$Table = @()
$Record = @{
  "Group Name" = ""
  "Name" = ""
  "Username" = ""
}
Foreach ($Group in $Groups) {
  $Arrayofmembers = Get-ADGroupMember -identity $Group -recursive | select name,samaccountname
  foreach ($Member in $Arrayofmembers) {
    $Record."Group Name" = $Group
    $Record."Name" = $Member.name
    $Record."UserName" = $Member.samaccountname
    $objRecord = New-Object PSObject -property $Record
    $Table += $objrecord
  }
}
$Table | export-csv "$backupRoot\ADSecurityGroups.csv" -NoTypeInformation

# WMI persistence
Write-Output "Copying WMI persistence"
Get-WmiObject -Namespace root\subscription -Class __EventFilter |
Export-Csv "$backupRoot\WMI_EventFilters.csv" -NoTypeInformation

Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer |
Export-Csv "$backupRoot\WMI_Consumers.csv" -NoTypeInformation

Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding |
Export-Csv "$backupRoot\WMI_Bindings.csv" -NoTypeInformation

# Network Snapshot
Write-Output "Copying Network Snapshot"
netstat -ano > "$backupRoot\netstat.txt"
ipconfig /all > "$backupRoot\ipconfig.txt"

# Zip up all files
Compress-Archive -Path $backupRoot -DestinationPath "$backupRoot.zip"
Write-Output "Zipped to $backupRoot.zip"
