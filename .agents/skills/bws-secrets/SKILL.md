---
name: bws-secrets
description: Read, create, rotate and wire kw-app secrets in Bitwarden Secrets Manager (bws) without ever printing values - project ID, naming convention, safe list/check/create/edit commands, how Kamal and CI consume secrets (.kamal/bin/secret), the rotation runbook, and the read/write access test. Use for any task that adds, rotates or audits a secret, token or credential, or touches .kamal/secrets* or env.secret in config/deploy*.yml.
allowed-tools: Read, Bash
---

# Bitwarden Secrets Manager (bws) for kw-app

Single source of truth for deploy-time secrets. Read/write access verified on 2026-11-17.

## Hard rules

1. **Never print a secret value** - not in tool output, logs, commits or docs. Report names, UUIDs, lengths, or a hash prefix.
2. `bws secret create` and `bws secret edit` **echo the value** in their JSON. Always post-process (see below).
3. Never decrypt `config/credentials/*.yml.enc` in a snippet that can raise with the config in the message. Print key *names* only.
4. Do not commit, push or deploy without asking (`.rules` section 8). A push to `develop` redeploys staging; a push to `main` targets the NOT-live new prod.
5. Prod is read-only unless the user approves a write.

## Where things live

| Thing | Value |
|-------|-------|
| Project `panel` | `155e4846-7d36-468d-9891-b3da010aaf94` (shared with ~10 other apps: Immich, Nextcloud, Home Assistant, sklep-gor ...) |
| Auth | `BWS_ACCESS_TOKEN` env var (machine account). The CLI reads it automatically |
| Naming for new secrets | `kw-app-<env>-<NAME>`, or `kw-app-<NAME>` when shared by all envs |
| Legacy names (kept - CI and Kamal reference them by UUID) | `staging-master-key`, `staging-postgres-password`, `staging-redis-password`, `registry-username`, `registry-password` |

Only touch entries that start with `kw-app-`, plus the five legacy names above. The rest belong to other apps.

### kw-app entries (UUID -> env var Kamal injects)

| bws name | UUID | Env var | Used by |
|----------|------|---------|---------|
| `registry-username` | `6e77be63-a052-4594-9585-b3da01100ce9` | `KAMAL_REGISTRY_USERNAME` | both |
| `registry-password` | `6ff8b019-a3e4-4571-85fc-b3da01106838` | `KAMAL_REGISTRY_PASSWORD` | both |
| `staging-master-key` | `79cdec0b-a73e-4f31-aabe-b3da0110963a` | `RAILS_MASTER_KEY` | staging |
| `staging-postgres-password` | `5f418769-a3ee-46d3-87bf-b3da0110cd71` | `POSTGRES_PASSWORD` | staging |
| `staging-redis-password` | `b4b3b0ce-46fe-4068-a477-b3da0110f721` | `REDIS_PASSWORD` | staging |
| `kw-app-production-master-key` | `519419f3-6bb7-4ce6-8132-b3da0119bf76` | `RAILS_MASTER_KEY` | production |
| `kw-app-production-postgres-password` | `9c80203f-f8c2-4b5d-8d4b-b3da0119d394` | `POSTGRES_PASSWORD` | production |
| `kw-app-production-redis-password` | `8ca74ff6-e6bd-4884-b45b-b3da0119f2a7` | `REDIS_PASSWORD` | production |
| `kw-app-production-vps-sudo-password` | `45e88671-20f8-4c23-ae00-b3da011bafdc` | (ansible only) | - |
| `kw-app-appsignal-push-api-key` | `10b644fb-ce8b-4d58-b0ac-b5050105f27e` | `APPSIGNAL_PUSH_API_KEY` | both |
| `kw-app-strava-verify-token` | `e48a96fa-0e1a-42b9-9393-b505010605a2` | `STRAVA_VERIFY_TOKEN` | both |

Not in bws (still in `config/credentials/<env>.yml.enc`, read via `ENV.fetch(..) { credentials.dig(..) }`): Mailgun, OpenStack, Dotpay, Strava client, Google OAuth, `secret_key_base`. To move one: create the bws entry, add it to `.kamal/secrets-common` (or the destination file) **and** to `env.secret` in `config/deploy.yml` + `config/deploy.production.yml`, and add it to the "Get Secrets" step of both deploy workflows.

> Pitfall: an **empty** env var overrides the credentials fallback. Only inject env vars that have a non-empty bws value.

## How secrets reach the app

```
bws (UUID)  ->  .kamal/bin/secret NAME UUID  ->  .kamal/secrets-common / secrets.<dest>
                       ^                                   |
   exported env var wins (GitHub Actions)                  v
                                           config/deploy*.yml  env.secret  ->  container env
```

- `kamal ... -d staging|production` reads `.kamal/secrets-common`, then `.kamal/secrets.<dest>`. Plain `.kamal/secrets` is **not** read with `-d` (that file was removed).
- `.kamal/bin/secret` prints the exported env var if set, else fetches that single secret by UUID (needs `bws`, `jq`, `BWS_ACCESS_TOKEN`). It exits non-zero with a message on stderr when it cannot resolve a value.
- Fetch by UUID, not by name: renames don't break it, and the other apps' secrets are never pulled.
- `env.secret` in `config/deploy.production.yml` **replaces** the base list in `config/deploy.yml` (Kamal does not merge arrays). Add every new name to both.
- GitHub Actions: `.github/workflows/deploy-{staging,production}.yml`, step "Get Secrets from Bitwarden", fetches by UUID into `$GITHUB_ENV`. Staging uses GitHub secret `BW_ACCESS_TOKEN`, production `BW_ACCESS_TOKEN_PRODUCTION`. The `BW_SECRET_*` GitHub secrets hold UUIDs.
- Do **not** run `kamal secrets print` in an agent session (prints values).

## Safe commands

```bash
P=155e4846-7d36-468d-9891-b3da010aaf94

# List names + ids only
bws secret list $P -o json | jq -r '.[] | select(.key|startswith("kw-app")) | "\(.id)  \(.key)"'

# Check a value without showing it: length and short hash
bws secret get <uuid> | jq -j '.value' | wc -c
bws secret get <uuid> | jq -j '.value' | shasum -a 256 | cut -c1-8

# Create (value stays inside python, only id/key/length are printed)
python3 - <<'PY'
import secrets, subprocess, json
value = secrets.token_urlsafe(32)          # or the credential issued by the provider
r = subprocess.run(['bws','secret','create','kw-app-<name>',value,'155e4846-7d36-468d-9891-b3da010aaf94',
                    '--note','what it is, env var name'], capture_output=True, text=True)
if r.returncode: raise SystemExit(r.stderr.replace(value,'***'))
d = json.loads(r.stdout); print('created', d['id'], d['key'], 'len', len(d['value']))
PY

# Edit (rotate) - discard the echo. The UUID stays, so CI and Kamal keep working
bws secret edit <uuid> --value "<new>" >/dev/null
bws secret edit <uuid> --key kw-app-new-name >/dev/null   # rename only
```

A literal value on the command line is briefly visible in shell history and `ps`; use the python pattern for real secrets.

## Rotation runbook

1. Issue the new credential at the provider (Mailgun, OpenStack, Dotpay, Strava, Google, AppSignal, Redis ...).
2. `bws secret edit <uuid> --value ... >/dev/null`.
3. Redeploy the environment (push to `develop` for staging; production per its own process) so Kamal re-injects it. A value that lives in `credentials/<env>.yml.enc` instead must be re-encrypted with that environment's key in a throw-away shell (`bin/rails credentials:edit --environment <env>`).
4. Verify without printing: `docker exec <container> sh -c 'printf %s "$NAME" | wc -c'`, then a functional check.
5. Revoke the old credential at the provider.
6. Rotating `secret_key_base` logs every user out but does not break stored passwords (Devise `secret_key`/`pepper` are not set).
7. Rotating `RAILS_MASTER_KEY` means re-keying the matching `credentials/<env>.yml.enc` first, then updating bws, then deploying.

## Access test (what was run to prove read/write)

Re-run only to re-check the token's permissions, and clean up afterwards.

```bash
bws project list -o json | jq -r '.[] | "\(.id) \(.name)"'                       # read
bws secret create _bws_rw_test "x" $P >/dev/null                                 # create
ID=$(bws secret list $P -o json | jq -r '.[]|select(.key=="_bws_rw_test").id')
bws secret edit $ID --value "y" >/dev/null                                       # edit
bws secret delete $ID                                                            # delete
```

Result on 2026-11-17: read, create, edit, delete secrets and create/delete projects all worked. Per-project machine-account access can only be configured in the Bitwarden web UI.

## Rotation backlog (decided 2026-11-17: do AFTER the migration to new prod)

These were exposed in an agent session on 2026-11-17 (the decrypted `production.yml.enc` was echoed into tool output) and/or are readable by anyone via the public repo, because `config/master.key` was committed in 2019 and still exists on `main` and in git history. Treat all as compromised. Names only, no values.

| # | Credential | Where it lives now | Rotate at | Effect of rotating |
|---|------------|--------------------|-----------|--------------------|
| 1 | `secret_key_base` (prod) | `production.yml.enc` / env | generate new | all users logged out; passwords unaffected |
| 2 | Redis password (prod, and staging which shares it) | bws `kw-app-production-redis-password`, `staging-redis-password` | generate new, give each env its own | restart Redis + app together |
| 3 | Mailgun API key + SMTP login/password | `production.yml.enc` | Mailgun dashboard | mail stops until updated |
| 4 | OpenStack tenant/username/API key (uploads storage) | `production.yml.enc` | OVH manager | uploads fail until updated |
| 5 | Dotpay login/password | `production.yml.enc` | Dotpay panel | payments fail until updated |
| 6 | Strava client secret | `production.yml.enc` | Strava API settings | Strava sync fails until updated |
| 7 | Google OAuth client secret | `production.yml.enc` | Google Cloud console | Google login fails until updated |
| 8 | AppSignal push API key | bws `kw-app-appsignal-push-api-key` (old value was hardcoded in `config/appsignal.yml` in git history) | AppSignal app settings | metrics stop until updated |
| 9 | Strava webhook verify token | bws `kw-app-strava-verify-token` (already a fresh random value; old `strava_token` is in git history but only matters at subscription creation) | nothing to do unless re-subscribing | - |
| 10 | Production `RAILS_MASTER_KEY` | bws `kw-app-production-master-key` (identical to the leaked `config/master.key`) | `bin/rails credentials:edit --environment production` with a NEW key, re-encrypt, then update bws | do this last, together with item 1-7 re-encryption |
| 11 | Dev/test `secret_key_base`, Devise sample secret/pepper | were in git history | no action (dev/test only, Devise ones were commented out) | - |

Order when doing it: new credential at provider -> update the value (bws entry, or re-encrypt `production.yml.enc` for the ones that live there) -> deploy -> verify -> revoke old. Item 10 re-keys the whole file, so do items 3-7 inside that same edit. After the migration also remove `config/master.key` and `config/secrets.yml` history exposure from `main`.

Staging was also affected only through the shared Redis password and the stale local file below; its own master key and Postgres password differ from production's.

Local leftover (laptop only, git-ignored, not read by Kamal): `.kamal/secrets-staging` holds 22 old KEY=VALUE lines (RAILS_MASTER_KEY, POSTGRES_PASSWORD and KAMAL_REGISTRY_PASSWORD differ from bws, i.e. stale; OpenStack/Dotpay/Mailgun/etc. have no bws copy). Before deleting it, make sure each value that is still needed exists in bws or the staging credentials.

## Known gaps (as of 2026-11-17)

- The repo is public and `config/master.key` was committed in 2019. It is removed from `develop` but remains on `main` and in git history, where it decrypts the current `production.yml.enc` and older staging/dev/prod credential files. Treat every value in those files as exposed and rotate them. After the prod migration: remove `master.key` from `main` and re-key production credentials.
- `kw-app-production-redis-password` is **identical** to the staging Redis password. Rotate one of them.
- Everything lives in the shared `panel` project. Recommended: a dedicated `kw-app` project with read-only machine accounts per environment (web UI).
- Staging should get its own Mailgun sandbox domain and OpenStack container before it holds a 1:1 production restore, otherwise staging can email real members and touch real uploads.
