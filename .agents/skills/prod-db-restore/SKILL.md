---
name: prod-db-restore
description: Fetch the latest LIVE prod database dump (51.68.141.247), restore it 1:1 onto a target Postgres (staging Pi now, new prod later), verify row-by-row against the dump, rehearse migrations, swap it in with rollback. Use when asked to refresh staging with production data, "restore prod DB on staging", or to run/rehearse the old-prod -> new-prod DB migration. Includes tested scripts.
allowed-tools: Read, Bash
---

# Restore prod DB onto staging / new prod (1:1)

Builds on `scp-transfer` (fetch + verify the dump) and `bws-secrets`. Scripts live in `.agents/skills/prod-db-restore/scripts/`. Tested end to end on 2026-11-17 against a scratch DB on staging; the final swap was rehearsed on throwaway databases only.

> Production is `51.68.141.247` (live, read-only source). `51.255.38.227` (new OVH VPS) is the future prod and is NOT live; `146.59.44.70` is obsolete. See `.rules` section 14.

## What "1:1" means here

No scrubbing, no anonymising: users, e-mails, phones, PESEL, password hashes, OAuth tokens all come across. Treat the dump and the target as production-sensitive. Only the DB is restored. **Not covered:** uploaded files (OVH OpenStack container `kw-app-cloud-<Rails.env>`; `public/uploads` is only a CarrierWave cache) and Redis/Sidekiq state.

## Hard rules

1. Prod is read-only. This skill only reads from it (via `scp-transfer`).
2. The live target DB is never modified until `swap`, and `swap` / `rollback` / `drop` refuse to run without `--yes`. **Ask the user for explicit confirmation before passing `--yes`.** Say which DB will be renamed and that the app will be stopped.
3. **Mail risk:** staging runs real Mailgun credentials, and members' real addresses will be in the DB. `swap` on staging also requires `--ack-mail-risk`. Do not pass it until the user confirms mail is sandboxed (separate Mailgun sandbox domain / no real sending), or accepts the risk. See `bws-secrets` "Known gaps".
4. Never print rows. The scripts print names, counts and statuses only; keep it that way.
5. Always clean up the local dump (`rm -rf "$(dirname "$DUMP")"`) when finished, also on failure.
6. Non-interactive SSH only (`BatchMode`), no `StrictHostKeyChecking=no`.

## Quick path (staging)

```bash
S=.agents/skills/prod-db-restore/scripts/restore.sh

# 1. fetch + verify the newest nightly dump (prod -> laptop, checks manifest hashes)
DUMP=$(.agents/skills/scp-transfer/scripts/fetch-latest-prod-dump.sh | tail -n1)

# 2. check the target (changes nothing)
$S preflight "$DUMP"

# 3. load into a NEW scratch DB. Live DB untouched. ~10 s for 86 MB
DB=$($S restore "$DUMP" | tail -n1)            # e.g. kw_restore_20261117T...

# 4. prove it is identical to the dump (~1 min): rows + content digest per table, sequences, structure
$S verify "$DUMP" --db "$DB"                   # must end with PASS

# 5. rehearse migrations on the scratch DB with the real web image (live app unaffected)
$S migrate --db "$DB"
$S verify "$DUMP" --db "$DB" --after-migrate   # must end with PASS

# 6. ASK THE USER, then swap. Stops web, renames live -> <live>_prev_<ts>, scratch -> live, starts web
PREV=$($S swap --db "$DB" --yes --ack-mail-risk | tail -n1)

# 7. rollback if something is wrong (renames back, keeps the bad DB as <live>_failed_<ts>)
$S rollback --prev "$PREV" --yes

# 8. later, when happy: drop the old copies, delete the dump
$S drop --db "$PREV" --yes
rm -rf "$(dirname "$DUMP")"
```

`-t new-prod` selects the other profile (placed before the command): `$S -t new-prod preflight "$DUMP"`. Profiles: `scripts/profiles/{staging,new-prod}.env`. **`new-prod.env` is UNTESTED** (SSH to the new VPS 51.255.38.227 was refused on 2026-11-17); confirm every value before first use.

## What each step does and why

| Step | Detail |
|------|--------|
| `restore` | `CREATE DATABASE` with the live DB's encoding/locale (prod: UTF8 `en_US.UTF-8`), then `gzip -dc | psql --single-transaction -v ON_ERROR_STOP=1`. Any error rolls everything back and drops the scratch DB. Creates a `NOLOGIN` role `deploy` if missing (every object in the dump is `OWNER TO deploy`), then `REASSIGN OWNED BY deploy TO <app user>` (ownership only; `--keep-owner` skips) |
| `verify` | Streams each table from the DB with `COPY ... TO STDOUT` and compares row count and an order-independent SHA-256 digest with the same computed from the dump. The 22 `double precision` columns are normalised (PG 10 and PG 16 print floats differently). Also compares all 98 sequences to the dump's `setval()` and counts tables / sequences / FKs / PK+unique / indexes. Compares against the **dump**, not live prod, which has moved on since 03:15 |
| `migrate` | Runs `db:migrate` in the running web container with `STAGING_DATABASE_NAME=<scratch>`, so only the scratch DB is touched. Prod's schema lacks migration `20241226180715`; that is the one it applies |
| `verify --after-migrate` | Same checks, but `schema_migrations` and structure counts may be larger, and `ar_internal_metadata` is only row-counted (Rails rewrites `environment` from `production` to `staging` on migrate) |
| `swap` | `docker stop <web>`, terminate sessions, `ALTER DATABASE live RENAME TO live_prev_<ts>`, `ALTER DATABASE scratch RENAME TO live`, `docker start <web>`, polls `/up`. If the second rename fails it renames the first back. The web container is always restarted on failure (shell trap) |
| `rollback` | Reverse of swap |
| `drop` | Only `kw_restore_*`, `*_prev_*`, `*_failed_*`. Refuses the live DB |

The web image entrypoint runs `db:prepare` on every boot, so any migrations still pending at swap time also run when the app starts. Rehearsing with `migrate` first just shows you the result beforehand.

## Tested results (2026-11-17, dump 20261117T021511Z)

- Restore into a scratch DB on staging PG 16.0: 10 s, 101 tables, 113 MB, no errors (dump is from PG 10.23).
- `verify`: 101/101 tables identical, 396,796 rows, 98/98 sequences, structure 101/101/11/100/165.
- Negative tests: a changed timestamp, a changed float, a deleted row and a shifted sequence were each reported as FAIL.
- `migrate`: applied exactly one pending migration, `verify --after-migrate` PASS.
- Gates: `swap` without `--yes` or `--ack-mail-risk`, and `drop` of the live DB or any other DB, are all refused.
- Swap and rollback: rehearsed on throwaway DBs with `--no-stop-app --live-db kw_swap_test_live`; live staging was not touched.

**Not tested:** `swap` with the web container stop/start and the `/up` wait (run it with the user watching); the `new-prod` profile.

## Verification order matters

Run strict `verify` **before** `migrate`; that is the pure 1:1 proof. After migrating the strict check must fail (new row in `schema_migrations`, changed `ar_internal_metadata`), so use `--after-migrate` there.

## Using this for the old-prod -> new-prod migration

1. Keep prod as the source; do not stop it. For a final cut-over a human must decide on a write freeze and a fresh dump (a new dump on prod is a write: ask first; the nightly 03:15 dump is up to ~24 h old).
2. `bin/migrate-database-to-new-prod` was a broken stub and is deleted; use this skill's scripts. `bin/verify-migration` (row counts on new prod, host from `NEW_PROD_SSH`, default `deploy@51.255.38.227`) can serve as an extra check.
3. Fill in and verify `profiles/new-prod.env` (container, user, DB, web filter) over a working SSH, run `preflight` then `restore` and `verify` into a scratch DB first, exactly as for staging.
4. New prod is PG 16 like staging; prod is PG 10.23. Plain-SQL dumps from 10 load fine into 16 (tested).
5. Also migrate uploaded files (OpenStack container) and decide what to do about Redis. The DB dump alone is not the whole app state.

## Troubleshooting

| Symptom | Cause / action |
|---------|----------------|
| `preflight`: `ssh ... failed` | Host unreachable or key missing. The Pi cannot reach prod, but this script only talks to the target |
| `restore` fails mid-load | Everything rolled back and the scratch DB was dropped. Read the psql error above; do not retry blindly |
| `verify` FAIL on one table | Re-run once. If it repeats, the load is wrong; drop the scratch DB, re-fetch the dump, restore again |
| `verify` fails only on float columns | Normalisation covers `double precision` and `real`; check for a new column type with a different text format |
| `migrate`: "expected exactly one running web container" | Staging web is down or two versions overlap during a deploy; wait and retry |
| `swap`: app not healthy in 180 s | `docker logs <web>`; `rollback --prev <PREV> --yes` |
| `drop` refuses | By design: only scratch, `_prev_` and `_failed_` DBs |
| macOS | Scripts run on the laptop (bash 3.2, BSD tools); do not use `grep \s`, use `[[:space:]]` |

## Related

- `scp-transfer`: fetch/verify the dump
- `bws-secrets`: secrets and the mail-risk follow-up
- `kamal-deployment`, `staging-logs-appsignal`: deploy and logs on staging
- `config/deploy.staging.yml`: staging Postgres accessory
