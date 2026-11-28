---
name: ssh-access
description: How to reach the kw-app hosts over SSH from this laptop - live production (deploy@51.255.38.227) and staging (rege@pi5main.local). Use before ANY ssh/scp/rsync/docker-exec to prod or staging, and whenever you see "Too many authentication failures" or "Permission denied (publickey)". Includes a tested wrapper script (scripts/kw-ssh.sh) that pins the right key, container-name tricks, read-only defaults and troubleshooting.
---

# SSH access to prod and staging (kw-app)

Tested 2026-11-25 on the owner's Mac. Other skills (`console`, `scp`, `scp-transfer`, `kamal-deployment`, `release-pr`, `staging-logs-appsignal`, `staging-controller-testing`) describe *what* to run on the hosts; this one is *how to get in*.

## Hosts

| Name | Target | Notes |
|------|--------|-------|
| **prod** (LIVE) | `deploy@51.255.38.227` | Ubuntu 26.04, Docker + Kamal. `deploy` is in the `docker` group, **no sudo**. Containers `kw-app-web-production-<sha>`, `-job-`, `-cron-`, `kamal-proxy`, accessories `kw-app-postgres` (PG 16, DB `kw_app_production`, user `production_user`), `kw-app-redis`. **Read-only unless the user explicitly approves a write** (`.rules` section 14) |
| **staging** | `rege@pi5main.local` | Raspberry Pi 5, Kamal + Docker. Containers `kw-app-staging-web-staging-<sha>`, `-job-`, `kw-app-staging-postgres` (PG 16, DB `kw_app_staging`, user `staging_user`), `kw-app-staging-redis`. Safe place for tests; still ask before destructive actions or restores (see `prod-db-restore`) |
| old prod `51.68.141.247` | do not use | Panel removed 2026-11-25. Only the WordPress edit flow of `szkolaalpinizmu-edit` may touch it |

## Use the wrapper (do this first)

`scripts/kw-ssh.sh` (path from the repo root: `.agents/skills/ssh-access/scripts/kw-ssh.sh`):

```
S=.agents/skills/ssh-access/scripts/kw-ssh.sh
$S prod    "hostname; docker ps --format '{{.Names}}\t{{.Status}}'"     # connection check, once per session
$S staging "hostname; docker ps --format '{{.Names}}'"
```

- Remote command goes in one quoted argument. **stdin is passed through**, so scripts and snippets can be piped in:
  `echo 'puts Library::ItemRecord.count' | $S prod 'docker exec -i $(docker ps -q -f name=kw-app-web-production) bin/rails runner -e production -'`
  (the `$(...)` inside single quotes runs on the remote host and picks the current web container; during a deploy two may exist, wait for it to finish).
- Longer script: write it to `tmp/<name>.rb`, run `... runner -e production - < tmp/<name>.rb`, delete the file afterwards (see the `console` skill).
- Read-only database check without Rails (fast, no app boot):
  `$S prod "docker exec kw-app-postgres psql -U production_user -d kw_app_production -At -c 'select count(*) from library_items'"`
  `$S staging "docker exec kw-app-staging-postgres psql -U staging_user -d kw_app_staging -At -c 'select count(*) from library_items'"`
- For `scp` / `rsync` / your own ssh loops, print the pinned options once and reuse them:
  `OPTS="$($S prod-opts)"` then `ssh $OPTS deploy@51.255.38.227 '...'` and `scp $OPTS deploy@51.255.38.227:/remote/file ./local`
  (prod-opts leaves a public-key file in `$TMPDIR`; it contains only the public key, delete it when done).
- Set `timeout_ms` on the terminal tool (e.g. 120000 for `rails runner`, the boot takes a while).

## Why plain `ssh deploy@51.255.38.227` fails here

`~/.ssh/config` has `Host *` -> `IdentityAgent` = the **1Password agent**. It offers every key it holds, in order, and the production server drops the connection after a few rejected keys: `Too many authentication failures`. The fix is to offer exactly one key with `IdentitiesOnly yes`. The authorized key is the owner's main key (`SHA256:cVosxEGq1KeMtKf7ZFjdClkq0UNUf1SAooo1NJTX8WA`); its **private half stays in 1Password**, ssh only needs the public half to select it from the agent. The wrapper writes that public key (public, safe to keep in the repo) to a temp file and cleans up.

Do **not** use `~/.ssh/kamal_production_ed25519` for `deploy@51.255.38.227`: it exists but is not authorized (`Permission denied (publickey)`). Kamal itself works through the agent via net-ssh.

Staging needs no pinning (`Host pi5main.local` in the config works as is).

## Rules

1. **Two attempts maximum** per problem, then stop and report. Failed logins can trigger fail2ban on prod. Never loop or retry blindly.
2. **Prod is read-only** by default: `docker ps`, `docker logs`, `select`, `.count`, `ls`, `cat`. Writes (`update`, `destroy`, `migrate`, `docker restart`, file changes) need the user's explicit approval in this conversation, with the exact command shown first. Details: `console` skill.
3. Prod is live: no mail or notification sending, no Dotpay/Strava calls, no printing of secrets or tokens (`encrypted_password`, `access_token`, `.env`, `docker inspect` env dumps).
4. Do not add prod keys to the Pi, do not change `~/.ssh/config`, do not install or change anything on the hosts without being asked.
5. Needs 1Password unlocked on the Mac (the agent). If ssh says `Permission denied` for the right key, ask the user to unlock 1Password and approve the SSH prompt, then retry once.

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `Too many authentication failures` | You used plain ssh. Use `kw-ssh.sh prod` |
| `Permission denied (publickey)` with the wrapper | 1Password locked or SSH agent integration off, or the key was removed from `authorized_keys`. Ask the user to unlock 1Password, retry once, then check `ssh-keygen -lf` of the key against the fingerprint above |
| `Permission denied (publickey)` after you passed `-i ~/.ssh/kamal_production_ed25519` | That key is not authorized for `deploy` |
| `Connection timed out` / `refused` | Network/VPN or server down. Check `https://panel.kw.krakow.pl/up`, then tell the user |
| `ssh: Could not resolve hostname pi5main.local` | Not on the home network. Staging is only reachable locally |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Stop. Do not edit `known_hosts` on your own; tell the user (could be a rebuilt server or a real problem) |
| `bash: docker: command not found` / permission denied on docker | Wrong host or user. `deploy` and `rege` are both in the `docker` group |
| Two web containers listed | A deploy is in progress. Wait and retry |

## Optional one-time setup for the user (not done by the agent)

Adding this to `~/.ssh/config` makes plain `ssh kw-prod` work everywhere (including scp and ad-hoc terminals). Save the public key line from `scripts/kw-ssh.sh` as `~/.ssh/kw_prod_deploy.pub` first:

```
Host kw-prod
    HostName 51.255.38.227
    User deploy
    IdentityFile ~/.ssh/kw_prod_deploy.pub
    IdentitiesOnly yes
```
