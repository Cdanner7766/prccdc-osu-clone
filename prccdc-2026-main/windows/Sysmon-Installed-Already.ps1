if (Test-Path "sysmonconfig.xml") {
    sysmon64.exe -i sysmonconfig.xml
} else {
    Write-Host "Error: sysmonconfig.xml not found in current directory!"
}