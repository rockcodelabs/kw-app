# ansible/ - the host layer

One source of truth for how kw-app is deployed, in two layers:

| Layer | Tool | Where |
|---|---|---|
| The host (patching, SSH, firewall, fail2ban, kernel hardening, auditd, Docker, timers, later monitoring) | Ansible | this directory |
| The app on the host (containers, proxy, TLS, env, accessories) | Kamal + GitHub Actions | `config/deploy*.yml`, `.github/workflows/` |

Secrets never live here. Ansible logs in as `ubuntu` (key only, passwordless sudo) and needs no secret.
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
`deploy_user` (no sudo, locked password, `docker` group, exclusive authorized keys from `inventory/group_vars/production.yml`).

Rule: a change on the host is made here first (or in the same change), then applied. A dry run that reports
changes means the host drifted from this repo.

## Staging (Raspberry Pi)

`staging/` and `inventory/staging.ini` are the old, unmaintained first-draft playbook (prompts for passwords).
They will be rewritten as roles of the same layout; until then staging is deployed by Kamal only.
