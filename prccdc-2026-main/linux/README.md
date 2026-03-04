# Linux Hardening Tools

Scripts for hardening Linux hosts at the start of a CCDC round. Run these as close to competition start as possible — ideally before red team makes contact.

---

## Quick Reference

| Script / File | What it does | Run order |
|---|---|---|
| `bashrc_enhancements` | Hardens bash history (tamper-resistant, timestamped) | 1 — apply to every shell session |
| `disableptrace.sh` | Blocks process tracing (anti-debugging, anti-dump) | 2 — kernel-level, one-time |
| `auditdsetup.sh` | Installs auditd + loads Neo23x0 ruleset; logs all root `execve` calls | 3 — enables full syscall auditing |
| `opengrep-selfextracting/` | Packages OpenGrep + rules into a portable scanner for code review | Use when checking web app source |

---

## Detailed Tool Guides

### 1. `bashrc_enhancements` — Tamper-Resistant Bash History

**What it does**

Appends settings to your shell config that:
- Write every command to `~/.bash_history` immediately (`history -a` after each prompt)
- Disable history deduplication / suppression (`HISTCONTROL=`, `HISTIGNORE=`)
- Add timestamps to every history entry (`Wed 14:32:05 sudo rm -rf /tmp/evil`)
- Lock all history settings as read-only with `typeset -r` so a logged-in attacker cannot unset them in the same session

**Use case in CCDC**

If red team gains shell access and runs commands, those commands will be logged with timestamps and cannot be erased by toggling `HISTCONTROL`. This gives you a post-incident forensic trail.

**How to apply**

```bash
# Append to your own .bashrc (run as the user you want to harden)
cat bashrc_enhancements >> ~/.bashrc

# Apply system-wide (all future interactive shells)
sudo cat bashrc_enhancements >> /etc/bash.bashrc

# Take effect immediately in current shell
source ~/.bashrc
```

**Verify it worked**

```bash
echo $HISTTIMEFORMAT    # Should print: %a %T
echo $HISTCONTROL       # Should be empty
```

> **Note for new members:** The `typeset -r` lines make these variables read-only. If you try to `unset HISTFILE` after sourcing, bash will refuse. That's intentional — it stops an attacker from blanking the history in the same session.

---

### 2. `disableptrace.sh` — Restrict Process Tracing

**What it does**

Sets `kernel.yama.ptrace_scope = 1` via sysctl and makes it permanent by writing to `/etc/sysctl.conf`.

`ptrace` is the Linux system call used by debuggers (`gdb`, `strace`), memory dumpers, and some credential-harvesting tools (like `mimipenguin` on Linux). Restricting it to scope 1 means:
- Only a parent process can ptrace its own children
- Arbitrary cross-process tracing is blocked
- `gdb -p <pid>` against another user's process will be denied

**Use case in CCDC**

Prevents a red teamer with a low-privilege shell from using ptrace-based tools to dump credentials from other running processes.

**How to run**

```bash
sudo bash disableptrace.sh
```

**Verify it worked**

```bash
cat /proc/sys/kernel/yama/ptrace_scope   # Should output: 1
```

**Scope values reference**

| Value | Behavior |
|---|---|
| 0 | Any process can trace any other (default on many distros) |
| 1 | Restricted — only parent↔child (this script sets this) |
| 2 | Admin only (`CAP_SYS_PTRACE` required) |
| 3 | No ptrace at all |

---

### 3. `auditdsetup.sh` — Syscall Auditing with auditd

**What it does**

1. Detects the distro's package manager (Debian/RedHat/Arch/Alpine/SUSE/Gentoo)
2. Installs `auditd` (or `audit` on RHEL/CentOS)
3. Backs up existing rules to `/etc/audit/old.rules`
4. Downloads the community [Neo23x0 audit ruleset](https://github.com/Neo23x0/auditd) — a well-maintained set of rules covering privilege escalation, persistence, lateral movement, and more
5. Loads the rules immediately with `augenrules --load`
6. Adds explicit rules to log every `execve` syscall run as root (uid 0)
7. Enables and starts the `auditd` service

**Use case in CCDC**

Full syscall auditing is the most reliable way to answer "what did they run?" after an incident. With these rules active, every command run as root — even from a reverse shell — will be in the audit log.

**How to run**

```bash
sudo bash auditdsetup.sh
```

**Verify it worked**

```bash
systemctl status auditd          # Should be active (running)
auditctl -l                      # Lists loaded rules
```

**Querying audit logs**

```bash
# All commands run as root
ausearch -ua 0 -sc execve

# All commands in the last hour
ausearch --start recent

# Commands run by a specific user
ausearch -ua <uid>

# Watch audit log in real-time
tail -f /var/log/audit/audit.log | aureport --stdin -x
```

> **Note for new members:** Audit logs are in `/var/log/audit/audit.log`. The `ausearch` and `aureport` utilities make them readable. Raw audit log format is intentionally verbose — use the tools, don't try to read the raw file manually.

**Known issue**

Line 66 of the script uses `augenrules –-load` with an en-dash (`–`) instead of two hyphens (`--`). This will cause the command to fail silently. If auditing doesn't start, run manually:

```bash
sudo augenrules --load
```

---

### 4. `opengrep-selfextracting/` — Portable Code Scanner

**What it is**

A packaging wrapper that bundles [OpenGrep](https://github.com/opengrep/opengrep) (an open-source fork of Semgrep) and its ruleset into a single self-extracting `.run` file. The resulting `prog.run` can be copied to any Linux x86 host without internet access and run immediately.

**Included rulesets:** PHP, HTML, Java, JavaScript, Python, Ruby, C

**Use case in CCDC**

If you inherit a web server running PHP or a Java app, run this against the source tree to find known vulnerability patterns (command injection, SQLi, path traversal, etc.) before red team exploits them.

#### Build the self-extracting package (run once, on your prep machine)

**Prerequisites:** `makeself`, `wget`, `git`

```bash
# Install makeself if needed
sudo apt-get install makeself   # Debian/Ubuntu
sudo yum install makeself       # RHEL/CentOS

# Build
cd opengrep-selfextracting/
bash build.sh
# Creates: ./prog.run
```

#### Deploy and scan (run on the target host)

```bash
# Copy prog.run to the target host via scp/USB/whatever
scp prog.run user@target:/tmp/

# Run a scan — MUST use absolute paths
./prog.run php /var/www/html
./prog.run python /opt/myapp/src
./prog.run java /opt/tomcat/webapps/ROOT
```

**Supported language arguments**

| Argument | Scans for |
|---|---|
| `php` | PHP injection, file inclusion, SQLi |
| `python` | Flask/Django vulns, command injection |
| `java` | Deserialization, SSRF, injection |
| `javascript` | XSS, prototype pollution, injection |
| `html` | Template injection, XSS |
| `ruby` | Rails-specific vulnerabilities |
| `c` | Buffer overflows, format strings |

> **Important:** The `install.sh` inside the package auto-detects whether the host uses glibc (`manylinux`) or musl (`musllinux`, e.g. Alpine Linux) and runs the correct binary.

---

## Recommended CCDC Run Order

```
T+0:00  Apply bashrc_enhancements to all active sessions
T+0:02  Run disableptrace.sh
T+0:03  Run auditdsetup.sh
T+0:05  Run linux/backup_automation scripts (see backup_automation/README.md)
T+??    Run opengrep scan if you have a web app to assess
```

Run everything as root. Each script is designed to be idempotent or low-risk to re-run.
