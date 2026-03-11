# PRCCDC OSU Scripts — CCDC Toolkit

This repository is a collection of hardening scripts, backup automation, infrastructure configs, and utilities built for the **Pacific Rim Collegiate Cyber Defense Competition (PRCCDC)**. It was originally developed by the Oregon State University CCDC team.

---

## Repository Inventory

```
prccdc-osu-clone/
├── prccdc-2026-main/                       # Main OSU CCDC toolkit
│   ├── linux/                              # Linux hardening suite
│   │   ├── bashrc_enhancements             # Tamper-resistant bash history (run first)
│   │   ├── disableptrace.sh                # Restrict ptrace / block credential dumping
│   │   ├── auditdsetup.sh                  # Install auditd + Neo23x0 ruleset
│   │   ├── backup_automation/              # Linux backup & recovery scripts
│   │   │   ├── backup_lin.sh               # Full backup: /home, /etc, /bin, /var/www/html
│   │   │   ├── initialstate.sh             # Lightweight snapshot: users, groups, services
│   │   │   ├── disperse_bkup.sh            # Copy backup tarball to multiple hidden paths
│   │   │   └── lock_noninitial_users.sh    # Lock accounts not in initial passwd snapshot
│   │   └── opengrep-selfextracting/        # Portable OpenGrep code scanner (offline)
│   ├── windows/                            # Windows hardening suite
│   │   ├── T0-Windows.ps1                  # T+0 hardening: SMBv1, local admin, PS v2 (CRITICAL — run first)
│   │   ├── GPO-Update.ps1                  # Force immediate Group Policy refresh
│   │   ├── Sysmon-Installed-Already.ps1    # Load Sysmon config onto existing install
│   │   ├── TCP-View-Sysinternal.ps1        # Interactive grid of active TCP connections
│   │   ├── backup_automation/              # Windows backup & recovery scripts
│   │   │   ├── backup_win.ps1              # Full snapshot: tasks, firewall, GPOs, AD groups, WMI
│   │   │   ├── disperse_bkup.ps1           # Copy backup zip to multiple hidden paths
│   │   │   ├── disable_noninitial_users.ps1# Disable AD users not in initial CSV snapshot
│   │   │   └── securityAutomation/
│   │   │       └── disableBadUsers         # Quick: disable AD users not in a text list
│   ├── 2025_repo/                          # Prior-year reference configs
│   │   ├── ansible/                        # Ansible playbooks for Linux hardening
│   │   │   ├── linux_harden.yaml           # Master playbook: auditd, SSH, ptrace, passwords
│   │   │   └── roles/                      # Modular roles: harden_ssh, rotate_all_passwords, etc.
│   │   └── Infra/                          # Infrastructure templates
│   │       ├── Hashicorp/                  # Consul, Vault, Nomad, Boundary, Packer configs
│   │       └── Crypto/                     # Certificate and key artifacts
│   └── inject_templates/                   # CCDC inject response templates (docx/odt/pdf)
└── LogCrunch/                              # Proto-SIEM for centralized log aggregation
    ├── agent/                              # Log shipping agent (Go)
    ├── server/                             # Intake server + Web UI (Go + SQLite)
    ├── executables/                        # Pre-built binaries (linux amd64 v0.11.1)
    ├── LOGCRUNCH_GUIDE.md                  # Full setup and usage guide
    ├── BEGINNER_GUIDE.md                   # Quick-start for new team members
    └── CHEAT_SHEET.md                      # SQL query reference for log investigation
```

---

## Quick-Start: CCDC Competition Timeline

```
T+0:00  Windows — Edit T0-Windows.ps1 (change "johnsmith" to your admin username)
T+0:01  Windows — Run T0-Windows.ps1 on every Windows host (Administrator PS session)
T+0:02  Linux   — Apply bashrc_enhancements to all active sessions
T+0:03  Linux   — Run disableptrace.sh
T+0:04  Linux   — Run auditdsetup.sh
T+0:05  Windows — Run GPO-Update.ps1 if domain-joined
T+0:05  Linux   — Start backup_lin.sh in background (tmux or &)
T+0:06  Windows — Run backup_win.ps1
T+0:07  Windows — Run TCP-View-Sysinternal.ps1 for a connection baseline
T+0:10  Both    — Run disperse_bkup scripts after backups complete
T+0:??  Both    — Deploy LogCrunch for centralized log visibility
T+0:??  Linux   — Run opengrep scan if you have an inherited web app
```

---

## Sections

### Linux Hardening — `prccdc-2026-main/linux/`

| Script / File | What it does | Priority |
|---|---|---|
| `bashrc_enhancements` | Tamper-resistant, timestamped bash history | **CRITICAL — apply first** |
| `disableptrace.sh` | Blocks ptrace-based credential dumping | High |
| `auditdsetup.sh` | Full syscall auditing via auditd + Neo23x0 rules | High |
| `opengrep-selfextracting/` | Offline code scanner (PHP/Python/Java/JS/Ruby/C) | When you have a web app |

See [`linux/README.md`](prccdc-2026-main/linux/README.md) for detailed run instructions.

---

### Linux Backup — `prccdc-2026-main/linux/backup_automation/`

| Script | What it does |
|---|---|
| `backup_lin.sh` | Backs up `/home`, `/etc`, `/bin`, `/var/www/html` into `./bak/` |
| `initialstate.sh` | Lightweight: user/group/service snapshot only |
| `disperse_bkup.sh` | Tarballs `./bak/` and copies to multiple hidden locations |
| `lock_noninitial_users.sh` | Locks all UID ≥ 1000 accounts not in original passwd snapshot |

See [`linux/backup_automation/README.md`](prccdc-2026-main/linux/backup_automation/README.md) for details and recovery commands.

---

### Windows Hardening — `prccdc-2026-main/windows/`

| Script | What it does | Priority |
|---|---|---|
| `T0-Windows.ps1` | Disables SMBv1 + PowerShell v2, creates local admin, resets domain admin password | **CRITICAL — run first** |
| `GPO-Update.ps1` | Forces immediate `gpupdate /force` | After any GPO change |
| `Sysmon-Installed-Already.ps1` | Loads Sysmon config onto existing install | After Sysmon deployment |
| `TCP-View-Sysinternal.ps1` | Interactive grid view of all TCP connections + owning PIDs | Incident response |

> All Windows scripts require an **Administrator** PowerShell session. If blocked by execution policy:
> ```powershell
> Set-ExecutionPolicy Bypass -Scope Process -Force
> ```

See [`windows/README.md`](prccdc-2026-main/windows/README.md) for detailed guides.

---

### Windows Backup — `prccdc-2026-main/windows/backup_automation/`

| Script | What it does |
|---|---|
| `backup_win.ps1` | Captures scheduled tasks, firewall rules, services, AD groups, WMI persistence, GPOs, autoruns |
| `disperse_bkup.ps1` | Copies timestamped backup zip to multiple locations |
| `disable_noninitial_users.ps1` | Disables AD accounts not in the initial CSV; optionally moves to OU and enforces groups |
| `securityAutomation/disableBadUsers` | Rapid alternative: disables users not in a plain-text list and pops a desktop alert |

See [`windows/backup_automation/README.md`](prccdc-2026-main/windows/backup_automation/README.md) for restore commands.

---

### Ansible — `prccdc-2026-main/2025_repo/ansible/`

Ansible playbook for automated Linux hardening across multiple hosts. Roles include: `harden_ssh`, `disable_ipv6`, `disable_ptrace`, `cfg_auditd`, `rotate_all_passwords`, `save_system_info`.

```bash
ansible-playbook linux_harden.yaml
```

---

### Infrastructure Templates — `prccdc-2026-main/2025_repo/Infra/`

Config templates for rapid deployment of Hashicorp tooling:

| Tool | Config file |
|---|---|
| Consul | `Hashicorp/Consul/ConsulConfig.hcl` |
| Vault | `Hashicorp/Vault/Vault-Server.hcl` |
| Nomad | `Hashicorp/Nomad/nomadConfig.hcl` |
| Boundary | `Hashicorp/Boundary/BoundaryConfig.hcl` |
| Packer | `Hashicorp/Packer/template.hcl` |

---

### LogCrunch — `LogCrunch/`

A lightweight proto-SIEM for centralized log aggregation during competitions and homelabs. Cloned from [`github.com/TLop503/LogCrunch`](https://github.com/TLop503/LogCrunch) at tag `v0.11.1`.

**Architecture:** Agents tail log files / systemd journals → ship over TLS → server stores in SQLite → Web UI for query.

| Component | What it is |
|---|---|
| `agent/` | Deployed on each host; ships logs to the central server |
| `server/` | Intake server + SQLite storage + browser-based query UI |
| `executables/` | Pre-built linux amd64 binaries, ready to deploy without building |

**Quick deploy (pre-built binaries)**

```bash
# Server
tar -xzf executables/LogCrunch_server_v0.11.1_linux_amd64.tar.gz
./LogCrunch-Server --help

# Agent (on each host to monitor)
tar -xzf executables/LogCrunch_agent_v0.11.1_linux_amd64.tar.gz
./LogCrunch-agent --help
```

See [`LogCrunch/LOGCRUNCH_GUIDE.md`](LogCrunch/LOGCRUNCH_GUIDE.md) for full setup, config reference, and Web UI guide.
See [`LogCrunch/BEGINNER_GUIDE.md`](LogCrunch/BEGINNER_GUIDE.md) for new team member quick-start.
See [`LogCrunch/CHEAT_SHEET.md`](LogCrunch/CHEAT_SHEET.md) for SQL query reference.
