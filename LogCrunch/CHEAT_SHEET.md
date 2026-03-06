# LogCrunch Cheat Sheet
### Quick reference for CCDC competition use

> Full walkthrough: [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md)

---

## Starting LogCrunch

```bash
# Start the server (run once, keep terminal open)
./LogCrunch-Server 0.0.0.0 5000 ./certs/server.crt ./certs/server.key 127.0.0.1 8080

# Start an agent on a monitored host
./LogCrunch-Agent <server-ip> 5000 ./targets.yaml n

# Open the web UI
# Browser → http://127.0.0.1:8080
# Username: admin  |  Password: printed on first server startup
```

---

## SQL Cheat Sheet

### Anatomy of a query

```sql
SELECT <columns>     -- what to show (use * for everything)
FROM logs            -- always "logs"
WHERE <condition>    -- optional filter
ORDER BY timestamp DESC  -- newest first
LIMIT 50;            -- always use a limit!
```

### Column quick reference

| Column | Contains |
|---|---|
| `host` | Server name (e.g. `webserver`) |
| `name` | Log source label (e.g. `Auth`, `Apache Access`) |
| `timestamp` | Unix time (big number — use time helpers below) |
| `raw` | The original log line text |
| `parsed` | JSON of extracted fields |
| `module` | Parsing rule used (`syslog`, `apache`) |
| `path` | Source file path on the agent host |

### Filtering tricks

```sql
-- Exact match
WHERE host = 'webserver'

-- Contains text (case-sensitive)
WHERE raw LIKE '%Failed password%'

-- Multiple conditions (both must be true)
WHERE host = 'webserver' AND raw LIKE '%Failed%'

-- Either condition
WHERE raw LIKE '%Failed%' OR raw LIKE '%Invalid%'

-- Last N minutes  (replace 1800 with seconds: 60=1min, 3600=1hr)
WHERE timestamp > strftime('%s', 'now') - 1800

-- Last 1 hour
WHERE timestamp > strftime('%s', 'now') - 3600
```

---

## The CCDC Hit List — Queries to Run on Repeat

### 1. Health check — are logs flowing?

```sql
-- Logs per host (run first, establish baseline counts)
SELECT host, COUNT(*) AS total
FROM logs
GROUP BY host
ORDER BY total DESC;

-- All log sources currently flowing
SELECT DISTINCT name, host, module FROM logs;
```

---

### 2. SSH / Login attacks

```sql
-- Failed logins (brute force indicator)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%Failed password%'
ORDER BY timestamp DESC LIMIT 50;

-- Successful logins (has anyone gotten in?)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%Accepted password%'
   OR raw LIKE '%Accepted publickey%'
ORDER BY timestamp DESC LIMIT 50;

-- Failed login counts by message (spot brute-force at a glance)
SELECT raw, COUNT(*) AS attempts
FROM logs
WHERE raw LIKE '%Failed password%'
GROUP BY raw
ORDER BY attempts DESC LIMIT 20;

-- Invalid / unknown username attempts
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%Invalid user%'
   OR raw LIKE '%invalid user%'
ORDER BY timestamp DESC LIMIT 50;
```

---

### 3. Privilege escalation

```sql
-- sudo usage (who is escalating to root?)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%sudo%'
ORDER BY timestamp DESC LIMIT 50;

-- Root login attempts
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%root%'
  AND (raw LIKE '%Failed%' OR raw LIKE '%Accepted%')
ORDER BY timestamp DESC LIMIT 50;

-- su command usage
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '% su %' OR raw LIKE '%su:%'
ORDER BY timestamp DESC LIMIT 30;
```

---

### 4. New user / account changes

```sql
-- New account creation
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%useradd%' OR raw LIKE '%adduser%'
ORDER BY timestamp DESC LIMIT 20;

-- Password changes
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%passwd%'
ORDER BY timestamp DESC LIMIT 20;

-- Group changes
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%usermod%' OR raw LIKE '%groupadd%'
ORDER BY timestamp DESC LIMIT 20;
```

---

### 5. Web server attacks (Apache/Nginx)

```sql
-- Recent web requests
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
ORDER BY timestamp DESC LIMIT 100;

-- HTTP 4xx/5xx errors (scanning, exploitation)
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
  AND (raw LIKE '%" 4%' OR raw LIKE '%" 5%')
ORDER BY timestamp DESC LIMIT 50;

-- Common attack path probing
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
  AND (raw LIKE '%/etc/passwd%'
    OR raw LIKE '%cmd.exe%'
    OR raw LIKE '%.php?%'
    OR raw LIKE '%/admin%'
    OR raw LIKE '%/shell%'
    OR raw LIKE '%/wp-admin%'
    OR raw LIKE '%/phpmyadmin%'
    OR raw LIKE '%../%')
ORDER BY timestamp DESC LIMIT 50;

-- Requests from a specific IP (fill in attacker IP)
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
  AND raw LIKE '%192.168.1.50%'
ORDER BY timestamp DESC LIMIT 100;
```

---

### 6. Drill down on a specific host

```sql
-- Everything from one host in the last 30 minutes
SELECT timestamp, name, raw
FROM logs
WHERE host = 'webserver'
  AND timestamp > strftime('%s', 'now') - 1800
ORDER BY timestamp DESC LIMIT 100;

-- Everything from one host (all time)
SELECT timestamp, name, raw
FROM logs
WHERE host = 'webserver'
ORDER BY timestamp DESC LIMIT 100;
```

---

### 7. General suspicious patterns

```sql
-- Cron jobs / scheduled task manipulation
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%cron%' OR raw LIKE '%crontab%'
ORDER BY timestamp DESC LIMIT 30;

-- File permission changes
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%chmod%' OR raw LIKE '%chown%'
ORDER BY timestamp DESC LIMIT 30;

-- Network tools that shouldn't be running
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%netcat%'
   OR raw LIKE '% nc %'
   OR raw LIKE '%nmap%'
   OR raw LIKE '%curl%'
   OR raw LIKE '%wget%'
ORDER BY timestamp DESC LIMIT 30;

-- Anything in /tmp (common attacker staging area)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%/tmp/%'
ORDER BY timestamp DESC LIMIT 30;
```

---

## Time Helpers

| Expression | Means |
|---|---|
| `strftime('%s', 'now') - 60` | Last 1 minute |
| `strftime('%s', 'now') - 300` | Last 5 minutes |
| `strftime('%s', 'now') - 900` | Last 15 minutes |
| `strftime('%s', 'now') - 1800` | Last 30 minutes |
| `strftime('%s', 'now') - 3600` | Last 1 hour |
| `strftime('%s', 'now') - 7200` | Last 2 hours |

---

## HTTP Status Code Reference

| Code | Meaning | Watch for |
|---|---|---|
| `200` | OK | Normal |
| `301` / `302` | Redirect | Normal |
| `400` | Bad Request | Possible fuzzing |
| `401` | Unauthorized | Login probing |
| `403` | Forbidden | Access probing |
| `404` | Not Found | Directory/file scanning |
| `500` | Server Error | Possible exploitation |
| `503` | Service Unavailable | Possible DoS |

---

## Syslog Line Anatomy

```
Mar  4 14:32:01   webserver   sshd[1234]:   Failed password for root from 192.168.1.50 port 54321 ssh2
│                 │           │             │
│                 │           │             └── What happened
│                 │           └── Process[PID]
│                 └── Hostname
└── Timestamp
```

---

## Common `name` Values (by default config)

| `name` value | Log source | Key things to look for |
|---|---|---|
| `Auth` | `/var/log/auth.log` | Failed logins, sudo, new users |
| `Apache Access` | `/var/log/apache2/access.log` | HTTP errors, attack paths |
| `Syslog` | `/var/log/syslog` | General system events, cron |
| `MySQL` | MySQL error log | Failed DB logins |

*(Actual names depend on your team's `targets.yaml` config.)*

---

## SQL Syntax Reminders

```
✅  WHERE raw LIKE '%Failed%'       -- single quotes around text
❌  WHERE raw LIKE "%Failed%"       -- double quotes won't work in SQLite

✅  LIMIT 50                        -- always include this
❌  SELECT * FROM logs;             -- no limit = may freeze browser

✅  AND, OR                         -- combine conditions
✅  COUNT(*), GROUP BY              -- for counting/grouping

-- Comments in SQL (ignored by the database)
-- This is a comment
```

---

## Troubleshooting One-Liners

```sql
-- Is the table there?
SELECT name FROM sqlite_master WHERE type='table';

-- What columns does logs have?
PRAGMA table_info(logs);

-- How many logs total?
SELECT COUNT(*) FROM logs;

-- Show me the 5 most recent logs (any host)
SELECT * FROM logs ORDER BY timestamp DESC LIMIT 5;

-- What distinct hosts are reporting?
SELECT DISTINCT host FROM logs;

-- What distinct log sources are there?
SELECT DISTINCT name FROM logs;
```
