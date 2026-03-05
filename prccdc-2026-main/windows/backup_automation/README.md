# Windows Backup Automation

Scripts for capturing a system state snapshot on Windows hosts and protecting it. Run these early — the backup is your recovery point for configs, GPOs, users, and scheduled tasks.

---

## Quick Reference

| Script | What it does | When to run |
|---|---|---|
| `backup_win.ps1` | Full snapshot: scheduled tasks, firewall rules, services, AD groups, autoruns, WMI persistence, network state, GPO backup | T+0 — your primary Windows backup |
| `disperse_bkup.ps1` | Copies the timestamped backup zip to multiple locations | After backup, to protect the copy |
| `disable_noninitial_users.ps1` | Disables all AD users not in an initial CSV snapshot; optionally enforces group memberships | When unauthorized AD accounts appear |
| `securityAutomation/disableBadUsers` | Simpler alternative: disables AD users not in a text file, pops an alert | Quick response to bad accounts |

---

## Detailed Guides

### `backup_win.ps1` — Full Windows State Backup

**What it captures**

All output lands in `C:\temp\<YYYY-MM-DD_HH>\` and is zipped to `C:\temp\<YYYY-MM-DD_HH>.zip`.

| File | What it contains | How to restore |
|---|---|---|
| `ScheduledTasks\*.xml` | Every scheduled task exported as XML | `Register-ScheduledTask -Xml (Get-Content task.xml \| Out-String) -TaskName "Name"` |
| `Firewall.wfw` | All Windows Firewall rules | `netsh advfirewall import "Firewall.wfw"` |
| `Services.csv` | All services: name, start mode, state, path | Manual reference |
| `ServicesRegistry.reg` | Raw service registry keys (more complete) | `reg import ServicesRegistry.reg` |
| `RunningServices.csv` | Services that were running at backup time | Comparison baseline |
| `PrivilegedGroups.csv` | Members of Domain Admins, Enterprise Admins, Schema Admins, Administrators | Comparison baseline |
| `GPOBackup\` | All GPOs exported via `Backup-GPO` | `Restore-GPO` (requires GPMC) |
| `SYSVOL_Backup\` | Raw SYSVOL copy (fallback if feature install fails) | Manual copy back |
| `ADSecurityGroups.csv` | All AD groups with full member lists | Comparison baseline |
| `WMI_EventFilters.csv` | WMI event filter subscriptions (common persistence) | Review for unknowns |
| `WMI_Consumers.csv` | WMI event consumers | Review for unknowns |
| `WMI_Bindings.csv` | WMI filter-to-consumer bindings | Review for unknowns |
| `netstat.txt` | `netstat -ano` output | Comparison baseline |
| `ipconfig.txt` | `ipconfig /all` output | Network config reference |
| `Run_HKLM.reg` | HKLM autorun registry keys | Compare to detect new autoruns |
| `Run_HKCU.reg` | HKCU autorun registry keys | Compare to detect new autoruns |
| `RunOnce_HKLM.reg` | HKLM RunOnce keys | Compare to detect persistence |

**How to run**

```powershell
# As Administrator
.\backup_win.ps1
```

The script creates and zips the backup automatically. On a DC, it will also try to install `GPMC` to enable `Backup-GPO`. If feature installation is blocked, it falls back to a raw SYSVOL copy.

**Estimated output location**

```
C:\temp\2026-03-04_14\           ← directory with all files
C:\temp\2026-03-04_14.zip        ← zipped archive
```

**Note:** The `PrivilegedGroups.csv` and `ADSecurityGroups.csv` sections require the `ActiveDirectory` module. On member servers that don't have RSAT installed, those sections will error — that's expected. The rest of the backup continues.

---

### `disperse_bkup.ps1` — Copy Backup to Multiple Locations

**What it does**

Finds the most recent timestamped backup zip in `C:\temp\` and copies it to multiple locations for redundancy.

**Before running — verify or update target directories**

The script ships with these default paths:

```powershell
$backupDirs = @(
    "C:\Program Files (x86)\Microsoft\Temp",
    "C:\Windows\Temp\SystemCache",
    "C:\Users\Public\Music"
)
```

These are intentionally non-obvious to avoid easy discovery. Change them if needed — just pick paths that look like system directories and won't be cleaned by a simple `del /f /s`.

**How to run**

```powershell
# Run immediately after backup_win.ps1
.\disperse_bkup.ps1
```

The script checks that the timestamped zip exists before doing anything, and uses `try/catch` around each copy so a failed target doesn't abort the rest.

**Verify copies landed**

```powershell
Get-Item "C:\Program Files (x86)\Microsoft\Temp\*.zip"
Get-Item "C:\Windows\Temp\SystemCache\*.zip"
```

---

### `disable_noninitial_users.ps1` — Enforce AD User Whitelist

**What it does**

The well-polished version of user enforcement. Compares every AD user account against a CSV whitelist (the one exported by `backup_win.ps1` as `ADSecurityGroups.csv` or `PrivilegedGroups.csv`). Any account not in the whitelist gets:

1. **Disabled** (`Disable-ADAccount`)
2. **Moved to a Disabled Users OU** (optional, if `-DisabledOU` is specified)
3. **Group memberships re-enforced** (optional, if `-EnforceGroups` is specified)

**CSV format expected**

```
"Username","Name","Group Name"
"jdoe","John Doe","Domain Admins"
"bsmith","Bob Smith","Developers"
```

This matches the format exported by `backup_win.ps1`'s `ADSecurityGroups.csv`.

**How to run**

```powershell
# Basic — just disable non-whitelisted users
.\disable_noninitial_users.ps1 `
    -CsvPath "C:\temp\2026-03-04_14\ADSecurityGroups.csv" `
    -AdminUser "domainadmin"

# Full — also move disabled users to an OU and enforce group memberships
.\disable_noninitial_users.ps1 `
    -CsvPath "C:\temp\2026-03-04_14\ADSecurityGroups.csv" `
    -AdminUser "domainadmin" `
    -DisabledOU "OU=Disabled Users,DC=corp,DC=local" `
    -EnforceGroups
```

**Always-preserved accounts**

- The `-AdminUser` you specify
- `krbtgt` (Kerberos account — never disable this)

**Protected groups (never modified)**

- Domain Admins
- Enterprise Admins
- Administrators
- Denied RODC Password Replication Group

**When to use this**

- After taking your initial backup — run it immediately to lock the state
- When you see unexpected accounts in AD Users and Computers
- After any credential compromise incident

---

### `securityAutomation/disableBadUsers` — Quick Bad-User Shutdown

A simpler, rougher version of the above for rapid use.

**What it does**

Reads a plain-text list of authorized usernames, compares against all AD users, and for any user **not** on the list:
1. Disables the account with `Disable-ADAccount`
2. Checks if that user is logged into a specified computer
3. Pops a desktop alert: `"unauthorized user disabled: username"`

**Before running — configure the script**

The script has two hardcoded values you must fill in:

```powershell
$userFile = "path to username list"   # ← change to e.g. "C:\users.txt"
$computer = "COMPUTER NAME"           # ← change to the hostname to check for active sessions
```

**Username list format** — one username per line:

```
administrator
jdoe
bsmith
svc_backup
```

**How to run**

```powershell
# Edit the script first to set $userFile and $computer
# Then run as Administrator
.\securityAutomation\disableBadUsers
```

**When to use this vs. `disable_noninitial_users.ps1`**

| | `disableBadUsers` | `disable_noninitial_users.ps1` |
|---|---|---|
| Input format | Plain text file | CSV with Username/Name/Group columns |
| OU move | No | Yes (optional) |
| Group enforcement | No | Yes (optional) |
| Desktop alert | Yes | No |
| Complexity | Simple | Full-featured |

Use `disableBadUsers` for a quick mid-incident response. Use `disable_noninitial_users.ps1` for systematic enforcement from your backup CSV.

---

## Recommended CCDC Workflow

```
T+0:00  Run backup_win.ps1
        .\backup_win.ps1

T+0:??  After backup completes, run disperse_bkup.ps1
        .\disperse_bkup.ps1

T+0:??  If the environment is domain-joined: run disable_noninitial_users.ps1
        with your backup's ADSecurityGroups.csv as the whitelist

T+??    During competition: if new/suspicious AD accounts appear,
        use disableBadUsers for immediate response
```

---

## Using the Backup for Incident Response

**Has a scheduled task been added?**

```powershell
# Compare current tasks against backup
$backup = Get-ChildItem "C:\temp\2026-03-04_14\ScheduledTasks\" | Select -ExpandProperty BaseName
$current = Get-ScheduledTask | ForEach-Object { ($_.TaskPath + $_.TaskName) -replace '[\\/:*?"<>|]', '_' }
Compare-Object $backup $current
```

**Has a new autorun been added?**

```powershell
# Export current state and diff against backup
reg export HKLM\Software\Microsoft\Windows\CurrentVersion\Run C:\temp\Run_HKLM_now.reg
# Then compare files manually or with fc.exe
fc C:\temp\2026-03-04_14\Run_HKLM.reg C:\temp\Run_HKLM_now.reg
```

**Has a new service appeared?**

```powershell
# Import backup CSV and compare to live
$backup = Import-Csv "C:\temp\2026-03-04_14\Services.csv"
$current = Get-CimInstance Win32_Service | Select Name, StartMode, State, PathName
Compare-Object ($backup | Select -ExpandProperty Name) ($current | Select -ExpandProperty Name)
```

**WMI persistence check**

```powershell
# Any WMI event subscriptions not in your backup CSV?
$live = Get-WmiObject -Namespace root\subscription -Class __EventFilter
$backup = Import-Csv "C:\temp\2026-03-04_14\WMI_EventFilters.csv"
# Compare Name columns
```
