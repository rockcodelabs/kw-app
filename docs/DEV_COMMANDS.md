# Development Commands Reference

> All shell commands for kw-app development. **All app commands run in Docker!**

---

## Table of Contents

1. [Testing](#testing)
2. [Console Access](#console-access)
3. [Database Operations](#database-operations)
4. [Container Management](#container-management)
5. [Code Quality](#code-quality)
6. [Generators](#generators)
7. [Deployment (Kamal)](#deployment-kamal)
8. [Debugging](#debugging)
9. [Credentials Management](#credentials-management)
10. [Maintenance](#maintenance)

---

## Testing

### Run Tests (ALWAYS in Docker)

```bash
# Run all tests
docker-compose exec -T app bundle exec rspec

# Specific file
docker-compose exec -T app bundle exec rspec spec/models/db/user_spec.rb

# Specific line
docker-compose exec -T app bundle exec rspec spec/models/db/user_spec.rb:25

# Pattern match (directory)
docker-compose exec -T app bundle exec rspec spec/components/

# Verbose mode (for debugging)
docker-compose exec -T app env VERBOSE_TESTS=true bundle exec rspec

# Fast fail (stop on first failure)
docker-compose exec -T app bundle exec rspec --fail-fast

# Documentation format
docker-compose exec -T app bundle exec rspec --format documentation

# With coverage
COVERAGE=true docker-compose exec -T app bundle exec rspec
```

### Test Specific Components

```bash
# Model tests
docker-compose exec -T app bundle exec rspec spec/models/

# Operation/Service tests
docker-compose exec -T app bundle exec rspec spec/components/

# Request/Integration tests
docker-compose exec -T app bundle exec rspec spec/requests/

# Job tests
docker-compose exec -T app bundle exec rspec spec/jobs/
```

---

## Console Access

### Development Console (Interactive - NO `-T` flag)

```bash
docker-compose exec app bundle exec rails console
```

### Staging Console (via Kamal with Native Ruby)

```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging -i --reuse "bin/rails console"'
```

### Production Console (via Kamal with Native Ruby)

```bash
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d production -i --reuse "bin/rails console"'
```

### Rails Runner (Execute Ruby Code)

```bash
# Development
docker-compose exec -T app bundle exec rails runner "puts User.count"

# Staging
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails runner \"puts User.count\""'

# Production
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d production --reuse "bin/rails runner \"puts User.count\""'
```

---

## Database Operations

### Migrations

```bash
# Run migrations
docker-compose exec -T app bundle exec rake db:migrate

# Rollback last migration
docker-compose exec -T app bundle exec rake db:rollback

# Rollback multiple steps
docker-compose exec -T app bundle exec rake db:rollback STEP=3

# Check migration status
docker-compose exec -T app bundle exec rake db:migrate:status

# Reset database (DANGEROUS - development only!)
docker-compose exec -T app bundle exec rake db:reset

# Seed database
docker-compose exec -T app bundle exec rake db:seed
```

### Database Console

```bash
# PostgreSQL console via Rails
docker-compose exec app bundle exec rails dbconsole

# Direct psql
docker-compose exec db psql -U postgres kw_app_development
```

### Database Info

```bash
# Check database size
docker-compose exec db psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"

# Vacuum analyze
docker-compose exec db psql -U postgres -d kw_app_development -c "VACUUM ANALYZE;"
```

---

## Container Management

### Basic Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Check status
docker-compose ps

# View logs (follow)
docker-compose logs -f app
docker-compose logs -f sidekiq

# View logs (last N lines)
docker-compose logs --tail=100 app

# Restart specific service
docker-compose restart app
docker-compose restart sidekiq
```

### After Gemfile Changes

```bash
# Restart containers (entrypoint will bundle install)
docker-compose restart app sidekiq

# Verify in logs
docker-compose logs app | grep bundle
```

### Rebuild Container

```bash
# If Dockerfile changed
docker-compose build app
docker-compose up -d app
```

---

## Code Quality

### Linting

```bash
# Run RuboCop
docker-compose exec -T app bundle exec rubocop

# Auto-fix issues
docker-compose exec -T app bundle exec rubocop -a

# Aggressive auto-fix (careful!)
docker-compose exec -T app bundle exec rubocop -A

# Specific files/directories
docker-compose exec -T app bundle exec rubocop app/components/users/
```

### Security Scanning

```bash
# Brakeman security scanner
docker-compose exec -T app bundle exec brakeman

# Check for vulnerable gems
docker-compose exec -T app bundle exec bundle-audit check --update
```

### Dependency Checks

```bash
# Check outdated gems
docker-compose exec -T app bundle outdated

# Install gems
docker-compose exec -T app bundle install
```

---

## Generators

### Models

```bash
# Generate model
docker-compose exec -T app bundle exec rails g model User email:string name:string

# Generate migration
docker-compose exec -T app bundle exec rails g migration AddAgeToUsers age:integer
```

### Operations/Services

```bash
# Create directory structure manually (no generator)
mkdir -p app/components/users/operation
touch app/components/users/operation/create.rb
```

### Jobs

```bash
# Generate job
docker-compose exec -T app bundle exec rails g job UserNotification
```

### Other

```bash
# List all generators
docker-compose exec -T app bundle exec rails g --help

# List all rake tasks
docker-compose exec -T app bundle exec rake -T

# Environment info
docker-compose exec -T app bundle exec rake about
```

---

## Deployment (Kamal)

> **Note:** Kamal commands use native Ruby (chruby 3.2.11), NOT Docker!

### Deploy

```bash
# Deploy to staging
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal deploy -d staging'

# Deploy to production
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal deploy -d production'

# Rollback
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal rollback -d production'
```

### Monitoring

```bash
# Check app status
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app details -d staging'

# View logs
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app logs -d staging'

# Tail logs
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app logs -d staging --tail 100'
```

### Remote Commands

```bash
# Run rake task on remote
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails db:migrate:status"'

# Run rails runner on remote
zsh -c 'source ~/.zshrc && chruby 3.2.11 && bundle exec kamal app exec -d staging --reuse "bin/rails runner \"puts User.count\""'
```

### Kamal Flags Reference

| Flag | Purpose |
|------|---------|
| `-d staging` | Target staging environment |
| `-d production` | Target production environment |
| `-i` / `--interactive` | Keep terminal interactive (for console) |
| `--reuse` | Reuse SSH connection, no registry credentials |

---

## Debugging

### Check Logs

```bash
# Application logs
docker-compose logs -f app

# Sidekiq logs
docker-compose logs -f sidekiq

# PostgreSQL logs
docker-compose logs -f db

# Redis logs
docker-compose logs -f redis

# Filter for errors
docker-compose logs app | grep -i error
```

### Check Routes

```bash
# All routes
docker-compose exec -T app bundle exec rails routes

# Filter routes
docker-compose exec -T app bundle exec rails routes | grep users
```

### Browser Automation (Playwright)

```bash
# Start Playwright container
docker-compose up -d playwright

# Run Playwright script
docker-compose exec -T app bundle exec rails runner "$(cat tmp/playwright/script.rb)"
```

### cURL Testing

```bash
# Get login page + save cookies
curl -c cookies.txt http://localhost:3002/users/sign_in > login.html

# Extract CSRF token
TOKEN=$(grep -o 'name="authenticity_token" value="[^"]*"' login.html | cut -d'"' -f4)

# Login
curl -c cookies.txt -b cookies.txt -X POST http://localhost:3002/users/sign_in \
  -d "authenticity_token=$TOKEN" \
  -d "user[email]=EMAIL" \
  -d "user[password]=PASSWORD" \
  -H "Accept: text/html"

# Access protected page
curl -b cookies.txt -H "Accept: text/html" http://localhost:3002/wydarzenia

# Check redirects
curl -I -b cookies.txt http://localhost:3002/wydarzenia
```

---

## Credentials Management

### Edit Credentials

```bash
# Development
docker-compose exec app bash -c "EDITOR=vim bin/rails credentials:edit --environment development"

# Staging
docker-compose exec app bash -c "EDITOR=vim bin/rails credentials:edit --environment staging"

# Production
docker-compose exec app bash -c "EDITOR=vim bin/rails credentials:edit --environment production"
```

### View Credentials (Structure Only)

```bash
docker-compose exec app bash -c "bin/rails credentials:show --environment development"
```

---

## Maintenance

### Clear Caches

```bash
# Rails cache
docker-compose exec -T app bundle exec rails runner "Rails.cache.clear"

# Tmp files
docker-compose exec -T app bundle exec rake tmp:clear

# Assets
docker-compose exec -T app bundle exec rake assets:clobber
```

### Sidekiq

```bash
# Sidekiq web UI
# Visit: http://localhost:3000/sidekiq

# Clear all queues (DANGEROUS)
docker-compose exec -T app bundle exec rails runner "Sidekiq::Queue.all.each(&:clear)"
```

### Cleanup

```bash
# Remove Playwright temporary scripts
rm tmp/playwright/*.rb
rm tmp/playwright/screenshots/*

# Docker cleanup
docker system prune -f
```

---

## Quick Reference

### Docker vs Native Ruby

| Context | Use |
|---------|-----|
| Tests, Console, Rake, Rails runner | Docker (`docker-compose exec`) |
| Kamal deployment commands | Native Ruby (`chruby 3.2.11`) |

### Why Docker is Mandatory

- System Ruby (2.6.10) ≠ App Ruby (3.2.11)
- Tests need PostgreSQL 10.3 and Redis 7 from containers
- Consistent gem versions
- Matches CI environment

### Common Mistakes

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| `bundle exec rspec` | `docker-compose exec -T app bundle exec rspec` |
| `rails console` | `docker-compose exec app bundle exec rails console` |
| `rake db:migrate` | `docker-compose exec -T app bundle exec rake db:migrate` |

---

## Related Documentation

- **[.rules](../.rules)** - AI constraints
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture details
- **[KNOWN_ISSUES.md](KNOWN_ISSUES.md)** - Known bugs and solutions
- **[AGENTS.md](../AGENTS.md)** - Available agents

---

**Version:** 1.0  
**Last Updated:** 2025