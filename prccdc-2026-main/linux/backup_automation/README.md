# Linux Backup Automation

Scripts for creating and dispersing system state backups on Linux hosts. Run these **early** — the backup is your recovery point if red team trashes a config or creates persistence you can't find.

---

## Quick Reference

| Script | What it does | When to run |
|---|---|---|
| `backup_lin.sh` | Full backup: `/home`, `/etc`, `/bin`, and `/var/www/html` into `./bak/` | T+0 — your main backup script |
| `initialstate.sh` | Lighter snapshot: `/home`, passwd/group/service state into `/bak/` | Alternative if storage is tight |
| `disperse_bkup.sh` | Copies `./bak/` to multiple locations as a tarball | After backup, to protect the copy |
| `lock_noninitial_users.sh` | Locks any user account not in the original `/etc/passwd` snapshot | When you suspect new accounts were created |

---

## Detailed Guides

### `backup_lin.sh` — Full System Backup

**What it backs up**

| Archive / File | Source | Notes |
|---|---|---|
| `init_home.tar.gz` | `/home` | All user home directories |
| `init_passwd` | `/etc/passwd` | User account list snapshot |
| `init_group` | `/etc/group` | Group membership snapshot |
| `init_systemctl` | `systemctl list-units` | All loaded systemd units |
| `init_lsmod` | `lsmod` | Loaded kernel modules |
| `init_last` | `last` | Login history |
| `init_etc.tar.gz` | `/etc` | Entire config directory |
| `init_bin.tar.gz` | `/bin` | System binaries |
| `init_html.tar.gz` | `/var/www/html` | Web root (only if it exists) |

**How to run**

```bash
# Run from whatever directory you want bak/ created in
sudo bash backup_lin.sh
```

This creates `./bak/` in the current directory and populates it. Run from a location with enough disk space (e.g., `/root` or `/tmp`).

**Why this matters for CCDC**

- `init_passwd` and `init_group` are your whitelist for `lock_noninitial_users.sh` later
- `init_systemctl` and `init_lsmod` let you spot new persistence (services, kernel modules) by diffing later
- `init_etc.tar.gz` is your recovery point for config files (sshd_config, sudoers, cron, etc.)
- `init_html.tar.gz` is your recovery point if red team defaces the web app

**Recover a single file from the backup**

```bash
# Extract just /etc/sshd_config from the etc backup
tar -xzvf bak/init_etc.tar.gz etc/ssh/sshd_config

# Extract the entire web root
tar -xzvf bak/init_html.tar.gz
```

> **Warning from the script itself:** "This takes a HOT minute." Run critical security tasks (passwords, auditd) first, then start this in the background or a tmux pane.

---

### `initialstate.sh` — Lightweight State Snapshot

A simpler, faster alternative to `backup_lin.sh`. Creates `/bak/` (root of filesystem) and captures:

| File | Source |
|---|---|
| `init_home.tar.gz` | `/home` |
| `init_passwd` | `/etc/passwd` |
| `init_group` | `/etc/group` |
| `init_systemctl` | `systemctl list-units` |
| `init_lsmod` | `lsmod` |
| `init_last` | `last` |

Does **not** back up `/etc`, `/bin`, or `/var/www/html`.

**How to run**

```bash
sudo bash initialstate.sh
```

Backup lands in `/bak/` (absolute path). Use this when you need the user/group/service snapshot quickly and don't have time or disk space for the full backup.

---

### `disperse_bkup.sh` — Copy Backup to Multiple Locations

**What it does**

Tarballs the `./bak/` directory into `bak_bak.tar.gz`, then copies that archive to multiple locations. This protects your backup against deletion if red team finds it in the obvious location.

**Before running — configure your target directories**

The script ships with placeholder paths (`/...`, `/var/log/...`). Edit them to real locations first:

```bash
# Open the script
nano disperse_bkup.sh

# Change this block to real paths:
backup_dirs=(
    "/..."           # ← change to e.g. /var/lib/.cache
    "/var/log/..."   # ← change to e.g. /var/log/.sys
)
```

Use non-obvious paths. Suggestions: `/var/lib/.bak`, `/usr/share/.sys`, `/var/cache/.store`

**How to run**

```bash
# Must be run from the directory that contains ./bak/
sudo bash disperse_bkup.sh
```

The script checks that `./bak/` exists before doing anything and will exit cleanly if not found.

**Quick reference for dispersal**

```bash
# After running, verify copies landed
ls -la /var/lib/.bak/bak_bak.tar.gz
ls -la /var/log/.sys/bak_bak.tar.gz
```

---

### `lock_noninitial_users.sh` — Lock Unauthorized User Accounts

**What it does**

Compares the current `/etc/passwd` against your saved `init_passwd` snapshot. Any user account with UID ≥ 1000 that was **not in the original snapshot** gets:

1. Account locked (`usermod -L -e 1`) — password login disabled, expiry set to epoch
2. Shell changed to `/usr/sbin/nologin` — interactive login blocked
3. Added to `deny-ssh` group — SSH access blocked (see setup note below)
4. sshd reloaded to enforce the new group deny

**Prerequisites**

This script expects a `deny-ssh` group and a matching `DenyGroups deny-ssh` line in sshd_config. Set that up once, early:

```bash
# Create the deny group
sudo groupadd deny-ssh

# Add to sshd_config
echo "DenyGroups deny-ssh" | sudo tee -a /etc/ssh/sshd_config

# Reload sshd
sudo systemctl reload sshd
```

**How to run**

```bash
# Requires: path to init_passwd file, name of your admin account to preserve
sudo bash lock_noninitial_users.sh /bak/init_passwd your_admin_username

# Example
sudo bash lock_noninitial_users.sh /bak/init_passwd ccdc_admin
```

**What it preserves**

- `root` — always preserved
- The admin user you specify — always preserved
- All system accounts (UID < 1000) — skipped

**When to use this**

Run this if:
- You see unexpected accounts in `cat /etc/passwd`
- You suspect red team created a backdoor user
- After any incident where you don't know what changed

**Verify what it locked**

```bash
# List locked accounts
passwd -S -a | grep " L "

# Check which users are in deny-ssh
getent group deny-ssh
```

---

## Recommended CCDC Workflow

```
T+0:00  Run backup_lin.sh in background (tmux pane or &)
        sudo bash backup_lin.sh &

T+0:01  While waiting: set up deny-ssh prereqs for lock script
        sudo groupadd deny-ssh
        echo "DenyGroups deny-ssh" >> /etc/ssh/sshd_config
        sudo systemctl reload sshd

T+??    After backup completes: edit disperse_bkup.sh with real paths
        sudo bash disperse_bkup.sh

T+??    If new users appear: run lock_noninitial_users.sh
        sudo bash lock_noninitial_users.sh /bak/init_passwd <your_admin>
```

**Tip:** Keep the `init_passwd` file. Every other script in this folder depends on it.

---

## Diffing to Spot Changes

Once you have a baseline, compare it to the current state:

```bash
# New user accounts since backup
diff /bak/init_passwd /etc/passwd

# New groups
diff /bak/init_group /etc/group

# New/changed services
diff /bak/init_systemctl <(systemctl list-units)

# New kernel modules
diff /bak/init_lsmod <(lsmod)

# Config files changed since backup
diff -r /bak/init_etc_extracted/ /etc/
```
