# kw-app

Rails monolith with Sidekiq, PostgreSQL, Redis. Deployed via Docker + Kamal.

---

## 🖥️ Servers

- **Development**: Local (Docker Compose)
- **Staging**: Raspberry Pi (`pi5main.local`) - ARM64, manual deploy
- **Production** (live since 2026-11-20): VPS `51.255.38.227` (OVH, Ubuntu 26.04) - x86_64, `https://panel.kw.krakow.pl`, deploy via GitHub Actions (PR `staging` -> `main`; merging deploys automatically after the tests pass, no manual approval), see `docs/NEW_PRODUCTION_PLAN.md`
- **Old production** (`51.68.141.247`): frozen, no longer serves the panel (its database is stale since the cutover). Read-only; other sites still run there

---

## 🚀 Setup

### Development (Fresh Machine)

**Prerequisites:** Docker, Docker Compose

```bash
# 1. Clone repo
git clone <repo-url> && cd kw-app

# 2. Build and start services
docker-compose build
docker-compose up -d postgres redis mailcatcher
sleep 5

# 3. Create databases
docker-compose exec -T postgres psql -U dev-user -c "CREATE DATABASE kw_app_development;" postgres
docker-compose exec -T postgres psql -U dev-user -c "CREATE DATABASE kw_app_test;" postgres

# 4. Migrate and seed
docker-compose run --rm -T app bundle exec rake db:migrate db:seed

# 5. Start app
docker-compose up -d

# Visit http://localhost:3002
```

**Local services:**
- App: http://localhost:3002
- Sidekiq: http://localhost:3002/sidekiq
- MailCatcher: http://localhost:1080

### Staging/Production Setup

See [ansible/README.md](ansible/README.md) for server provisioning.

---

## 🎮 Rails Console

```bash
# Local
docker-compose exec app bundle exec rails console

# Staging (SSH first: ssh rege@pi5main.local)
kamal app exec --reuse -d staging "bundle exec rails console"

# Production (live data, read-only habits)
kamal app exec -d production -i --reuse "bin/rails console"

# Production, one-off script without Kamal (non-interactive)
echo 'puts Db::User.count' | ssh deploy@51.255.38.227 'docker exec -i $(docker ps -q -f name=kw-app-web-production) bin/rails runner -e production -'
```

---

## 📦 Deployment

### Staging (Manual)
```bash
ssh rege@pi5main.local
cd ~/kw-app && git pull origin staging
kamal deploy -d staging
```

### Production (Automatic)
```bash
# Push to 'main' branch - GitHub Actions handles the rest
git push origin main
```

---

## 🔐 Secrets

Encrypted credentials in `config/credentials/*.yml.enc`. Master keys in Bitwarden (never commit).

**Edit:**
```bash
docker-compose exec app bash -c "EDITOR=vim bin/rails credentials:edit --environment development"
```

See [docs/RAILS_ENCRYPTED_CREDENTIALS.md](docs/RAILS_ENCRYPTED_CREDENTIALS.md)

---

## 📚 Documentation

- **Docker setup**: [docs/DOCKER_SETUP.md](docs/DOCKER_SETUP.md)
- **Known issues**: [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
- **AI guidelines**: [CLAUDE.md](CLAUDE.md)
- **Zed agents**: [.agents/README.md](.agents/README.md)

---

## 🤝 Contributing

**Where to commit:**
Branch flow: `develop` -> `staging` -> `main`.

- Features/fixes: `develop` branch (development; CI tests only, no deploy)
- Staging deploy: push or merge to `staging` branch (triggers `Deploy Staging`)
- Production deploy: PR `staging` -> `main` (merging triggers `Deploy Production`)

**Never commit:** Master keys, secrets, or `config/credentials/*.key` files.