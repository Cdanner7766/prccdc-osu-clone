# LogCrunch Beginner's Guide
### For students new to cybersecurity and the terminal

---

> **Scenario:** It's competition day. Your team just sat down at a CCDC event. You've been handed access to three servers and told to "keep services running and keep attackers out." Your job is to watch the logs. This guide walks you through doing exactly that with LogCrunch.

---

## Before You Start: Key Vocabulary

You don't need to memorize these — just refer back as you go.

| Word | What it means |
|---|---|
| **Log** | A text file that records what happened on a computer. Every login attempt, command run, and web page visited leaves a record. |
| **SIEM** | "Security Information and Event Management." A tool that collects logs from many computers and lets you search all of them at once. LogCrunch is a lightweight SIEM. |
| **Terminal** | The black window where you type commands. Also called a shell, command line, or console. |
| **Agent** | A small program you run on each server you want to monitor. It reads the server's log files and sends them to the central LogCrunch server. |
| **Server (LogCrunch)** | The central computer that collects all logs from all agents and stores them. This is also where the web interface runs. |
| **Query** | A question you ask a database. "Show me all failed login attempts from the last hour" is a query. |
| **SQL** | The language used to write queries. Stands for Structured Query Language. You'll learn the basics here. |
| **TLS** | Encryption for network connections. Makes it so no one can eavesdrop on the logs being sent from agents to the server. |

---

## Part 1 — What Is LogCrunch Doing?

Imagine three servers in your CCDC network:
- **`webserver`** — running a website
- **`dbserver`** — running a database
- **`firewall`** — controlling network traffic

Each of these servers is generating logs constantly. The problem: logs are spread across three different machines. To read them you'd have to SSH into each one separately and hunt through text files. That's slow.

LogCrunch solves this by running a small **agent** on each server. Each agent reads that server's log files and sends the entries — in real time — to one central **LogCrunch server**. You sit at the LogCrunch web UI, and you can search all three servers' logs at once.

```
webserver logs ──┐
                 │   (all sent over encrypted network)
dbserver logs ───┼──────────────────▶  LogCrunch Server
                 │                      (stores everything,
firewall logs ───┘                       serves web UI)
```

---

## Part 2 — Starting LogCrunch

### Step 1: Open a terminal

On Linux, look for an application called **Terminal**, **Console**, or press `Ctrl+Alt+T`.

You'll see a prompt that looks like:
```
user@hostname:~$
```
The `$` means the terminal is ready for your input. Everything after `$` in this guide is something you type.

### Step 2: Navigate to the LogCrunch folder

```bash
cd /home/user/prccdc-osu-clone/LogCrunch
```

**What this does:** `cd` means "change directory." Think of it like double-clicking a folder. Now you're "inside" the LogCrunch folder.

To confirm you're in the right place:
```bash
ls
```
You should see files like `LogCrunch-Server`, `go.mod`, `README.MD`, etc.

### Step 3: Start the LogCrunch server

```bash
./LogCrunch-Server 0.0.0.0 5000 ./certs/server.crt ./certs/server.key 127.0.0.1 8080
```

Breaking down what each part means:
- `./LogCrunch-Server` — run the server program
- `0.0.0.0 5000` — listen for agents on all network interfaces, port 5000
- `./certs/server.crt ./certs/server.key` — the TLS certificate and key (encryption)
- `127.0.0.1 8080` — serve the web UI on localhost, port 8080

**The first time you run it**, the server will print something like:
```
Default password: xK9mPqR2
```
**Copy that password.** You'll need it to log into the web UI.

> **Tip:** Don't close this terminal. The server runs in it. Open a new terminal tab or window for everything else (`Ctrl+Shift+T` in most terminals, or just open a new terminal window).

### Step 4: Start an agent on a monitored server

On each server you want to monitor, run:
```bash
./LogCrunch-Agent 10.0.0.5 5000 ./targets.yaml n
```

- `10.0.0.5` — the IP address of your LogCrunch server
- `5000` — the port the server is listening on
- `./targets.yaml` — your config file (tells the agent which log files to read)
- `n` — don't verify TLS certificates (safe for self-signed certs in a lab)

You should see output like:
```
Connected to 10.0.0.5:5000
Tailing: /var/log/auth.log
Tailing: /var/log/apache2/access.log
```

---

## Part 3 — Logging Into the Web UI

Open a web browser and go to:
```
http://127.0.0.1:8080
```

You'll see a login screen.

- **Username:** `admin`
- **Password:** the one printed when the server started (e.g., `xK9mPqR2`)

**You will be immediately asked to change your password.** Do it. Choose something your team knows but an attacker would not guess.

After changing the password, you'll land on the **Dashboard**.

### The web UI pages

| Page | What it shows |
|---|---|
| **Dashboard** | Overview of the server status |
| **Connections** | Which agents are currently connected and sending logs |
| **Logs** | A live feed of recent log entries |
| **Query** | Where you write SQL to search the logs |

**Check the Connections page first.** Make sure all your agents show up. If an agent is missing, it means either the agent isn't running or the network connection is broken — investigate before you continue.

---

## Part 4 — Understanding SQL (The Query Language)

SQL is how you ask LogCrunch questions. Every query follows this basic pattern:

```sql
SELECT [what you want to see]
FROM [which table]
WHERE [filter conditions]
ORDER BY [how to sort]
LIMIT [how many results];
```

Think of it like a sentence: "**Show me** [these columns] **from** [this table] **where** [this condition is true]."

### The logs table

All your log data lives in a table called `logs`. Its columns are:

| Column | What's in it | Example value |
|---|---|---|
| `log_id` | A unique number for each log entry | `1042` |
| `name` | The label you gave this log source in the config | `Auth`, `Apache Access` |
| `path` | The file path the log came from | `/var/log/auth.log` |
| `host` | Which server sent this log | `webserver` |
| `timestamp` | When the log was recorded (Unix time — a big number) | `1709536000` |
| `module` | Which parsing rule was used | `syslog`, `apache` |
| `raw` | The original, unmodified log line | `Mar 4 14:32:01 webserver sshd[1234]: Failed password...` |
| `parsed` | Structured fields extracted from the raw line (JSON) | `{"process":"sshd","pid":"1234","message":"Failed password..."}` |

The column you'll use most is `raw` — it's the actual log text.

### Your first query

Go to the **Query** page and type:

```sql
SELECT * FROM logs LIMIT 10;
```

- `SELECT *` means "show me all columns"
- `FROM logs` means "from the logs table"
- `LIMIT 10` means "only show 10 results"

Hit **Run**. You should see a table of log entries appear.

> **Always use LIMIT.** Without it, a query might try to return millions of rows and crash your browser. Start with `LIMIT 50` or `LIMIT 100`.

---

## Part 5 — The CCDC Scenario: Your First Hour

Here's how a real competition hour might play out and what you'd query at each step.

---

### T+0:00 — Establish a baseline

Before red team does anything, understand what *normal* looks like. Run:

```sql
-- How many logs do we have total, by server?
SELECT host, COUNT(*) as total_logs
FROM logs
GROUP BY host
ORDER BY total_logs DESC;
```

Write down the counts. This is your normal baseline. If one server's count suddenly jumps, something is happening there.

```sql
-- What log sources are we receiving?
SELECT DISTINCT name, host, module FROM logs;
```

This tells you which log types are flowing in. Make sure you see logs from all the servers you expect.

---

### T+0:10 — Check for failed login attempts

SSH brute force is one of the first things red teams try. Check for it:

```sql
-- Failed SSH login attempts
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%Failed password%'
ORDER BY timestamp DESC
LIMIT 50;
```

**What `LIKE '%Failed password%'` means:** The `%` is a wildcard — it matches anything. So this finds any log line that *contains* the phrase "Failed password" anywhere in it.

If you see a flood of these from the same IP address, red team is probably brute-forcing SSH.

```sql
-- See failed logins grouped by the source (to spot brute force)
SELECT host, raw, COUNT(*) as attempts
FROM logs
WHERE raw LIKE '%Failed password%'
GROUP BY raw
ORDER BY attempts DESC
LIMIT 20;
```

---

### T+0:15 — Check for successful logins

Now check if any of those brute force attempts *worked*:

```sql
-- Successful logins
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%Accepted password%'
   OR raw LIKE '%Accepted publickey%'
ORDER BY timestamp DESC
LIMIT 50;
```

Successful logins aren't always bad — your team logs in too. But look for unexpected usernames or login times.

---

### T+0:20 — Check for root activity

Root (the administrator) shouldn't be doing much in normal operation. Suspicious root activity is a red flag:

```sql
-- Any sudo usage (privilege escalation)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%sudo%'
ORDER BY timestamp DESC
LIMIT 50;
```

```sql
-- Root login attempts
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%root%'
  AND (raw LIKE '%Failed%' OR raw LIKE '%Accepted%')
ORDER BY timestamp DESC
LIMIT 50;
```

---

### T+0:30 — Watch your web server

If your team is running a web application, red team will probe it. Check Apache access logs:

```sql
-- Recent web requests
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
ORDER BY timestamp DESC
LIMIT 100;
```

```sql
-- HTTP errors (might indicate scanning or exploitation attempts)
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
  AND (raw LIKE '%" 4%' OR raw LIKE '%" 5%')
ORDER BY timestamp DESC
LIMIT 50;
```

The `" 4` and `" 5` patterns match HTTP 4xx and 5xx status codes in Apache log format.

```sql
-- Requests for common attack paths (shells, admin pages, etc.)
SELECT timestamp, host, raw
FROM logs
WHERE name = 'Apache Access'
  AND (raw LIKE '%/etc/passwd%'
    OR raw LIKE '%cmd.exe%'
    OR raw LIKE '%.php?%'
    OR raw LIKE '%/admin%'
    OR raw LIKE '%/wp-admin%')
ORDER BY timestamp DESC
LIMIT 50;
```

---

### T+0:45 — Focus on one suspicious host

Suppose the query above shows a ton of weird requests hitting `webserver`. Now drill down on just that host:

```sql
-- All logs from webserver in the last 30 minutes
SELECT timestamp, name, raw
FROM logs
WHERE host = 'webserver'
  AND timestamp > strftime('%s', 'now') - 1800
ORDER BY timestamp DESC
LIMIT 100;
```

**What `strftime('%s', 'now') - 1800` means:**
- `strftime('%s', 'now')` = the current time as a Unix timestamp (a big number)
- `- 1800` = subtract 1800 seconds (30 minutes)
- So this filters to only logs from the last 30 minutes

---

### T+1:00 — Check for new accounts

Red team often creates backdoor user accounts. Compare what you see now against what you expect:

```sql
-- Any log lines mentioning "useradd" or "adduser" (new account creation)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%useradd%'
   OR raw LIKE '%adduser%'
ORDER BY timestamp DESC
LIMIT 20;
```

```sql
-- Any log lines mentioning "passwd" (password changes)
SELECT timestamp, host, raw
FROM logs
WHERE raw LIKE '%passwd%'
ORDER BY timestamp DESC
LIMIT 20;
```

---

## Part 6 — Reading Individual Log Lines

When you find something suspicious, the `raw` column shows the original log line. Here's how to read common formats.

### Syslog format (auth.log, syslog)

```
Mar  4 14:32:01 webserver sshd[1234]: Failed password for root from 192.168.1.50 port 54321 ssh2
```

| Part | Meaning |
|---|---|
| `Mar  4 14:32:01` | Date and time |
| `webserver` | Hostname |
| `sshd[1234]` | Process name and PID |
| `Failed password for root` | What happened |
| `from 192.168.1.50` | Attacker's IP address |
| `port 54321` | Port the connection came from |

### Apache access log format

```
192.168.1.50 - - [04/Mar/2026:14:32:01 +0000] "GET /admin HTTP/1.1" 404 512
```

| Part | Meaning |
|---|---|
| `192.168.1.50` | Visitor's IP address |
| `[04/Mar/2026:14:32:01 +0000]` | Date and time |
| `"GET /admin HTTP/1.1"` | What page was requested |
| `404` | HTTP response code (404 = Not Found) |
| `512` | Response size in bytes |

**Common HTTP status codes:**

| Code | Meaning | CCDC relevance |
|---|---|---|
| `200` | OK — page served normally | Normal |
| `301/302` | Redirect | Usually normal |
| `403` | Forbidden — no access | Could be probing |
| `404` | Not Found | Could be scanning for hidden files |
| `500` | Server Error | Could be an exploitation attempt |

---

## Part 7 — Staying Organized During Competition

### Label your findings

When you find something suspicious, note:
1. **What you found** — e.g., "repeated failed logins"
2. **Which host** — e.g., `webserver`
3. **The time range** — e.g., "14:30–14:45"
4. **The attacker's IP** — e.g., `192.168.1.50`
5. **The exact query you ran** — so your teammates can reproduce it

### Triage priority

Not everything in the logs is an attack. Triage like this:

1. **Active intrusion** — root login succeeded, new user created, web shell uploaded → tell your team immediately
2. **Active probing** — brute force in progress, web scanning → monitor and block at firewall if possible
3. **Finished probe** — single scan from hours ago, no follow-up → low priority, keep watching

### Keep querying

LogCrunch's strength is that logs keep flowing in. A query you ran 10 minutes ago might show different results now. Re-run your key queries periodically throughout the competition.

---

## Part 8 — What to Do When You Find Something

If you find evidence of an active attack, do this in order:

1. **Don't panic.** Log what you see with a screenshot or copy-paste the log line and query.
2. **Tell your team.** Announce on your team's communication channel: "SSH brute force on webserver from 192.168.1.50, started at 14:32."
3. **Keep watching.** Stay on LogCrunch. Did the brute force succeed? Are there other attacks happening elsewhere?
4. **Let the firewall/system people respond.** If your team has someone on networking or system hardening, give them the attacker IP — they can block it.
5. **Document everything.** CCDC often includes scored injects (reports). Your log evidence can go into those reports.

---

## Troubleshooting

**The web UI won't load**

- Make sure the server terminal is still running (didn't get closed)
- Check you're going to the right address: `http://127.0.0.1:8080`
- Make sure no other program is using port 8080

**No logs are appearing**

- Check the Connections page — are any agents connected?
- On the agent machine, make sure the agent is still running
- Check the agent's terminal output for error messages

**My query returns an error**

- Check for typos — SQL is picky about spelling
- Make sure every opening parenthesis `(` has a closing one `)`
- Make sure string values are in single quotes: `'webserver'` not `"webserver"`
- Check that you have a semicolon `;` at the end of the query

**A query runs but shows 0 results**

- Try removing some of the `WHERE` conditions — maybe the filter is too narrow
- Check the `name` column value: what does `SELECT DISTINCT name FROM logs;` show?
- Make sure the agent is monitoring the right log file

---

*Continue to the [Cheat Sheet](CHEAT_SHEET.md) for a quick-reference card of the most important queries.*
