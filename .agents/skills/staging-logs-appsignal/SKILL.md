---
name: staging-logs-appsignal
description: Read kw-app logs (Rails log in the staging container, kamal-proxy access log, Puma/boot output, appsignal.log) and AppSignal incidents/traces to find why a request failed or is slow. Use after a staging check fails, for 500s, slow requests, deploy/boot problems, or when asked to "check the logs" or "check AppSignal".
allowed-tools: Read, Bash
---

# Staging Logs & AppSignal (kw-app)

Read-only diagnostics. Nothing here changes data or configuration.

## Where things are (verified 2026-11)

| What | Where | How to read |
|------|-------|-------------|
| **Rails log (staging)** | `log/staging.log` **inside** the web container. **Not on stdout** (`RAILS_LOG_TO_STDOUT` is unset) | `docker exec <c> tail/grep log/staging.log` (recipes below) |
| Rails log (production) | stdout (`config.logger = Logger.new(STDOUT)`) | `kamal app logs -d production` / `docker logs` |
| Boot / Puma / Sidekiq banner | container stdout | `docker logs <c>` or `kamal app logs -d staging` |
| Access log (every request, JSON) | `kamal-proxy` container on the Pi | `docker logs kamal-proxy` |
| AppSignal agent log | `log/appsignal.log` in the container | `docker exec <c> tail log/appsignal.log` |
| AppSignal incidents, traces, metrics | appsignal.com, app **KwApp**, envs `staging` / `production` | AppSignal CLI or MCP (see below) |

> `kamal app logs -d staging` only shows boot/Puma output. Requests and exceptions are in `log/staging.log`. If you see an empty-looking log, you are probably reading the wrong one.

AppSignal receives **errors, performance traces and metrics**. Application *log lines* are **not** shipped to AppSignal (no AppSignal logger is configured), so `logs search` in AppSignal will be empty. Use the container log for log lines.

Log level is `:debug` in staging and production, so logs include SQL and rendering lines and are verbose. The staging log is a single, never-rotated file; use `tail`/`grep`, never `cat` it into the conversation.

## Access pattern

Everything runs over SSH on the Pi. The container name changes on every deploy, so discover it on the server (single quotes so `$(...)` expands remotely):

```bash
ssh pi5main.local 'C=$(docker ps -q --filter label=service=kw-app-staging --filter label=role=web --filter status=running | head -n1); docker exec $C <command>'
```

Shorthand used below: `C` = that discovered container, and each recipe is the part after `docker exec $C`.

Prerequisite: `ssh -o BatchMode=yes pi5main.local true` succeeds. Plain `ssh` + `docker` is the supported path; local `bundle exec kamal ...` needs the host gems for Kamal 2.10.1 and was broken when this skill was written.

## Rails log recipes

Rails lines look like `I, [time #pid]  INFO -- : [<request-id>] message`. Every line of a request carries its `request-id`, and the same id appears in the kamal-proxy log.

```bash
# Last 50 non-SQL lines
tail -n 400 log/staging.log | grep -v ' DEBUG -- ' | tail -n 50

# All 5xx responses (request id, status, time)
grep -E 'Completed 5[0-9]{2}' log/staging.log | tail -n 20

# Exception headlines (class + message), then app frames follow on the next lines
grep -nE '^\[[0-9a-f-]{36}\] [A-Z][A-Za-z:]+ \(' log/staging.log | tail -n 20

# Full story of one request (params, SQL, exception, frames)
grep -F '[<request-id>]' log/staging.log

# Same, but with the controller line and only the app backtrace
grep -F '[<request-id>]' log/staging.log | grep -E 'Started|Processing|Parameters|Completed|app/'

# One controller/action
grep -E 'Processing by Settlement::Admin::ContractsController#(update|create)' log/staging.log | tail -n 10

# Slow requests (>= 1000 ms)
grep -E 'Completed [0-9]+ .* in [0-9]{4,}ms' log/staging.log | tail -n 20

# SQL errors / deadlocks / timeouts
grep -nE 'PG::|ActiveRecord::(StatementInvalid|Deadlocked|LockWaitTimeout)' log/staging.log | tail -n 20

# Deprecation warnings (check after gem upgrades)
grep -c 'DEPRECATION WARNING' log/staging.log

# Size / line count
wc -lc log/staging.log
```

### Reading an exception block

```
I, [..] INFO -- : [842fa299-...] Completed 500 Internal Server Error in 3ms
[842fa299-...] NoMethodError (undefined method `with' for Settlement::ContractForm:Class):
[842fa299-...]
[842fa299-...] app/components/settlement/update_contract.rb:13:in `call'
```
The first `app/` frame is usually the line to open. Gem frames are filtered out of the log.

### Test traffic in the log

Requests from the `staging-controller-testing` harness are written to the same file. They are identifiable by source IP `127.0.0.1` and a runner pid that differs from Puma's (the long-lived server pid is the one in `ps`, typically `31`). Do not mistake them for real user errors. Real user traffic arrives via kamal-proxy with the client's public IP.

## kamal-proxy access log

JSON, one line per request, includes `request_id`, `status`, `path`, `method`, `duration` (nanoseconds), `host`, `service` and `target`:

```bash
ssh pi5main.local 'docker logs --since 1h kamal-proxy 2>&1 | grep "kw-app-staging" | grep -E "\"status\":5"' | cut -c1-400
ssh pi5main.local 'docker logs --since 1h kamal-proxy 2>&1 | grep "<request-id>"' | cut -c1-600
```

Use it when the Rails log shows nothing: a 502/503/504 from the proxy with no matching Rails request means the app was down, restarting or timed out. Deploys restart the container, so check `docker ps -a --filter label=service=kw-app-staging` for `Exited` containers and `docker logs <old-container>` for the crash reason.

Note: the staging proxy host is `panel.taterniczek.pl`.

## Boot, Puma and agent output

```bash
ssh pi5main.local 'C=$(docker ps -q --filter label=service=kw-app-staging --filter label=role=web --filter status=running | head -n1); docker logs --tail 60 $C 2>&1 | cut -c1-220'
ssh pi5main.local 'C=$(docker ps -q --filter label=service=kw-app-staging --filter label=role=web --filter status=running | head -n1); docker exec $C tail -n 40 log/appsignal.log | cut -c1-220'
```

`appsignal.log` lines: `Starting AppSignal ...` (agent started in a process), `Not starting, not active for staging` (disabled via `APPSIGNAL_ACTIVE=false`), and probe errors.

## AppSignal

### Facts

- App name `KwApp`; `config/appsignal.yml` sets `active: true` for `production` and `staging`, `false` for `development`.
- Gem `appsignal` 4.3.1. `Appsignal.set_error` is also called in `ApplicationController` for `RecordNotFound`, so those appear as incidents.
- **The agent also starts inside `rails runner`/console processes.** Any one-off command on staging that makes errors would create real incidents. Always add `-e APPSIGNAL_ACTIVE=false` to `docker exec` for test or diagnostic runners (the `staging-controller-testing` harness enforces it).

### Give the agent read access (one-time, by the user)

OAuth sign-in needs a human in a browser, so ask the user to do one of these; do not try to log in yourself, and never ask for or paste tokens into chat, commits or this skill.

**Option A: AppSignal CLI** (best for terminal use, supports JSON output)

```bash
brew install appsignal/appsignal-cli/appsignal-cli
appsignal-cli auth login          # opens a browser; tokens are stored locally
appsignal-cli apps list           # confirm "KwApp" is visible (also sets default org)
```

**Option B: AppSignal MCP in Zed** (tools appear in the agent panel)

Add to Zed `settings.json` (OAuth; Zed signs in on first use and caches in the keychain):

```json
"context_servers": {
  "appsignal": { "url": "https://appsignal.com/api/mcp" }
}
```

A scoped, read-only MCP token (AppSignal → Account Settings → MCP Tokens, limited to KwApp and read tools) is the safer choice if the agent should not be able to close incidents or edit triggers. Put it in an `Authorization: Bearer ...` header in the user's own settings, never in the repo.

Without either, fall back to the container logs above and the AppSignal web UI (`https://appsignal.com`, app KwApp).

### CLI recipes (`--app KwApp --environment staging`)

Check what is exposed first: `appsignal-cli about`, `appsignal-cli auth status`.

```bash
A='--app KwApp --environment staging'

# Open exception incidents, newest activity first
appsignal-cli incidents list-exceptions $A --state OPEN --limit 10

# Find an exception by class or message
appsignal-cli incidents list-exceptions $A --query "NoTransitionAllowed"

# One incident with exception, causes and first app frame
appsignal-cli incidents show --number 42 $A

# Slow actions
appsignal-cli incidents list-performance $A --query "ContractsController" --limit 10

# Error traces for an exception: digest comes from the incident JSON (`digests` field)
appsignal-cli --output json incidents show --number 42 $A
appsignal-cli traces errors $A --digest <digest>
appsignal-cli traces show-incident $A --number 42 --trace-id <trace-id>   # span tree, SQL, `!!` marks the failing span

# Performance incident: list its traces, then open one
appsignal-cli traces incident $A --number 17
appsignal-cli traces show-incident $A --number 17 --trace-id <trace-id>

# Traces default to the last 24 h; widen with --start 2026-11-01T00:00:00Z
# Request params/headers are hidden unless --include-sensitive (avoid; it prints personal data)

# Machine-readable
appsignal-cli --output json incidents list-exceptions $A --state OPEN
```

Same commands for production with `--environment production` (read-only use only).

Changing state (`incidents update --state CLOSED`, `--assign-me`, notes) writes to AppSignal. Do it only when the user asks.

### MCP workflows

With the MCP server connected, ask for the same things in plain language, e.g. "list open exception incidents for KwApp staging", "show the newest trace for incident N", "which actions got slower since the last deploy". Prefer read-only tools.

## Triage runbook: "a request failed on staging"

1. **Reproduce / identify**: get the path, time and user, or run the `staging-controller-testing` scenario.
2. **Rails log**: find the 5xx or exception headline, copy its `request-id`, pull the whole request (`grep -F '[<id>]'`). Read the first `app/` frame, params, and the last SQL.
3. **Proxy log**: if no Rails request exists, search kamal-proxy by `request_id` or time. 502/503/504 means the app was unavailable (deploy, crash, OOM on the Pi).
4. **AppSignal**: look for the incident (`incidents list-exceptions --query <ExceptionClass>`), check occurrence count, first seen vs last deploy, and the trace for SQL/N+1 or slow events.
5. **Decide**: bug, data problem, or infrastructure. Check `docs/KNOWN_ISSUES.md` first.
6. **Fix through the normal workflow** (tests in Docker, then deploy via `kamal-deployment`), and re-run the scenario to confirm. Close the AppSignal incident only if asked.

## Known observations (re-check, may be stale)

- Staging logs requests to a file instead of stdout, unlike production. Setting `RAILS_LOG_TO_STDOUT` in `config/deploy.staging.yml` would make `kamal app logs -d staging` useful, but that is a deploy-config change: ask first.
- `appsignal.log` on staging repeats `Error in minutely probe 'sidekiq': Connection refused ... 127.0.0.1:6379` every minute: the Sidekiq probe/client uses no `REDIS_URL` while Redis runs in `kw-app-staging-redis` with a password. Only one process (`puma`) runs in the web container, so no Sidekiq worker handles jobs there.
- `config/appsignal.yml` contains the Push API key in plain text and is committed. Prefer `<%= ENV['APPSIGNAL_PUSH_API_KEY'] %>` and rotate the key.

## Safety & privacy

- Read-only. Do not `truncate`/`rm` logs, restart containers, or run `docker system prune`.
- Logs contain request parameters, emails and names. `filter_parameters` only masks `passw`, `secret`, `token`, `_key`, `crypt`, `salt`, `certificate`, `otp`, `ssn`. Quote the minimum lines needed, and do not paste real user data into issues or commits.
- Cap output (`tail -n`, `head -n`, `cut -c1-220`); the log is ~800 KB after a few hours of debug logging.
- Production: reading is fine; any command that writes (incident updates, deploys, consoles) needs explicit approval.

## Related

- `staging-controller-testing`: generates reproducible requests and 5xx's to look up here
- `kamal-deployment`: deploy, rollback, console
- `performance-optimization`: what to do once traces show N+1 or slow queries
