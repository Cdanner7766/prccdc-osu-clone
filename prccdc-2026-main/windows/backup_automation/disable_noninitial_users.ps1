<#
.SYNOPSIS
    Disable all non-whitelisted Active Directory users
    based on a CSV file with columns:
    "Username","Name","Group Name"
    CAPITALIZATION MATTERS FOR ADMIN USER

.USAGE
    .\disable_noninitial_users.ps1 `
        -CsvPath "C:\path\initial_users.csv" `
        -AdminUser "domainadmin" `
        -DisabledOU "OU=Disabled Users,DC=example,DC=com" `
        -EnforceGroups
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$AdminUser,

    [Parameter(Mandatory = $false)]
    [string]$DisabledOU,

    [switch]$EnforceGroups
)

$ProtectedGroups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Administrators",
    "Denied RODC Password Replication Group"
)

function Log {
    param([string]$Message)
    Write-Host "[ad-enforce] $Message"
}

function Die {
    param([string]$Message)
    Log "ERROR: $Message"
    exit 1
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Die "ActiveDirectory module not available."
}

Import-Module ActiveDirectory

if (-not (Test-Path $CsvPath)) {
    Die "CSV file '$CsvPath' not found."
}

try {
    Get-ADUser -Identity $AdminUser -ErrorAction Stop | Out-Null
}
catch {
    Die "Admin user '$AdminUser' not found in AD."
}

Log "Whitelist CSV: $CsvPath"
Log "Preserved admin user: $AdminUser"

# ---------------------------------------------------------------------------
# Build whitelist from CSV
# ---------------------------------------------------------------------------

$AllowedUsers = @{}
$CsvData = Import-Csv $CsvPath

foreach ($row in $CsvData) {

    if (-not $row.Username) { continue }

    $sam = $row.Username.Trim().ToLower()
    $AllowedUsers[$sam] = $row
}

# Always preserve specified admin
$AllowedUsers[$AdminUser.ToLower()] = $true

# ---------------------------------------------------------------------------
# Disable non-whitelisted users
# ---------------------------------------------------------------------------

$AllUsers = Get-ADUser -Filter * -Properties Enabled

foreach ($User in $AllUsers) {

    if ($User.ObjectClass -ne "user") { continue }
    if ($User.SamAccountName -eq "krbtgt") { continue }

    $sam = $User.SamAccountName.ToLower()

    if (-not $AllowedUsers.ContainsKey($sam)) {

        # Disable if enabled
        if ($User.Enabled) {
            Log "Disabling user: $($User.SamAccountName)"
            Disable-ADAccount -Identity $User
        }

        # Move if DisabledOU specified and user not already there
        if ($DisabledOU -and 
            $User.DistinguishedName -notlike "*$DisabledOU") {

            try {
                Log "Moving user $($User.SamAccountName) to $DisabledOU"
                Move-ADObject -Identity $User.DistinguishedName `
                              -TargetPath $DisabledOU `
                              -ErrorAction Stop
            }
            catch {
                Log "Failed to move $($User.SamAccountName): $_"
            }
        }
    }
}


# ---------------------------------------------------------------------------
# Optional: Enforce group membership from CSV
# ---------------------------------------------------------------------------

if ($EnforceGroups) {

    Log "Enforcing group memberships from CSV..."

    foreach ($row in $CsvData) {

        $sam = $row.Username.Trim()
        $groupName = $row."Group Name"

        if (-not $groupName) { continue }

        if ($ProtectedGroups -contains $groupName) {
            Log "Skipping protected group: $groupName"
            continue
        }

        try {
            # Skip computer accounts (end in $)
            if ($sam.EndsWith('$')) {
                Log "Skipping computer account: $sam"
                continue
            }

            try {
                $user = Get-ADUser -Identity $sam -ErrorAction Stop
            }
            catch {
                Log "User not found or not a user object: $sam"
                continue
            }

            $group = Get-ADGroup -Identity $groupName -ErrorAction Stop

            $isMember = Get-ADGroupMember $group | Where-Object {
                $_.SamAccountName -eq $sam
            }

            if (-not $isMember) {
                Log "Adding $sam to group $groupName"
                Add-ADGroupMember -Identity $group -Members $user
            }
        }
        catch {
            Log "Group enforcement error for $sam : $_"
        }
    }
}

Log "AD enforcement complete."
