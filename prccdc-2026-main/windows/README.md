# Windows Hardening Tools

PowerShell scripts for hardening Windows hosts at the start of a CCDC round. Run these with Administrator privileges. Most are intentionally short — they do one focused thing well.

---

## Quick Reference

| Script | What it does | When to run |
|---|---|---|
| `T0-Windows.ps1` | Disables SMBv1, creates a known-good local admin, resets AD admin password, disables PowerShell v2 | T+0 — run first on every Windows box |
| `GPO-Update.ps1` | Forces immediate Group Policy refresh | After any GPO change or to pull latest policy |
| `Sysmon-Installed-Already.ps1` | Loads a Sysmon config onto a host where Sysmon is already installed | After deploying Sysmon binary |
| `TCP-View-Sysinternal.ps1` | Lists all active TCP connections with PID info in a grid view | During incident response / suspicious traffic investigation |

---

## Detailed Guides

### `T0-Windows.ps1` — Initial Hardening (T+0)

This is your first script. Run it on every Windows box at competition start.

**What it does, step by step**

#### 1. Disable SMBv1 (EternalBlue mitigation)
```powershell
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
```
SMBv1 is the protocol exploited by EternalBlue (MS17-010), the vulnerability behind WannaCry and NotPetya. Disabling it removes that entire attack surface. The `-NoRestart` flag prevents an automatic reboot — you'll need to reboot manually at a safe time.

#### 2. Create a known-good local admin account
```powershell
New-LocalUser -Name "johnsmith" -Password $Password -Description "Local Administrator Account"
Add-LocalGroupMember -Group "Administrators" -Member "johnsmith"
```
Creates `johnsmith` as a local administrator. This gives you a reliable fallback account whose credentials only your team knows.

> **Before running:** Edit `T0-Windows.ps1` and change `"johnsmith"` to your team's agreed admin username. The script will prompt you for the password at runtime — it will not echo to the screen.

#### 3. Reset the domain Administrator password
```powershell
Set-ADAccountPassword -Identity Administrator -NewPassword (Read-Host -AsSecureString) -Reset
```
Immediately rotates the built-in `Administrator` account password. Will gracefully fall back with a warning message if the host is not domain-joined.

#### 4. Show current SMB shares
```powershell
Get-SMBShare
```
Prints all current SMB shares. Review the output — remove anything unexpected with:
```powershell
Remove-SmbShare -Name <smb_share_name> -Force
```

#### 5. Check domain membership
```powershell
systeminfo | findstr "Domain"
```
Shows whether the host is domain-joined. If it should be joined but isn't, the script prints the join command as a reminder.

#### 6. Disable PowerShell v2
```powershell
Disable-WindowsOptionalFeature -Online -FeatureName "PowerShell-V2" -NoRestart
```
PowerShell v2 bypasses many modern script block logging and AMSI controls. Disabling it removes a common attacker bypass.

**How to run**

```powershell
# Open PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
.\T0-Windows.ps1
```

You will be prompted for passwords during execution. Have your team's passwords ready.

**After running**

- Record the `Get-SMBShare` output — review and remove unneeded shares
- Note any domain membership issues flagged in the output
- Plan a reboot to apply the SMBv1 and PowerShell v2 changes fully

---

### `GPO-Update.ps1` — Force Group Policy Refresh

**What it does**

Runs `gpupdate /force`, which immediately pulls and applies the latest Group Policy Objects from the domain controller — both Computer and User policy.

**Use case in CCDC**

- After you make a change to a GPO in GPMC, run this to apply it immediately without waiting for the 90-minute background refresh cycle
- After a DC failover or GPO restore, force re-application of policy
- When troubleshooting whether a policy is applied correctly

**How to run**

```powershell
# As Administrator
.\GPO-Update.ps1

# Or just run the command directly
gpupdate /force
```

The output will tell you which policies applied (Computer, User) and whether a reboot or logoff is required.

---

### `Sysmon-Installed-Already.ps1` — Load Sysmon Configuration

**What it does**

Checks whether `sysmonconfig.xml` exists in the current directory and, if so, passes it to `sysmon64.exe -i` to install/replace the active configuration.

**Use case in CCDC**

If you've already deployed the Sysmon binary on a host (as part of your standard image or pre-competition prep), use this to load your team's config without re-installing the binary. Sysmon without a config provides minimal logging — the config is what defines what events get captured.

**Prerequisites**

1. `sysmon64.exe` must already be installed on the host
2. Your `sysmonconfig.xml` must be in the same directory as the script

**Recommended config source:** [SwiftOnSecurity/sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config) or the more aggressive [olafhartong/sysmon-modular](https://github.com/olafhartong/sysmon-modular)

**How to run**

```powershell
# Copy your config to the same directory as the script
# Then run as Administrator
.\Sysmon-Installed-Already.ps1
```

**Verify Sysmon is running**

```powershell
Get-Service Sysmon64
# Status should be: Running

# View Sysmon events in Event Viewer
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 20
```

**Key Sysmon event IDs to watch**

| Event ID | Meaning |
|---|---|
| 1 | Process creation (with full command line) |
| 3 | Network connection |
| 7 | Image/DLL loaded |
| 11 | File created |
| 13 | Registry value set |
| 22 | DNS query |
| 25 | Process tampering |

---

### `TCP-View-Sysinternal.ps1` — View Active Network Connections

**What it does**

Runs `Get-NetTCPConnection` and pipes the output to `Out-GridView`, which opens an interactive sortable/filterable grid window.

The script also includes a commented-out alternative for real-time monitoring:
```powershell
# netstat -noab 1
```

**Use case in CCDC**

Use this to quickly identify:
- Unexpected outbound connections (reverse shells, C2 beacons)
- Listening ports that shouldn't be there
- Which process (PID) owns a suspicious connection

**How to run**

```powershell
.\TCP-View-Sysinternal.ps1
```

A GUI grid window will open. You can sort by State, LocalPort, RemoteAddress, or OwningProcess.

**Map PIDs to process names**

The `Get-NetTCPConnection` output gives you `OwningProcess` (PID). To resolve to a process name:

```powershell
# Get all connections with process names
Get-NetTCPConnection |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State,
    @{Name="Process"; Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
    Out-GridView
```

**For real-time terminal monitoring (no GUI)**

```powershell
# Refresh every 1 second, show address, port, PID, and process name
netstat -noab 1
```

---

## Recommended CCDC Run Order

```
T+0:00  Edit T0-Windows.ps1 — change "johnsmith" to your team's admin username
T+0:01  Run T0-Windows.ps1 on every Windows host
T+0:05  Run GPO-Update.ps1 if domain-joined
T+0:06  Load Sysmon config if Sysmon is deployed
T+0:07  Run TCP-View for a quick baseline of active connections
T+0:10  Run windows/backup_automation scripts (see backup_automation/README.md)
```

All scripts require an **Administrator** PowerShell session. If execution policy blocks you:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```
