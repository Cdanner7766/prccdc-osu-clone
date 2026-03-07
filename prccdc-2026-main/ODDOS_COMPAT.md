# Compatibility Guide — Obscure & Old Operating Systems

This document answers: **"I'm on a weird box at CCDC — which scripts can I safely run?"**

Every script in `linux/` and `linux/backup_automation/` was analyzed for what breaks and why, across a wide range of unusual, minimal, and legacy Linux systems that have historically appeared at CCDC events.

---

## The Short Answer — Quick Compatibility Matrix

| Script | Alpine | Red Star OS | Hannah Montana | Damn Small Linux | Puppy Linux | Gentoo | Slackware | Void | NixOS | Old CentOS 5–6 | Old Debian 7 / Ubuntu 12–14 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `disableptrace.sh` | ✅ | ⚠️ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ |
| `bashrc_enhancements` | ⚠️ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `auditdsetup.sh` | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | ⚠️ | ⚠️ |
| `backup_lin.sh` | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅† | ⚠️ | ⚠️ | ✅† | ⚠️ | ⚠️ |
| `initialstate.sh` | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅† | ⚠️ | ⚠️ | ✅† | ⚠️ | ⚠️ |
| `disperse_bkup.sh` | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `lock_noninitial_users.sh` | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| `opengrep` (built package) | ✅ | ✅† | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Key:**
- ✅ Works as-is
- ✅† Works if on systemd (user config may vary)
- ⚠️ Partially works — specific commands fail, workarounds available below
- ❌ Does not work — wrong package manager or architecture

---

## What Actually Breaks (and Why)

Most failures come from three sources. Knowing these lets you adapt any script on any system.

### Root Cause 1 — `systemctl` (init system mismatch)

`systemctl` is the systemd command. Many unusual and old systems don't use systemd:

| Init system | Found on | What to use instead |
|---|---|---|
| **systemd** | Most modern Linux (Debian 8+, Ubuntu 15+, CentOS 7+, Arch, Fedora, Gentoo†) | `systemctl` — works normally |
| **OpenRC** | Alpine Linux, Gentoo† | `rc-service <name> start`, `rc-update add <name>` |
| **Upstart** | Ubuntu 10.04–14.10, old RHEL/CentOS 6 | `service <name> start`, `update-rc.d <name> enable` |
| **SysVinit** | Debian 7, Slackware, CentOS 5, Damn Small Linux | `service <name> start`, `chkconfig <name> on` |
| **runit** | Void Linux | `ln -s /etc/sv/<name> /var/service/` |

**How to check which init system you have:**

```bash
# Method 1 — ask the process directly
ps -p 1 -o comm=

# Method 2 — look for the binary
ls -la /sbin/init

# Method 3 — check for systemd socket
[ -d /run/systemd/system ] && echo systemd || echo not-systemd
```

### Root Cause 2 — No bash (ash/sh/dash only)

`bashrc_enhancements` and scripts with `#!/usr/bin/env bash` require bash. On minimal distros, the default shell is often `ash` (BusyBox) or `dash`, not bash.

**Check if bash exists:**
```bash
which bash       # should print a path like /bin/bash
bash --version   # should respond
```

**Install bash if missing:**
```bash
apk add bash          # Alpine
xbps-install bash     # Void
```

### Root Cause 3 — Package manager not detected

`auditdsetup.sh` detects the package manager by checking for OS release files. It supports: `yum`, `apt-get`, `pacman`, `emerge`, `zypp`, `apk`. Systems outside this list get an error and exit.

**Unsupported package managers:** Slackware (`pkgtool`), Void (`xbps`), NixOS (`nix`), CRUX (`ports`).

---

## Per-OS Breakdown

---

### Alpine Linux

**What it is:** Ultra-minimal Linux using musl libc instead of glibc, BusyBox utilities, and OpenRC (not systemd). Very common in Docker containers and competition infrastructure.

**Package manager:** `apk` — **detected** by `auditdsetup.sh`

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ✅ | Works — sysctl is available |
| `bashrc_enhancements` | ⚠️ | Default shell is `ash`. Install bash first: `apk add bash` |
| `auditdsetup.sh` | ⚠️ | `apk add auditd` works; `systemctl` calls fail (Alpine uses OpenRC); `augenrules` en-dash bug still present |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` fails; `last` not installed by default |
| `disperse_bkup.sh` | ⚠️ | Works if bash is installed; BusyBox tar supports the flags used |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` needs `apk add shadow`; nologin path is `/sbin/nologin` not `/usr/sbin/nologin`; `systemctl reload sshd` fails — use `rc-service sshd reload` |
| `opengrep` | ✅ | `opengrep_musllinux_x86` binary was built specifically for musl systems like Alpine |

**Quick fixes for Alpine:**

```bash
# Install essential tools that are missing
apk add bash shadow util-linux auditd

# Replace systemctl with OpenRC equivalents:
rc-service auditd start
rc-update add auditd default

# Reload sshd:
rc-service sshd reload

# Replace `last` (from util-linux):
last   # works after: apk add util-linux

# Check init system
ps -p 1 -o comm=    # outputs "openrc-init" or "init"
```

---

### Red Star OS (붉은별, Ryugyong)

**What it is:** North Korea's national operating system. Red Star 3.0 visually mimics macOS but is based on Fedora 11 (circa 2009), running a modified kernel 2.6.x. Has significant anti-tamper mechanisms.

**Package manager:** `yum` — **detected** by `auditdsetup.sh`

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ⚠️ | Kernel 2.6.x predates YAMA (merged in Linux 3.4). The `ptrace_scope` key does not exist. `sysctl -p` will warn but not crash. Anti-tamper may also revert `/etc/sysctl.conf` on reboot. |
| `bashrc_enhancements` | ✅ | bash is present; works normally |
| `auditdsetup.sh` | ⚠️ | `yum install audit` works; `systemctl` may not exist (Fedora 11 era used SysVinit/Upstart); anti-tamper may fight audit rules |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` likely fails; everything else (tar, cat, lsmod, last) should work |
| `disperse_bkup.sh` | ✅ | Pure bash + tar + cp — should work |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` and `shadow-utils` should be present; `/sbin/nologin` path likely correct; `systemctl reload sshd` may fail |
| `opengrep` | ✅† | x86 architecture, glibc — the `manylinux_x86` binary should work if the kernel is new enough (glibc 2.17+ needed for manylinux2014) |

**Key concern:** Red Star OS has anti-tamper software (`nss daemon`) that monitors critical system files and can revert them. Changes to `/etc/sysctl.conf`, `/etc/passwd`, and system configs may be reverted. If you find yourself on a Red Star box, kill or disable `nss` first — it runs as a background daemon.

---

### Hannah Montana Linux

**What it is:** A novelty Ubuntu-based distro from circa 2009–2010. Functionally it is stock Ubuntu 10.04 LTS (Lucid Lynx) with a custom theme. Ubuntu 10.04 uses **Upstart**, not systemd.

**Package manager:** `apt-get` — **detected** by `auditdsetup.sh`

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ✅ | Ubuntu 10.04 kernel is 2.6.32 — predates YAMA (3.4). Same issue as Red Star: key doesn't exist, `sysctl -p` warns but continues |
| `bashrc_enhancements` | ✅ | bash is standard on Ubuntu |
| `auditdsetup.sh` | ⚠️ | `apt-get install auditd` works; `systemctl start auditd` fails (Upstart, not systemd). Use: `service auditd start && update-rc.d auditd enable` |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` fails; use `service --status-all` instead |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` works; `systemctl reload sshd` fails; use `service ssh reload` |
| `opengrep` | ✅ | x86, glibc — manylinux binary should work |

**Upstart equivalents:**

```bash
# Instead of: systemctl start auditd
service auditd start

# Instead of: systemctl enable auditd
update-rc.d auditd enable

# Instead of: systemctl reload sshd
service ssh reload

# Instead of: systemctl list-units
service --status-all
```

---

### Damn Small Linux (DSL)

**What it is:** ~50MB Linux distro based on Knoppix (Debian). Uses a 2.4 kernel and BusyBox for nearly all utilities. Has `/etc/debian_version` so `apt-get` is detected, but the package repos are ancient.

**Package manager:** `apt-get` — **detected**, but repos likely stale/unavailable

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ⚠️ | Kernel 2.4 — YAMA doesn't exist. The key will not be found. `sysctl -p` will error. Script will not crash but does nothing useful. |
| `bashrc_enhancements` | ⚠️ | bash may not be installed; DSL typically uses `ash` |
| `auditdsetup.sh` | ⚠️ | `apt-get` detected; auditd may not be available for a 2.4 kernel; no `systemctl` (SysVinit); `augenrules` probably not installed |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` fails; `last` may not be installed; `tar` is BusyBox (may behave differently) |
| `disperse_bkup.sh` | ✅ | BusyBox tar supports flags used; works if bash available |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` may not exist (BusyBox `adduser` is different); `shadow-utils` may be missing |
| `opengrep` | ❌ | 2.4 kernel is too old for the manylinux binaries; architecture is x86 but glibc is extremely old |

**Practical advice:** On DSL, skip most scripts. Focus on manual actions: change passwords (`passwd`), check running processes (`ps aux`), check listening ports (`netstat -tlnp` if available), and copy files manually.

---

### Puppy Linux

**What it is:** A family of distros rather than a single OS — "Puppy" is built on top of Ubuntu (Bionic Pup), Slackware (Slacko Puppy), or others. Behavior varies significantly by flavor. Designed to run entirely from RAM.

**Package manager:** Depends on the base:
- Ubuntu-based → `apt-get` (detected ✅)
- Slackware-based → `pkgtool` (not detected ❌)

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ✅ | Most Puppy flavors have a modern enough kernel; works if YAMA is compiled in |
| `bashrc_enhancements` | ⚠️ | Bash may be present but minimal; `~/.bashrc` may not exist — create it first |
| `auditdsetup.sh` | ⚠️ | Ubuntu-based Puppy: may work; Slackware-based: detected as unsupported |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | Puppy runs from RAM — `/home` may not persist across reboot; `systemctl` may or may not exist |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` availability varies; `nologin` path varies |
| `opengrep` | ⚠️ | x86 and glibc needed; Ubuntu-based Puppy should work |

**Important Puppy note:** Puppy Linux saves state in a `pupsave` file and boots entirely to RAM. Edits to system files persist through the save mechanism, but only after you explicitly save. Make sure to save your state after running these scripts.

---

### Gentoo

**What it is:** Source-based distro where everything is compiled from source. Uses `emerge` package manager and either OpenRC or systemd (user's choice at installation).

**Package manager:** `emerge` — **detected** by `auditdsetup.sh`

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ✅ | Works |
| `bashrc_enhancements` | ✅ | bash is always present on Gentoo |
| `auditdsetup.sh` | ⚠️ | `emerge auditd` works but compiles from source — **this will take a very long time** at CCDC. Check if it's already installed first: `which auditctl`. If systemd: `systemctl` works. If OpenRC: use `rc-service`/`rc-update`. |
| `backup_lin.sh` / `initialstate.sh` | ✅† | Works if on systemd; if OpenRC, `systemctl list-units` fails |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ✅† | Works if systemd; if OpenRC, adjust sshd reload command |
| `opengrep` | ✅ | x86 glibc — works |

**Gentoo-specific warning:** Don't run `emerge <anything>` during competition unless you have to. It compiles from source and will consume CPU and time. Check if packages are already installed first.

---

### Slackware

**What it is:** One of the oldest surviving Linux distros (1993). Uses SysVinit and `pkgtool`/`slackpkg` for package management. No package manager file is detected by the scripts.

**Package manager:** `pkgtool` — **not detected** — `auditdsetup.sh` will exit with an error

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ✅ | Works — just sysctl |
| `bashrc_enhancements` | ✅ | bash is standard on Slackware |
| `auditdsetup.sh` | ❌ | Unsupported package manager — script exits. Install manually: `slackpkg install audit` |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` fails (SysVinit); use `service --status-all` or check `/etc/rc.d/` |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` is present; `systemctl reload sshd` fails; use `/etc/rc.d/rc.sshd reload` |
| `opengrep` | ✅ | x86 glibc — works |

**Slackware init equivalents:**
```bash
# Instead of: systemctl reload sshd
/etc/rc.d/rc.sshd reload

# Instead of: systemctl list-units
ls /etc/rc.d/     # shows active services

# Instead of: systemctl enable auditd
chmod +x /etc/rc.d/rc.auditd
```

---

### Void Linux

**What it is:** Independent distro using `xbps` package manager and `runit` init system. Available in glibc and musl variants.

**Package manager:** `xbps` — **not detected** — `auditdsetup.sh` will exit with an error

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ✅ | Works |
| `bashrc_enhancements` | ✅ | bash available |
| `auditdsetup.sh` | ❌ | Unsupported. Install manually: `xbps-install -S audit`. Use runit to manage: `ln -s /etc/sv/auditd /var/service/` |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` fails; use `sv status /var/service/*` |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | `systemctl reload sshd` fails; use `sv reload sshd` |
| `opengrep` | ✅ | glibc variant: manylinux binary; musl variant: musllinux binary |

**Void runit equivalents:**
```bash
# Instead of: systemctl start auditd
ln -s /etc/sv/auditd /var/service/   # enable and start

# Instead of: systemctl reload sshd
sv reload sshd

# Instead of: systemctl list-units
sv status /var/service/*
```

---

### NixOS

**What it is:** Declarative, reproducible Linux distro where the entire system is configured in `/etc/nixos/configuration.nix`. Uses systemd, so `systemctl` works — but edits to individual config files (like `/etc/sysctl.conf`) **don't persist** across system rebuilds.

**Package manager:** `nix` — **not detected** — `auditdsetup.sh` will exit with an error

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ⚠️ | The sysctl change applies immediately but **will not survive** a `nixos-rebuild`. Must be added to `configuration.nix` to persist: `boot.kernel.sysctl."kernel.yama.ptrace_scope" = 1;` |
| `bashrc_enhancements` | ✅ | bash is available |
| `auditdsetup.sh` | ❌ | Unsupported package manager. Enable auditd in `configuration.nix` instead. |
| `backup_lin.sh` / `initialstate.sh` | ✅† | systemctl works; `last` should be available |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | Changes work immediately but user config on NixOS is typically managed declaratively — manual `usermod` changes may be reverted |
| `opengrep` | ✅ | NixOS handles glibc patching; the binary should run (NixOS has patchelf/nix-ld) |

---

### Old CentOS / RHEL 5–6

**What it is:** Enterprise Linux from the RHEL ecosystem. CentOS 5 uses a 2.6.18 kernel and SysVinit. CentOS 6 uses Upstart. CentOS 7+ uses systemd. Still appears at CCDC events as legacy infrastructure.

**Package manager:** `yum` — **detected** by `auditdsetup.sh`

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ⚠️ | CentOS 5: kernel 2.6.18 — no YAMA, key doesn't exist, sysctl will warn. CentOS 6: kernel 2.6.32 — still no YAMA. CentOS 7: kernel 3.10 — YAMA backported, **works**. |
| `bashrc_enhancements` | ✅ | bash is standard on RHEL |
| `auditdsetup.sh` | ⚠️ | Package name is `audit` (not `auditd`) — the script handles this correctly for `yum`. **But:** CentOS 5 (SysVinit) and CentOS 6 (Upstart) don't have `systemctl`. CentOS 5: use `service auditd start && chkconfig auditd on`. CentOS 6: use `service auditd start && chkconfig auditd on`. |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | CentOS 5/6: `systemctl list-units` fails. CentOS 7+: works. |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` and `shadow-utils` present. CentOS 5/6: `systemctl reload sshd` fails — use `service sshd reload`. Nologin path: `/sbin/nologin` not `/usr/sbin/nologin`. |
| `opengrep` | ✅ | x86 glibc — works on CentOS 6+. CentOS 5 has glibc 2.5 which may be too old for manylinux2014 binaries. |

**CentOS 5/6 init equivalents:**
```bash
# Instead of: systemctl start auditd
service auditd start

# Instead of: systemctl enable auditd
chkconfig auditd on

# Instead of: systemctl reload sshd
service sshd reload

# Instead of: systemctl list-units
service --status-all 2>/dev/null
chkconfig --list
```

---

### Old Debian 7 / Ubuntu 12.04–14.04

**What it is:** Mainstream distros that just predate systemd. Debian 7 (Wheezy) uses SysVinit. Ubuntu 12.04 (Precise) and 14.04 (Trusty) use Upstart.

**Package manager:** `apt-get` — **detected** ✅

| Script | Status | Notes |
|---|---|---|
| `disableptrace.sh` | ⚠️ | Debian 7 / Ubuntu 12.04: kernel 3.2 — YAMA exists but may not be compiled in. Ubuntu 14.04: kernel 3.13 — YAMA works. Try it and check: `cat /proc/sys/kernel/yama/ptrace_scope` |
| `bashrc_enhancements` | ✅ | bash is standard |
| `auditdsetup.sh` | ⚠️ | `apt-get install auditd` works. Debian 7 / Ubuntu 12: `systemctl` fails — use `service auditd start && update-rc.d auditd enable`. Ubuntu 14.04: same (Upstart). Ubuntu 14.10+: systemd works. |
| `backup_lin.sh` / `initialstate.sh` | ⚠️ | `systemctl list-units` fails on Debian 7 and Ubuntu 12/14 |
| `disperse_bkup.sh` | ✅ | Works |
| `lock_noninitial_users.sh` | ⚠️ | `usermod` works. `systemctl reload sshd` fails on Upstart/SysVinit. Use `service ssh reload`. Note: Debian/Ubuntu service name is `ssh`, not `sshd`. |
| `opengrep` | ✅ | x86 glibc — works |

---

## Universal Workarounds Reference

### Replacing `systemctl` on non-systemd systems

**Step 1 — Identify your init:**
```bash
ps -p 1 -o comm=
# or
cat /proc/1/comm
```

**Step 2 — Use the right command:**

```bash
# systemd (output: "systemd")
systemctl start auditd
systemctl enable auditd
systemctl reload sshd

# OpenRC — Alpine, Gentoo (output: "openrc-init" or "init")
rc-service auditd start
rc-update add auditd default
rc-service sshd reload

# Upstart — Ubuntu 12-14, CentOS 6 (output: "init")
service auditd start
update-rc.d auditd enable       # Debian/Ubuntu
chkconfig auditd on             # CentOS/RHEL
service ssh reload              # Debian/Ubuntu (service is "ssh")
service sshd reload             # CentOS/RHEL (service is "sshd")

# SysVinit — Debian 7, CentOS 5, Slackware (output: "init")
service auditd start
chkconfig auditd on             # if chkconfig exists
# or: update-rc.d auditd defaults
service sshd reload

# runit — Void Linux (output: "runit")
ln -s /etc/sv/auditd /var/service/
sv reload sshd
```

### Check if YAMA ptrace restriction is supported

```bash
# If this file exists, YAMA is compiled in and disableptrace.sh will work:
cat /proc/sys/kernel/yama/ptrace_scope
# 0 = exists but unrestricted (script will change to 1)
# file not found = YAMA not compiled in, script does nothing useful
```

### Check if auditd is already installed

```bash
which auditctl && auditctl -l
# or
auditd -v
```

### Fix the `augenrules` en-dash bug

`auditdsetup.sh` line 66 has an en-dash (`–`) instead of two hyphens (`--`):
```bash
# The script runs: augenrules –-load     ← broken
# Run this manually after the script:
augenrules --load
```

### Find the correct `nologin` path

`lock_noninitial_users.sh` hardcodes `/usr/sbin/nologin`. The actual path varies:

```bash
# Find it on your system:
which nologin
# or
find /usr /sbin /bin -name nologin 2>/dev/null

# Common paths:
# /usr/sbin/nologin  — Debian, Ubuntu
# /sbin/nologin      — RHEL, CentOS, Alpine, Arch
# /usr/bin/nologin   — Arch Linux
# /bin/false         — fallback that works on all systems
```

---

## Safe-to-Run List for Completely Unknown Systems

If you land on a box and don't know what it's running, these are the safest to try first (highest compatibility, lowest risk):

1. **`disableptrace.sh`** — Worst case: the key doesn't exist and you get a sysctl warning. No damage.
2. **`bashrc_enhancements`** — Worst case: bash isn't installed and the file isn't sourced. Check `which bash` first.
3. **`disperse_bkup.sh`** — Pure bash + standard Unix tools. Works almost everywhere if bash is present.

Before running anything else, do these checks:
```bash
which bash          # is bash available?
ps -p 1 -o comm=    # which init system?
cat /proc/sys/kernel/yama/ptrace_scope  # does ptrace restriction work?
which systemctl     # does systemctl exist?
cat /etc/*release   # what distro is this?
uname -r            # kernel version
```
