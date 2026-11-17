# CLAUDE.md

> Quick reference for AI assistants. **Read [.rules](.rules) first!**

---

## Documentation Map

| Document | Purpose |
|----------|---------|
| [.rules](.rules) | **AI constraints (READ FIRST)** |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Full architecture details |
| [docs/DEV_COMMANDS.md](docs/DEV_COMMANDS.md) | All shell commands |
| [docs/FEATURE_WORKFLOW.md](docs/FEATURE_WORKFLOW.md) | @feature development phases |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Known bugs and solutions |
| [AGENTS.md](AGENTS.md) | Available agents and routing |
| [.agents/](.agents/) | Individual agent specifications |
| [.agents/skills/](.agents/skills/) | Deep-dive knowledge modules |
| [templates/](templates/) | Code templates |

---

## Critical Commands

```bash
# Run tests (ALWAYS in Docker)
docker-compose exec -T app bundle exec rspec

# Run specific test
docker-compose exec -T app bundle exec rspec spec/path/to/file_spec.rb:25

# Console (interactive)
docker-compose exec app bundle exec rails console

# Lint
docker-compose exec -T app bundle exec rubocop -a

# Migrations
docker-compose exec -T app bundle exec rake db:migrate
```

---

## Architecture Summary

```
Request → Controller → Operation → Model → Database
               ↓           ↓
            Form/      Validation
           Contract
```

### Key Patterns

- **Operations** use `Dry::Monads[:result, :do]` → return `Success(value)` / `Failure(error)`
- **Controllers** are thin → delegate to operations, pattern match results
- **Models** are thin → associations, validations, scopes only (namespaced as `Db::Model`)
- **Jobs** pass IDs, not objects

---

## Quick Boundaries

| ✅ Always | ⚠️ Ask First | 🚫 Never |
|-----------|--------------|----------|
| Use Docker for commands | DB migrations | Hardcode secrets |
| Write tests | Git operations | Skip tests |
| Use dry-monads | Add gems | Use custom Result classes |
| Check KNOWN_ISSUES.md | Deploy changes | Run tests outside Docker |

---

## Tech Stack

| Component | Version |
|-----------|---------|
| Ruby | 3.2.11 |
| Rails | 7.0.8 |
| PostgreSQL | 10.3 |
| Redis | 7 |

---

**For all details, see [.rules](.rules) and [docs/](docs/)**

---

**Version:** 3.0  
**Last Updated:** 2025