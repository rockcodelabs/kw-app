---
name: staging-controller-testing
description: Exercise Rails controller actions end-to-end on the kw-app staging server (Raspberry Pi) without touching real data, mail or Sidekiq. Runs a scenario inside the live staging container via `rails runner -`, in a rolled-back transaction, as throwaway users per role. Use to review/verify a controller (e.g. Settlement::Admin::ContractsController), check authorization, or reproduce staging-only 500s.
allowed-tools: Read, Write, Edit, Bash
---

# Staging Controller Testing (kw-app)

Drives real HTTP requests through the full Rack stack (routing, Devise/Warden, CanCan, views, ransack, workflow) **inside the staging container**, against the staging database and staging gem versions, then rolls everything back.

Use it when specs are not enough: staging runs the deployed image and real config (e.g. `Rails.env == staging`, mailgun, async ActiveJob), and a controller can pass specs but 500 there.

## How it works

```
scenario (Ruby, this repo)  ──cat──►  ssh pi5main.local  ──►  docker exec -i <web container> bin/rails runner -
                                                                   │
                         harness.rb: guard staging → stub jobs/mail → BEGIN
                                      create throwaway users → Warden login_as → ActionDispatch::Integration::Session
                                      assert → ROLLBACK → verify row counts unchanged
```

No deploy and no commit is needed: the code under test is whatever is already deployed on staging; the scenario is streamed over stdin.

## Safety guarantees (enforced by `harness.rb`)

| Risk | Mitigation |
|------|------------|
| Running on the wrong env | `abort` unless `Rails.env.staging?`; production is accepted only with `-e HARNESS_ALLOW_PRODUCTION=yes` (P7 rehearsal dry run, post-flip check after P8, see "Post-deploy gate") |
| Persisting test data | One outer transaction, always `ActiveRecord::Rollback`; afterwards the harness checks that no throwaway row is left (users `*@example.invalid`, records named `stg-check*`); outside production it also compares row counts of the `TRACKED_MODELS`. On production counts are not compared (live traffic changes them) |
| Real emails (Mailgun) | `ActionMailer` → `:test`, `perform_deliveries = false`; aborts if `MailDeliveryJob` is not on the test adapter |
| Jobs hitting Redis/Sidekiq or the async adapter running after rollback | `ActiveJob::Base.queue_adapter = :test`; inspect with `h.enqueued_jobs` |
| Real credentials | Users are `stg-check+<role>-<hex>@example.invalid`, logged in via `Warden.test_mode!` `login_as` (process-local) |
| CSRF blocking PUT/POST/DELETE | `allow_forgery_protection = false` in the runner process only |
| AppSignal noise | The AppSignal agent is **active** in staging and also starts inside `rails runner`, so test errors/traces would show up as real incidents. The harness aborts unless run with `-e APPSIGNAL_ACTIVE=false` |

All overrides live only in the short-lived runner process; the serving app processes are untouched.

**Still your responsibility:**
- Endpoints that read files from the container (e.g. `download_attachment`) must be probed with harmless paths such as `/etc/hostname`.
- Anything that writes outside Postgres (files via CarrierWave, S3/fog, external HTTP) is **not** rolled back. Do not upload files or call endpoints that hit external APIs. Use `document_type: 'charities'` style params to avoid required uploads.
- Production is allowed **only** through `bin/post-deploy-check production` (the production-safe scenarios, throwaway data, rolled back). Never run `post_migration_smoke.rb` there: it registers users, touches files and calls webhooks.
- **Name every record a scenario creates `stg-check ...`** (users already are `*@example.invalid`). The leftover check can only see rows with these markers.

## Prerequisites

- SSH access to `pi5main.local` (key based; `ssh -o BatchMode=yes pi5main.local true` should succeed)
- The staging web container running (`docker ps` label `service=kw-app-staging`, `role=web`)
- Runs from the host with plain `ssh`; **no Docker Compose, no chruby** needed (Ruby runs in the container)

## Run a scenario

From `.agents/skills/staging-controller-testing/`:

```bash
cat harness.rb scenarios/settlement_admin_contracts.rb \
  | ssh pi5main.local 'docker exec -e APPSIGNAL_ACTIVE=false -i $(docker ps -q --filter label=service=kw-app-staging --filter label=role=web --filter status=running | head -n1) bin/rails runner -'
```

- `-e APPSIGNAL_ACTIVE=false` is **mandatory** (the harness aborts without it) so test traffic does not create AppSignal incidents.

- The container name changes on every Kamal deploy, so always discover it as above (single quotes: the `$(...)` must expand on the server).
- Exit code is `0` when all checks pass, `1` otherwise (propagates through ssh).
- Show failures only: append `| grep -vE '^\s+PASS'`.
- A full run takes roughly 1 minute on the Pi (Rails boot dominates).

## Output

```
== Settlement::Admin::ContractsController (staging, db=kw_app_staging)
-- accept
  PASS secondary accepts new contract
  FAIL accepting already accepted contract does not 500  -> expected 302, got 500 | Workflow::NoTransitionAllowed: ...
== 57/84 checks passed
```

A 500 prints the exception class and message captured from `action_dispatch.exception`. For the stack trace and SQL, see the `staging-logs-appsignal` skill.

## Writing a scenario

Create `scenarios/<namespace>_<controller>.rb`. It is concatenated after `harness.rb`, so it can call `StagingHarness` directly.

```ruby
StagingHarness.run('Namespace::SomeController') do |h|
  r      = h.routes                              # Rails.application.routes.url_helpers
  admin  = h.user('admin', roles: %w[admin])     # throwaway Db::User
  member = h.user('member', active: true)        # active: true => Ability#active (membership) is true
  anon   = h.client                              # not logged in
  as     = ->(label, user) { h.client(label, user) }

  h.check_denied('anonymous cannot list', anon.get(r.things_path))
  h.check_status('admin lists', as.('admin', admin).get(r.things_path), 200)
  res = as.('member', member).post(r.things_path, params: { thing: { name: 'x' } })
  h.check_status('member creates', res, 302)
  h.check('row persisted', Thing.where(name: 'x').count, 1)
end
```

### Harness API

| Call | Purpose |
|------|---------|
| `h.user(label, roles: [], active: false)` | Create a throwaway user. `roles` are `Db::User` roles (see `Ability`). `active: true` forces `Membership::Activement#active?` |
| `h.client(label = 'anonymous', user = nil)` | Session; `.get/.post/.put/.patch/.delete(path, params: {})` returns `Response` (`status`, `location`, `body`, `content_type`, `headers`, `exception`, `redirect?`) |
| `h.check_status(name, response, 200 \| [302, 303])` | Status equals value, or any of an Array |
| `h.check_denied(name, response)` | 401/403 **or redirect to `/`** (what `CanCan::AccessDenied` does here). A bare 302 is *not* denial |
| `h.check(name, actual, expected)` | `expected === actual`: value, Range (`1..`), Regexp. Arrays are compared exactly |
| `h.enqueued_jobs` / `h.clear_enqueued_jobs!` | Inspect jobs/mails that `deliver_later` queued |
| `h.capture_mail { ... }` | Runs the block with mail jobs performed inline into the `:test` delivery; returns the deliveries. Aborts if the delivery method is not `:test` |
| `h.known_gap(id, name, actual, expected)` | A documented open finding (e.g. `G23`). Prints `GAP` and does not fail the run while open; once the behaviour is fixed it counts as a pass and says `promote this to a plain check` |
| `h.info(name, text)` | Prints an `INFO` line (hosts, counts). Never pass secret values |
| `h.routes` | URL helpers |

### Scenario conventions

1. **Persona matrix**: anonymous, no-role/outsider, active member (owner), each privileged role the `Ability` grants (`office_king`, `financial_management`, `secondary_management`, `admin`, ...).
2. **Per action** check: unauthenticated, unauthorized, authorized happy path, invalid input, unknown id, and wrong state (e.g. workflow transition from the wrong state).
3. **Always assert the data effect**, not only the status. `redirect` is returned on success *and* on denial, so also `record.reload` and compare state/columns after a "denied" call.
4. **Build fixtures with `create!` inside the block**, one per case, so cases do not influence each other. Use high `internal_number`s or other unique values to avoid unique-index clashes with existing staging rows.
5. Expectations describe **intended** behaviour (from `Ability`, UI, domain rules). Treat every FAIL as either a controller bug or a wrong expectation. Decide which before changing code.
6. Keep one scenario per controller; do not put business rules in the harness.

## Gotchas learned the hard way

- **Container is renamed on each deploy.** A stale name gives `container ... is not running`. Use the discovery one-liner.
- **Password max length is 12** on `Db::User`; the harness uses `SecureRandom.hex(5)`.
- **`rails runner -`** reads the script from stdin; `docker exec` needs `-i` (no `-t`).
- Harness requests are written to the real `log/staging.log` (request host `staging-check.local`, runner pid, source IP `127.0.0.1`). Use the `staging-logs-appsignal` skill to read them.
- **Class-level `authorize!` ignores CanCan conditions.** `authorize! :finish, Settlement::ContractRecord` passes for any role with `can :manage, ContractRecord, state: [...]`, so state conditions in `Ability` do not protect collection/member actions unless the controller authorizes the *instance*.
- **Actions without `authorize!`** are open to anonymous users (no `authenticate_user!` in `Admin::BaseController`). Always include an anonymous check.
- Staging `config.hosts` is cleared; the harness uses `staging-check.local` as the request host. On production the host is `HARNESS_HOST` (default `panel.kw.krakow.pl`, right also before the DNS flip because the requests never leave the container) and requests are https.
- The harness forces `show_exceptions` on, so an exception is a 500 response with `Response#exception`, on every environment (also when trying a scenario locally with `RAILS_ENV=test`, which needs a temporary harness copy without the env guard and `HARNESS_HOST=www.example.com`).
- `dry-validation` is 1.x: `Contract` classes need `.new`/`.call` on an instance. Code written for 0.x (`Form.call`, `.with`) raises `NoMethodError` on staging.
- **A client that registers or signs in stays signed in.** Use a fresh `h.client('fresh-anon')` for every anonymous check that follows a registration or login.
- Devise sign-out is **GET** `/users/sign_out`; admin accept is **PUT**.
- The Warden `login_as` hook is global, so do not mix clients' expectations within one request chain.
- `TRACKED_MODELS` in the harness (includes `Db::Profile`, `Db::Payment`) are the models whose row counts are compared before and after the rollback; add models your scenario writes to.
- `Dry::Validation` messages, Polish locale strings and flash text may change; assert on status/data, not on flash copy.

## Interpreting results & next steps

1. Group FAILs by root cause (one missing `authorize!` often yields several FAILs).
2. Confirm in code before reporting; separate **bugs** (500s, missing authorization, wrong state effects) from **policy questions** (is `financial_management` meant to be able to `finish`?).
3. Fix via the normal workflow (TDD with RSpec in Docker, see `testing-standards`), then re-run the scenario after the staging deploy (`kamal-deployment`) to confirm.
4. Port stable, valuable checks into `spec/requests/` so CI covers them. Keep this scenario for staging-only concerns.

## Ready-made scenarios

| Scenario | Purpose |
|----------|---------|
| `scenarios/settlement_admin_contracts.rb` | Authorization matrix and workflow (accept, prepayment, finish) for `Settlement::Admin::ContractsController`. Production-safe. Open `known_gap` G37 (role boundary policy) |
| `scenarios/training_supplementary_courses_signups.rb` | Courses/events, sign-ups, cash payment, Dotpay callback, expiry cron code path (`B-CRS`, `B-SUP`, `B-PAY`). Production-safe. Open `known_gap` G23/G23b (unsigned or unknown Dotpay callback) |
| `scenarios/reservations_module.rb` | Gear reservations: availability, booking, double booking, cancel (own vs foreign), keeper actions, unpaid-cleanup candidates (`B-RES`). Production-safe, uses throwaway items |
| `scenarios/post_migration_smoke.rb` | Post-migration smoke checks (`B-xx` IDs) for login, profiles, mail, notifications, Dotpay callback, Strava webhook, files, cron code paths. Results are mapped in `docs/NEW_PRODUCTION_PLAN.md` Appendix B. Some checks FAIL by design to document known vulnerabilities (G23) |

## Post-deploy gate (`bin/post-deploy-check`)

One command runs the three production-safe scenarios (contracts, courses and sign-ups, reservations) and prints a summary with an exit code. Use it as one step of the first 30 minutes after the P8 flip (plan Appendix B.3) and once as a dry run on the P7 rehearsal.

```bash
bin/post-deploy-check staging    --dry-run          # prints the exact ssh/docker commands, runs nothing
bin/post-deploy-check staging
bin/post-deploy-check production --confirm   # works before the flip too: it runs inside the container
bin/post-deploy-check production --confirm                                  # after the flip, host panel.kw.krakow.pl
```

- Production needs `--confirm` and only accepts the three safe scenarios; `--only a,b` narrows the list.
- It uses one multiplexed SSH connection (fail2ban friendly). SSH destination and options are overridable with `POST_DEPLOY_SSH_STAGING`, `POST_DEPLOY_SSH_PRODUCTION`, `POST_DEPLOY_SSH_OPTS`; `POST_DEPLOY_DOCKER="sudo docker"` if the SSH user needs it.
- `GAP` lines are known open findings and do not fail the run. Anything else that is not `PASS` does: read it with the `staging-logs-appsignal` skill.
- Why this is safe on a live database: one transaction that is always rolled back, throwaway users and items, mail and jobs stubbed (`:test`), AppSignal off, no Dotpay call, leftover check afterwards. It cannot prove that real credentials work (Dotpay, Mailgun): those stay manual rows in Appendix B.

## Related

- `kamal-deployment`: deploy, logs, console on staging
- `staging-logs-appsignal`: read the logs and AppSignal incidents behind a failing check
- `testing-standards`: RSpec conventions (Docker only)
- `rails-service-object`, `dry-monads-patterns`: when fixing operations
- Ability definitions: `app/models/ability.rb`
