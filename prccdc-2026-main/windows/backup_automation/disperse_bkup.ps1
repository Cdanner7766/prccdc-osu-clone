$timestamp = Get-Date -Format "yyyy-MM-dd_HH"
$backupRoot = "C:\temp\$timestamp"
$zipPath = "$backupRoot.zip"

# Only continue if zip exists
if (!(Test-Path $zipPath)) {
    Write-Error "Backup zip not found: $zipPath"
    exit 1
}

$backupDirs = @(
    "C:\Program Files (x86)\Microsoft\Temp",
    "C:\Windows\Temp\SystemCache",
    "C:\Users\Public\Music"
)

foreach ($dir in $backupDirs) {

    Write-Host "Processing: $dir"

    try {
        # Create directory if missing
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        if (Test-Path $dir) {
            Copy-Item $zipPath -Destination $dir -Force
            Write-Host "  Copied to $dir"
        }
        else {
            Write-Warning "  Failed to create $dir"
        }
    }
    catch {
        Write-Warning "  Error copying to $dir : $_"
    }
}
