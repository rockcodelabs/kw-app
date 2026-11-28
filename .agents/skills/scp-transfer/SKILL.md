---
name: scp-transfer
description: Safely copy files between kw-app hosts with scp/ssh - move files from production (new prod 51.255.38.227, live since 2026-11-20) or from the frozen old prod (51.68.141.247, stale DB dumps up to 2026-11-20) to this machine, verify DB dumps, and push files to the staging Pi (pi5main.local). Use whenever a task needs a file moved from prod, to staging, or between them (DB dumps, logs, exports). Includes a tested fetch-and-verify script for the old-prod dumps.
allowed-tools: Read, Bash
---

# scp Transfers (kw-app)

How to move files between **production**, **this machine (the hub)** and **staging (Pi)** without leaking data or touching production state. Old-prod parts were tested on 2026-11-17, new-prod parts on 2026-11-25.

> Current state (2026-11-25): **production is `51.255.38.227`** (cutover 2026-11-20, `panel.kw.krakow.pl`). On the old server `51.68.141.247` the panel, its DBs and **all dumps were deleted on 2026-11-25** (no archive kept), so the old-prod sections and the `fetch-latest-prod-dump.sh` script below are **obsolete and will fail**; use new prod only. `146.59.44.70` no longer exists. See `.rules` section 14.

## Hosts

| Name | Login | OS / SSH | Notes |
|------|-------|----------|-------|
| **Production (LIVE)** | `deploy@51.255.38.227` | Ubuntu 26.04, Docker + Kamal | **Source only.** `deploy` is in the `docker` group, has **no sudo**. Postgres is the container `kw-app-postgres` (PG 16, user `production_user`, DB `kw_app_production`). Nightly backups are in `/var/backups/kw-app` (root-only, not readable by `deploy`) and in restic on OVH Object Storage |
| Old prod (panel removed 2026-11-25) | `deploy@51.68.141.247` | Ubuntu 20.04, OpenSSH 8.2, native (no Docker) | No kw-app data left (dumps in `/var/lib/kw-db-backup` deleted). Only other developers' sites run there; do not use it as a source |
| **Staging Pi** | `rege@pi5main.local` | Debian 13 aarch64, OpenSSH 10.0 | Docker; `/tmp` is **tmpfs** (8 GB, RAM-backed, wiped on reboot); 100+ GB free on `/` |
| **This machine (hub)** | local user | macOS, OpenSSH 9.9 | Has `jq`, `shasum`, `gzip`, `python3`, `rsync` |


## Topology: everything goes through this machine

```
prod (deploy@...) ──scp──►  laptop /tmp/kw-prod-dump.XXXX (0700)  ──scp / ssh stream──►  Pi (rege@pi5main.local)
        ▲ read-only                  verify here                         ▲ staging only
```

The Pi **cannot** reach (old) prod: `ssh deploy@51.68.141.247` from the Pi fails with `Permission denied (publickey)`. Do not add a prod key to the Pi (security change, ask first). Hop through the laptop instead.

## Rules (MUST)

1. **Production is read-only.** Use prod only as a **source**: `scp prod:file local`, `ssh prod 'ls|cat|grep'`. Never `scp x prod:`, `rm`, `mv`, `chmod`, `sudo`, or `rsync --delete` on prod without explicit user approval.
2. **Always non-interactive:** `-o BatchMode=yes -o ConnectTimeout=10`. If it asks for a password, stop and report; do not work around it.
3. **Private by default:** `umask 077`, destination dir `mktemp -d` + `chmod 700`. Dumps contain member PII (emails, phones, PESEL, password hashes, Strava/OAuth tokens).
4. **Never put dumps in the repo** or in a world-readable location. Keep them out of git, chat output and issues. Do not `cat`, `zcat | head`, or print rows; print only counts/hashes.
5. **Clean up** the local dir and any file on the Pi when finished (`rm -rf`), also after a failure.
6. **Verify before use**: compare size, sha256, gzip CRC and raw sha256 with the manifest. A mismatch means do not restore.
7. **Strict file names.** Match the dump name against `^kw_app_production-[0-9]{8}T[0-9]{12}Z\.sql\.gz$` before building any path. Do not interpolate user input into remote commands, and do not use remote globs.
8. **No new files on prod**, and do not leave dumps on prod outside `/var/lib/kw-db-backup/dumps/`. (Prod has only ~3 GB free disk: `/dev/sda1` 20 GB, 84% used.)

## Current data from new prod (read-only, tested 2026-11-25)

`deploy` cannot read `/var/backups/kw-app`, so for fresh data stream a plain SQL dump out of the Postgres container (a read-only `pg_dump`; it takes a short consistent snapshot and adds some load, so avoid it during peak hours and ask the user first for a full-DB dump):

```bash
umask 077; D=$(mktemp -d /tmp/kw-prod-dump.XXXXXX); chmod 700 "$D"
ssh -o BatchMode=yes -o ConnectTimeout=10 deploy@51.255.38.227 'docker exec kw-app-postgres pg_dump -U production_user --no-owner --no-privileges kw_app_production | gzip' > "$D/kw_app_production-newprod.sql.gz"
gzip -t "$D/kw_app_production-newprod.sql.gz"   # ~16 MB; a dump with PII, same handling rules as above
```

This was measured (about 16 MB gzipped) but the output is **not** wired into `fetch-latest-prod-dump.sh` or `prod-db-restore/restore.sh` (they expect the old-prod name pattern, manifest and `OWNER TO deploy`); adapt and test them before relying on it. For a single table or a count, prefer a read-only query with the `console` skill or `docker exec kw-app-postgres psql -U production_user -d kw_app_production -Atc '...'`.

## Where the OLD-prod dumps were (OBSOLETE: deleted 2026-11-25)

| Item | Value |
|------|-------|
| Directory | `/var/lib/kw-db-backup/dumps/` (mode 0700, owner `deploy`) |
| Producer | `deploy` crontab: `15 3 * * *` runs `/usr/local/lib/kw-db-backup/runner.py run` (Poland 03:15, file stamps are UTC) |
| File | `kw_app_production-<YYYYMMDD>T<HHMMSSffffff>Z.sql.gz`: plain SQL (`pg_dump` 10.23), gzip, ~20 MB (86 MB raw), 101 tables, all objects `OWNER TO deploy`, no `GRANT`s, no `CREATE DATABASE` |
| Manifest | `<file>.manifest.json`: `sha256` (compressed), `raw_sha256`, `md5`, `compressed_bytes`, `raw_bytes`, `started_utc`, `verification` |
| Retention | 7 daily dumps, oldest auto-deleted. Do not rely on older ones |
| Health | `/var/lib/kw-db-backup/status.json`: `local_status` must be `VERIFIED`. `offhost_status` has been `ERROR` (`native_deadline`), so the **local copy is the only copy**: do not delete or modify anything there |
| Legacy | `/home/deploy/baza_dump/sql/` has only a stale October dump from the old weekly job. Ignore it |

## Quick path: fetch and verify (script, old prod only)

**Obsolete:** the script reads old prod, whose dumps were deleted on 2026-11-25; it now fails. Kept only as a pattern for a future dump fetch (adapt it to new prod first).

```bash
DUMP=$(.agents/skills/scp-transfer/scripts/fetch-latest-prod-dump.sh | tail -n1)
echo "$DUMP"        # /tmp/.../kw-prod-dump.XXXXXX/kw_app_production-....sql.gz (dir is 0700)
```

What it does: finds the newest dump by strict name, requires `status.json` `local_status == VERIFIED`, `scp`s dump + manifest to a private temp dir, checks size/sha256/gzip CRC/raw sha256 against the manifest, warns when older than 36 h, prints the dump path on the last line (progress goes to stderr). On a mismatch it deletes the download and exits 1.

Options: `--name <file>` for a specific dump, `--max-age-hours N`. Takes ~5 s for 20 MB on a normal link, plus ~10 s of hashing.

Cleanup when finished: `rm -rf "$(dirname "$DUMP")"`.

## Manual commands (tested)

Variables (old prod, for the dump examples): `PROD=deploy@51.68.141.247` (use `deploy@51.255.38.227` for new prod), `PI=rege@pi5main.local`, `SRC=/var/lib/kw-db-backup/dumps`, `OPTS="-o BatchMode=yes -o ConnectTimeout=10"`.

> **New prod (`51.255.38.227`) from this Mac:** plain options fail with `Too many authentication failures` (1Password agent offers too many keys). Set `OPTS="$(.agents/skills/ssh-access/scripts/kw-ssh.sh prod-opts)"` instead (pins the one authorized key, see the `ssh-access` skill) and use it for every `ssh`/`scp` to prod. Staging (`PI`) needs no pinning.

```bash
# List / find newest (strict match, not a remote glob)
ssh $OPTS $PROD "ls -1 $SRC" | grep -E '^kw_app_production-[0-9]{8}T[0-9]{12}Z\.sql\.gz$' | sort | tail -n1

# Backup health (no jq on prod, parse locally)
ssh $OPTS $PROD "cat /var/lib/kw-db-backup/status.json" | jq '{local_status, offhost_status, finished_utc}'

# prod -> laptop (several files in one connection)
umask 077; D=$(mktemp -d /tmp/kw-prod-dump.XXXXXX)
scp -q $OPTS "$PROD:$SRC/$NAME" "$PROD:$SRC/$NAME.manifest.json" "$D/"

# laptop -> Pi (make a private dir first; Pi /tmp is tmpfs)
ssh $OPTS $PI 'umask 077; mkdir -p /tmp/kw-restore'
scp -q $OPTS "$D/$NAME" "$PI:/tmp/kw-restore/"

# prod -> Pi directly, relayed THROUGH this machine (no local file, nothing to clean locally)
scp -3 -q $OPTS "$PROD:$SRC/$NAME" "$PI:/tmp/kw-restore/$NAME"

# Preferred for restores: stream, no file on the Pi at all
gzip -dc "$D/$NAME" | ssh $OPTS $PI 'docker exec -i kw-app-staging-postgres psql -U staging_user -d <db> -v ON_ERROR_STOP=1'

# Verify on the Pi after a file copy
ssh $OPTS $PI "sha256sum /tmp/kw-restore/$NAME"   # compare with manifest .sha256

# Cleanup
rm -rf "$D"; ssh $OPTS $PI 'rm -rf /tmp/kw-restore'
```

Use `scp -3` only when you do not need to verify locally first. For restores prefer: fetch + verify locally (script) then stream into `psql`.

## Verify by hand

```bash
M="$D/$NAME.manifest.json"
jq -r '.sha256, .raw_sha256, .compressed_bytes' "$M"
shasum -a 256 "$D/$NAME" | cut -d' ' -f1          # must equal .sha256
gzip -t "$D/$NAME" && gzip -dc "$D/$NAME" | shasum -a 256 | cut -d' ' -f1   # must equal .raw_sha256
stat -f %z "$D/$NAME"                              # macOS; Linux: stat -c %s. Must equal .compressed_bytes
```

## Gotchas

- **macOS vs Linux:** `stat -f %z` (macOS) vs `stat -c %s` (Linux); `shasum -a 256` vs `sha256sum`. The Pi and prod have `sha256sum`, macOS has both.
- **`scp` uses SFTP since OpenSSH 9.0.** Prod's sshd has `Subsystem sftp` enabled, so it works. If a transfer ever fails with `subsystem request failed`, retry with `-O` (legacy protocol); do not change prod config.
- **`scp -3`** needs both remote logins to work non-interactively from this machine, and all data flows through it (bandwidth = this machine's link). It does not resume.
- **Large or flaky link:** `rsync -P --partial -e 'ssh -o BatchMode=yes' "$PROD:$SRC/$NAME" "$D/"` resumes (macOS ships an old rsync, which is fine for this). Never add `--delete` and never use `prod` as a destination.
- **`ls -1 $SRC` ordering** is by name, and names embed the UTC timestamp, so `sort | tail -n1` is the newest.
- **A dump taken at 03:15 does not contain later changes.** The data is up to ~24 h old by design. For fresher data a human must run a new dump on prod (a write to prod and extra load on a 2 GB host: ask first).
- **Pi `/tmp` is tmpfs:** a file there lives in RAM and disappears on reboot. Fine for 20 MB; for anything big, use a path on `/`.
- **`rc=$?` after a pipe** reports the last command (`tail`/`cut`), not `ssh`. Use `set -o pipefail` (the script does) or test the `ssh` alone when checking connectivity.
- **Host key prompts** are disabled by `BatchMode=yes`; an unknown host fails instead of prompting. Fix by connecting once by hand, not by `StrictHostKeyChecking=no`.

## Troubleshooting

| Symptom | Cause / action |
|---------|----------------|
| `Permission denied (publickey)` from the Pi to prod | Expected: the Pi has no prod key. Route via the laptop |
| `Connection refused` on `146.59.44.70` | That VPS was deleted. Production is `51.255.38.227` |
| `Permission denied` reading `/var/backups/kw-app` on new prod | Expected: root-only and `deploy` has no sudo. Use the `pg_dump` stream above, or the restic copy (needs bws + the restic password) |
| `local_status` is not `VERIFIED` | Last nightly backup failed local verification. Do not use the dump; read `/var/lib/kw-db-backup/last-cron.log` (read-only) and tell the user |
| `offhost_status: ERROR` | Known (`native_deadline`), informational. Mention it, do not fix it from here |
| Hash mismatch | Truncated/corrupted transfer. Re-fetch once; if it repeats, stop and report |
| `scp: ... Permission denied` on a dump | Files are `0600` owned by `deploy`; log in as `deploy`, not another user |
| Script says dump older than 36 h | Nightly job missed a run. Check `status.json` `finished_utc` and tell the user |

## Related

- `kamal-deployment`: deploy / console / logs for staging
- `staging-logs-appsignal`: read-only diagnostics on the Pi and prod
- `.rules` section 14: which host is live production
- `console` / `scp` skills: running Ruby on the new prod web container
- `config/deploy.staging.yml`: staging Postgres container (`kw-app-staging-postgres`, PG 16, user `staging_user`, db `kw_app_staging`)
