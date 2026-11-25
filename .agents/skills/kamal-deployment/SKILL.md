---
name: kamal-deployment
description: Zero-downtime deployment with Kamal for kw-app (staging on Raspberry Pi ARM64, production on VPS x86_64). Covers deployment workflows, console access, and troubleshooting.
allowed-tools: Read, Write, Edit, Bash
---

# Kamal Deployment (kw-app)

## Overview

kw-app uses Kamal for zero-downtime deployments to:
- **Staging**: Raspberry Pi 4 (ARM64, ~4GB RAM)
- **Production**: OVH VPS `51.255.38.227` (x86_64, Ubuntu 26.04, `https://panel.kw.krakow.pl`), live since 2026-11-20. Deploys come from CI (merge to `main` deploys automatically once the `test` job is green; the `production` Environment has no required reviewer since 2026-11-25, only the `main` branch restriction); a hand `kamal deploy -d production` is an emergency path. The old server `51.68.141.247` is frozen and does not run the panel any more

**Key Features:**
- Rolling restarts (zero downtime)
- Automated migrations before deploy
- Docker-based deployment
- SSH-based remote execution

## Prerequisites

**Local Machine Requirements:**
- Ruby 3.2.11 (via chruby) - **NOT Docker!**
- Kamal gem installed globally or in bundle
- SSH keys configured for deployment servers

## Architecture

### Deployment Flow

```
Local Machine (chruby 3.2.11)
    ↓
Run: kamal deploy -d staging/production
    ↓
1. Build Docker image (ARM64 or x86_64)
2. Push to registry
3. SSH to target server
4. Run migrations (if needed)
5. Pull new image
6. Rolling restart (zero downtime)
7. Health checks
```

### Why Native Ruby for Kamal?

- Kamal runs on **host machine**, not in Docker
- Needs native Ruby 3.2.11 (via chruby)
- Docker is used ONLY for the app container being deployed

## Configuration Files

```
config/
├── deploy.yml               # Base config (not used directly)
├── deploy.staging.yml       # Staging (Raspberry Pi)
└── deploy.production.yml    # Production (VPS)
```

### Key Settings

**Staging (deploy.staging.yml):**
- Server: Raspberry Pi 4
- Architecture: ARM64
- Memory: ~4GB (use batches for large operations)
- Branch: `develop`

**Production (deploy.production.yml):**
- Server: OVH VPS `51.255.38.227`, SSH user `deploy` (docker group, no sudo)
- Architecture: x86_64
- Branch: `main`

## Common Commands

### Deployment Commands

**All Kamal commands run with native Ruby (chruby):**

```bash
# Deploy to staging
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal deploy -d staging'

# Deploy to production
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal deploy -d production'

# Deploy specific branch
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal deploy -d staging --version=feature-branch'

# Check deployment status
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app details -d staging'

# View logs
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app logs -d staging'

# Rollback to previous version
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal rollback -d production'
```

### Console Access

**Staging Console:**
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging -i --reuse "bin/rails console"'
```

**Production Console:**
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d production -i --reuse "bin/rails console"'
```

**Non-interactive production runner (what agents use, tested 2026-11-25):**
```bash
echo 'puts Db::User.count' | ssh -o BatchMode=yes deploy@51.255.38.227 'docker exec -i $(docker ps -q -f name=kw-app-web-production) bin/rails runner -e production -'
```
See the `console` and `scp` skills for the full procedure and safety rules.

**Flag Meanings:**
- `-d staging/production` - Destination environment
- `-i` / `--interactive` - Keep terminal interactive (required for console)
- `--reuse` - Reuse existing SSH connection (no registry auth needed)

### One-off Commands

**Run rake task:**
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails db:migrate:status"'
```

**Run Rails runner:**
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails runner \"puts User.count\""'
```

## Deployment Workflow

### 1. Pre-Deployment Checklist

```
Before deploying:
- [ ] All tests passing locally
- [ ] Migrations reviewed and tested
- [ ] Environment variables updated in credentials
- [ ] Staging tested (for production deploys)
- [ ] Backup taken (for production)
```

### 2. Standard Deployment

```bash
# 1. Check current status
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app details -d staging'

# 2. Deploy
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal deploy -d staging'

# 3. Verify deployment
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app logs -d staging'

# 4. Smoke test via console
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging -i --reuse "bin/rails console"'
```

### 3. Migration Deployment

**Kamal runs migrations automatically before deploying new containers.**

If migration fails, deployment stops (zero-downtime preserved).

**Manual migration (if needed):**
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails db:migrate"'
```

### 4. Emergency Rollback

```bash
# Rollback to previous version
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal rollback -d production'

# Check status
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app details -d production'
```

## Troubleshooting

### Issue: Deployment Hangs

**Symptoms:** Kamal stuck on "Waiting for health check"

**Solutions:**

1. Check app logs:
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app logs -d staging'
```

2. Check container status:
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app details -d staging'
```

3. SSH to server and check Docker:
```bash
ssh staging-server
docker ps
docker logs <container-id>
```

### Issue: "Registry Authentication Failed"

**Cause:** Trying to use `--reuse` without an active connection.

**Solutions:**

1. Remove `--reuse` for first connection:
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging -i "bin/rails console"'
```

2. Or authenticate first:
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal registry login -d staging'
```

### Issue: Out of Memory (Staging Pi)

**Symptoms:** Deployment succeeds but app crashes on Raspberry Pi.

**Cause:** Pi has only ~4GB RAM.

**Solutions:**

1. Reduce Sidekiq concurrency in staging
2. Use database batches for large operations
3. Deploy during low-traffic times
4. Consider upgrading Pi memory

### Issue: "Wrong Ruby Version"

**Symptoms:** 
```
Your Ruby version is 2.6.10, but your Gemfile specified 3.2.11
```

**Cause:** Running Kamal without chruby.

**Solution:** Always wrap in `zsh -c 'source ~/.zshrc && chruby 3.2.11 && ...'`

### Issue: Migrations Fail During Deployment

**Symptoms:** Deployment stops with migration error.

**Solution:**

1. Check migration on local:
```bash
docker-compose exec -T app bundle exec rake db:migrate
```

2. Fix migration and redeploy
3. OR manually run on server:
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails db:migrate"'
```

## CI/CD Integration

### GitHub Actions (Automated)

**Staging deploys automatically on push to `develop`:**
```yaml
name: Deploy to Staging
on:
  push:
    branches: [develop]
jobs:
  deploy:
    runs-on: self-hosted  # Runs on Pi
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        run: bundle exec kamal deploy -d staging
```

**Production deploys on push to `main`:**
```yaml
name: Deploy to Production
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        run: bundle exec kamal deploy -d production
```

## Security Best Practices

### ✅ Always Do

- Use SSH keys (never passwords)
- Store secrets in Rails encrypted credentials
- Use `--reuse` flag to avoid exposing registry credentials
- Review migrations before production deploy
- Test on staging first
- Keep Kamal gem updated

### ⚠️ Ask First

- Modifying `deploy.*.yml` files
- Changing server SSH configurations
- Deploying to production outside of CI/CD
- Running destructive rake tasks on production

### 🚫 Never Do

- Commit `master.key` files
- Hardcode passwords in deploy configs
- Deploy directly to production without staging test
- Skip migrations testing
- Force deploy without health checks

## Monitoring

### Post-Deployment Verification

```bash
# 1. Check app is running
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app details -d production'

# 2. Check logs for errors
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app logs -d production --tail 100'

# 3. Test critical paths (console)
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d production -i --reuse "bin/rails console"'
> User.count
> # Test other critical models

# 4. Check Sidekiq
# Visit: https://your-domain.com/sidekiq
```

### Monitoring Endpoints

- **Sidekiq Web UI**: `https://domain.com/sidekiq`
- **Health Check**: `https://domain.com/health` (if configured)
- **App Logs**: Via Kamal `app logs` command

## Quick Reference

### Command Pattern

**ALL Kamal commands:**
```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal <command> -d <env> [flags]'
```

### Common Operations

| Task | Command |
|------|---------|
| Deploy | `kamal deploy -d staging` |
| Rollback | `kamal rollback -d staging` |
| Console | `kamal app exec -d staging -i --reuse "bin/rails console"` |
| Run rake task | `kamal app exec -d staging --reuse "bin/rails <task>"` |
| View logs | `kamal app logs -d staging` |
| Check status | `kamal app details -d staging` |

### Key Flags

- `-d <env>` - Destination (staging/production)
- `-i` / `--interactive` - Interactive mode (console)
- `--reuse` - Reuse SSH connection
- `--version=<branch>` - Deploy specific branch

## Additional Resources

- **Kamal Docs**: https://kamal-deploy.org/
- **kw-app host layer (Ansible)**: `ansible/README.md`
- **Server Provisioning**: `ansible/playbooks/`
- **Deploy Configs**: `config/deploy.*.yml`

---

**Version**: 2.0  
**Last Updated**: 2024-01  
**Maintained By**: kw-app team