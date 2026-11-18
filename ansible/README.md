# ansible/ - the host layer

One source of truth for how kw-app is deployed, in two layers:

| Layer | Tool | Where |
|---|---|---|
| The host (patching, SSH, firewall, fail2ban, kernel hardening, auditd, Docker, timers, later monitoring) | Ansible | this directory |
| The app on the host (containers, proxy, TLS, env, accessories) | Kamal + GitHub Actions | `config/deploy*.yml`, `.github/workflows/` |

Secrets never live here. Ansible logs in as `ubuntu` (key only, passwordless sudo). Only the `backup` role needs secret values: it reads them
from Bitwarden Secrets Manager on the machine running Ansible (`bws` + `jq` installed, `BWS_ACCESS_TOKEN` in the environment) and writes them to a root-only file on the host.
Kamal and CI use the separate `deploy` user and never run Ansible.

## New production (`51.255.38.227`, not live until the cutover)

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/production.yml --syntax-check
ansible-playbook playbooks/production.yml --check --diff   # dry run: must end with changed=0
ansible-playbook playbooks/production.yml                  # apply
```

Fresh host only: add `-e base_full_upgrade=true` for one full `apt dist-upgrade` (normal patching is `unattended-upgrades`).
Keep the number of SSH sessions low (the host runs fail2ban); `ansible.cfg` reuses one connection.

Roles (each mirrors a verified step in `docs/NEW_PRODUCTION_PLAN.md`, P1/P2):
`base` (swap, unattended-upgrades, quiet upgrade window, reboot-if-needed timer), `ssh`, `firewall`, `fail2ban`,
`docker` (official repo with the checked-in key, major version pinned, capped logs + live-restore, DOCKER-USER firewall so only 80/443 reach containers, the `kw-app-network` network),
`kernel` (sysctl, module blacklist, auditd rules and log caps, journald limits; runs after `docker`),
`deploy_user` (no sudo, locked password, `docker` group, exclusive authorized keys from `inventory/group_vars/production.yml`),
`backup` (nightly dump, restic copy to OVH Object Storage, weekly restore test and repository check, healthchecks.io pings; settings in `roles/backup/defaults/main.yml`,
run a job by hand with `sudo systemctl start kw-backup.service`, read it with `journalctl -u kw-backup`).
On a first `--check` of a fresh host a few tasks (restic download, timers) cannot see files that do not exist yet; the role tolerates that in check mode only.

Rule: a change on the host is made here first (or in the same change), then applied. A dry run that reports
changes means the host drifted from this repo.

## Staging (Raspberry Pi)

`staging/` and `inventory/staging.ini` are the old, unmaintained first-draft playbook (prompts for passwords).
They will be rewritten as roles of the same layout; until then staging is deployed by Kamal only.
