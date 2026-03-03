# LogCrunch — Analysis, Setup Guide & Usage Guidelines

> Version: v0.11.1
> Source: `github.com/TLop503/LogCrunch`
> Author: TLop (Honor's Undergrad thesis project)

---

## Table of Contents

1. [Summary](#1-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Setup Guide](#3-setup-guide)
4. [Configuration Reference](#4-configuration-reference)
5. [Usage Guidelines](#5-usage-guidelines)
6. [Built-in Parsing Modules](#6-built-in-parsing-modules)
7. [Web UI Reference](#7-web-ui-reference)
8. [Known Limitations & Roadmap](#8-known-limitations--roadmap)

---

## 1. Summary

**LogCrunch** is a lightweight, open-source **proto-SIEM** (Security Information and Event Management system). It is designed to minimize computational overhead while still providing centralized log aggregation, real-time monitoring, and query capabilities — making it well-suited for:

- **Collegiate Cyber Defense Competitions (CCDC)**
- **Homelabs**
- **Small-scale production environments** where enterprise SIEMs are impractical

### What it does

| Capability | Detail |
|---|---|
| Log collection | Agents tail log files and systemd journals in real-time |
| Log parsing | Regex-based schemas extract structured fields from raw log lines |
| Centralized storage | All logs are shipped to a single server and stored in SQLite |
| Secure transport | All agent-to-server traffic is encrypted with TLS |
| Web UI | Browser-based interface for querying and investigating logs |
| Heartbeat monitoring | Agents send keepalives every 60 seconds so you know if one goes silent |
| Multi-source | A single agent can watch many files and services simultaneously |

### What it is not

LogCrunch is not a full enterprise SIEM. It lacks alerting rules, threat intelligence feeds, dashboards, and long-term retention tooling. It is purpose-built for fast deployment and low resource consumption in competitive or lab environments.

---

## 2. Architecture Overview

```
  [ Monitored Host ]          [ Monitored Host ]
  ┌────────────────┐          ┌────────────────┐
  │  LogCrunch     │          │  LogCrunch     │
  │  Agent         │          │  Agent         │
  │  (Go binary)   │          │  (Go binary)   │
  └───────┬────────┘          └───────┬────────┘
          │  TLS/TCP                  │  TLS/TCP
          └──────────────┬────────────┘
                         ▼
              [ Central Server ]
              ┌───────────────────────────────┐
              │  LogCrunch Server (Go binary)  │
              │                               │
              │  ┌──────────┐  ┌──────────┐   │
              │  │  Intake  │  │  Web UI  │   │
              │  │  :5000   │  │  :8080   │   │
              │  └────┬─────┘  └─────┬────┘   │
              │       └──────┬────────┘        │
              │              ▼                 │
              │         ┌─────────┐            │
              │         │ SQLite  │            │
              │         │  DB     │            │
              │         └─────────┘            │
              └───────────────────────────────┘
```

### Key components

- **Agent** — deployed on every host you want to monitor. Reads log files and systemd journals, parses them according to a YAML config, and streams JSON-encoded log records to the server over TLS.
- **Server** — receives log records from all agents, stores them in SQLite, and serves the web UI.
- **Hemoglobin** (agent sub-component) — the log-tailing engine. Handles log rotation transparently.
- **MetaParser** (agent sub-component) — applies user-defined or built-in regex schemas to extract structured fields from raw log lines.
- **Web UI** — chi-based HTTP server serving an embedded template UI for login, connection status, and SQL-based log querying.

---

## 3. Setup Guide

### Prerequisites

| Requirement | Notes |
|---|---|
| Go 1.24.0+ | Required to build from source |
| OpenSSL | Required to generate TLS certificates |
| Python 3 | Required only for the automated setup script |
| Linux (UNIX) | Windows agent support is not yet available |
| `curl`, `tar`, `git` | Required by the automated setup script |

Directory permissions required on the server host:
- Read + write to `/var/log/LogCrunch/`
- Read + write to `/opt/LogCrunch/`

---

### Option A — Automated Setup (Recommended for CCDC)

The utility script handles Go installation, certificate generation, and binary compilation automatically.

```bash
cd LogCrunch/LogCrunch-Utils/setup_scripts/
python3 server_setup.py
```

---

### Option B — Manual Setup

#### Step 1 — Build from source

```bash
cd LogCrunch

# Build server and agent binaries
go build -o LogCrunch-Server ./server
go build -o LogCrunch-Agent ./agent
```

#### Step 2 — Generate TLS certificates

You need a certificate and key for the server. Self-signed is acceptable for lab/CCDC use:

```bash
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -keyout certs/server.key \
    -out certs/server.crt -days 365 -nodes \
    -subj "/CN=logcrunch-server"
```

#### Step 3 — Start the server

```bash
./LogCrunch-Server <log_host> <log_port> <cert_path> <key_path> [http_host] [http_port]

# Example — listen for agents on all interfaces at port 5000,
# serve the Web UI on localhost port 8080
./LogCrunch-Server 0.0.0.0 5000 ./certs/server.crt ./certs/server.key 127.0.0.1 8080
```

**First-run behaviour:**
- A randomized default password is printed to `stdout`. Copy it.
- Log into the Web UI and change the password before you can access the query interface.
- The SQLite database is created at `/var/log/LogCrunch/logcrunch.logDB`.
- User accounts are stored at `/opt/LogCrunch/users/accounts.userDB`.

> **Locked out?** Delete `/opt/LogCrunch/users/` and restart the server to regenerate credentials.

#### Step 4 — Write an agent config

Create a `targets.yaml` on each host you want to monitor. See [Configuration Reference](#4-configuration-reference) for the full schema.

Minimal example:

```yaml
---
Targets:
  - name: Auth
    path: /var/log/auth.log
    severity: low
    custom: false
    module: syslog
Services:
  - name: SSH
    key: ssh
    severity: high
...
```

#### Step 5 — Start the agent

```bash
./LogCrunch-Agent <server_host> <port> <config_file> <verify_certs_y/n>

# Example — connecting to server at 10.0.0.5, skipping cert verification
./LogCrunch-Agent 10.0.0.5 5000 ./targets.yaml n
```

> Pass `n` for cert verification when using self-signed certificates. Pass `y` in production environments with properly signed certificates.

#### Step 6 — Open firewall ports (if applicable)

The server needs to accept inbound TCP on the intake port from agent hosts:

```bash
# Example using ufw
ufw allow 5000/tcp    # agent intake
ufw allow 8080/tcp    # web UI (restrict to trusted IPs in production)
```

---

### Development / Testing

Use the included development script to run both server and agent locally:

```bash
cd LogCrunch
./scripts/dev_start.sh
```

---

## 4. Configuration Reference

Agent configuration is a YAML file with two top-level sections: `Targets` (log files) and `Services` (systemd journals).

### Targets (log files)

```yaml
Targets:
  - name: <display name>          # Label shown in the Web UI
    path: <absolute path>         # Path to the log file
    severity: <low|high|info>     # Informational severity tag
    custom: <true|false>          # true = inline regex, false = built-in module
    module: <module name>         # Built-in module name OR custom label

    # Only required when custom: true
    regex: '<named-capture regex>'
    schema:
      <field_name>: <string|int|float>
```

### Services (systemd journal)

```yaml
Services:
  - name: <display name>          # Label shown in the Web UI
    key: <systemd unit name>      # The systemd service key (e.g. "ssh", "nginx")
    severity: <low|high|info>
```

### Full example

```yaml
---
Targets:
  - name: Auth
    path: /var/log/auth.log
    severity: low
    custom: false
    module: syslog

  - name: Apache Access
    path: /var/log/apache2/access.log
    severity: high
    custom: false
    module: apache

  - name: Custom App Log
    path: /var/log/myapp/app.log
    severity: high
    custom: true
    module: myapp
    regex: '^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+\[(?P<level>\w+)\]\s+(?P<message>.*)$'
    schema:
      timestamp: string
      level: string
      message: string

Services:
  - name: SSH Service
    key: ssh
    severity: high

  - name: MySQL
    key: mysql
    severity: low
...
```

---

## 5. Usage Guidelines

### Querying logs in the Web UI

The query interface accepts raw SQLite SQL. The primary table is `logs` with the following columns:

| Column | Type | Description |
|---|---|---|
| `log_id` | INTEGER | Auto-increment primary key |
| `name` | TEXT | Log target name from config |
| `path` | TEXT | Source file path |
| `host` | TEXT | Hostname of the reporting agent |
| `timestamp` | INTEGER | Unix epoch timestamp |
| `module` | TEXT | Parsing module / schema name |
| `raw` | TEXT | Original unmodified log line |
| `parsed` | TEXT | JSON string of extracted fields |

#### Useful example queries

```sql
-- All logs from a specific host
SELECT * FROM logs WHERE host = 'webserver-01' ORDER BY timestamp DESC LIMIT 100;

-- Failed SSH authentication attempts
SELECT timestamp, host, raw FROM logs
WHERE name = 'Auth' AND raw LIKE '%Failed password%'
ORDER BY timestamp DESC;

-- Logs from the last hour
SELECT * FROM logs
WHERE timestamp > strftime('%s', 'now') - 3600
ORDER BY timestamp DESC;

-- Count events per host
SELECT host, COUNT(*) as event_count FROM logs GROUP BY host ORDER BY event_count DESC;

-- Apache logs with HTTP 4xx/5xx errors
SELECT host, parsed FROM logs
WHERE module = 'apache' AND (parsed LIKE '%"4__"%' OR parsed LIKE '%"5__"%')
ORDER BY timestamp DESC LIMIT 50;

-- Logs from a specific time window
SELECT * FROM logs
WHERE timestamp BETWEEN 1709500000 AND 1709600000
ORDER BY timestamp;
```

---

### Recommended deployment pattern for CCDC

```
Topology:
  10.0.0.5   — LogCrunch Server (internal only)
  10.0.0.10  — Webserver agent  (auth.log, apache access.log)
  10.0.0.11  — Database agent   (mysql.log, mysql service)
  10.0.0.12  — Firewall agent   (syslog, ufw service)
```

1. Deploy the server first. Note the default password from stdout.
2. Change the password via the Web UI immediately.
3. Deploy agents on each host simultaneously (they will reconnect automatically on failure).
4. Verify connections in the Web UI "Connections" page.
5. Use the query interface to baseline normal traffic before an incident occurs.

---

### Security considerations

| Concern | Recommendation |
|---|---|
| TLS certificates | Use properly signed certs in sensitive environments; avoid `n` for cert verification outside of labs |
| Web UI exposure | Bind the HTTP port to a trusted interface only, not `0.0.0.0` |
| Password | Change the default immediately and use a strong unique password |
| Account lockout | If locked out, deleting `/opt/LogCrunch/users/` resets all accounts |
| Firewall | Restrict agent intake port to known agent IPs only |
| Log retention | `/var/log/LogCrunch/firehose.log` grows unbounded; plan rotation via `logrotate` |
| Run as dedicated user | Avoid running as root; create a `logcrunch` system user with scoped permissions |

---

### Performance notes

- LogCrunch is intentionally lightweight. A single server can handle multiple agents with minimal CPU and memory overhead.
- SQLite performs well for querying moderate log volumes (millions of records). For very high-throughput environments, index planning or periodic archival may be needed.
- Each agent spawns one goroutine per log target. Monitoring dozens of files is feasible; monitoring hundreds simultaneously is untested.

---

## 6. Built-in Parsing Modules

Use these module names with `custom: false` in your target config.

| Module | Matches | Key fields extracted |
|---|---|---|
| `syslog` | RFC 5424 / standard Linux syslog | `timestamp`, `host`, `process`, `pid`, `message` |
| `apache` | Apache/Nginx combined access log | `remote_ip`, `user`, `timestamp`, `request`, `status`, `bytes` |

> **Note:** The `tbd` module placeholder exists in example configs for `faillog` and `boot.log` but is not yet implemented. Use custom regex for those targets in the meantime.

---

## 7. Web UI Reference

| Page | Path | Description |
|---|---|---|
| Login | `/login` | Session authentication |
| Dashboard | `/` | Overview of server status |
| Connections | `/connections` | Active agents and their metadata |
| Logs | `/logs` | Browse recent log entries |
| Query | `/query` | Free-form SQL query interface |

**First login flow:**
1. Server prints the default password to `stdout` on startup.
2. Navigate to the Web UI and log in with `admin` / `<printed password>`.
3. You will be forced to set a new password before the query interface is accessible.

---

## 8. Known Limitations & Roadmap

| Item | Status |
|---|---|
| Windows agent support | Planned, not yet available |
| `faillog` / `boot.log` built-in modules | Listed as `tbd` in code |
| Graceful agent shutdown | Not implemented; requires kill signal |
| Alerting / notifications | Not implemented |
| Docker support | Exists but marked as unstable |
| Systemd service unit files | Not yet provided |
| Log retention / archival | Manual; no built-in rotation policy |

---

*This guide was generated from analysis of LogCrunch v0.11.1 source code.*
