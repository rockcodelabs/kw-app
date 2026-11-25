---
name: release-pr
description: Release develop -> main for kw-app (staging is skipped by default, used only when the owner says so). "Deploy to prod" / "release to prod" = open the PR, watch the PR test checks and MERGE it automatically when green (no further permission needed), then watch the production deploy. "Create PR to main" / "prepare a release PR" = open the PR and return the link only, never merge. Never pushes to main directly.
allowed-tools: Read, Write, Bash
---

# Release PR: develop -> main (kw-app)

**Default: staging is skipped.** The release PR is **`develop` -> `main`**. Staging (`pi5main.local`) is only for special purposes and is used **only when the owner explicitly says so** (e.g. "go through staging", "test on staging first", "release from staging"). Never promote to `staging` or ask about it on your own; do not mention it as a missing step.

In this skill `SRC` is the release source branch: **`develop` by default**, `staging` only when the owner asked for the staging route (see "Staging route" at the end).

Branch meanings:

| Branch | Environment | What a push does |
|--------|-------------|------------------|
| `develop` | development / integration (default release source) | Runs `Test Suite` only. **No deploy** |
| `staging` | staging (`pi5main.local`), special purposes only | Runs `Test Suite` and `Deploy Staging` |
| `main` | production (`51.255.38.227`) | Merging a PR runs `Deploy Production` |

Merging a PR into `main` **deploys to production automatically** once the `test` job is green: the `production` Environment has no required reviewer (removed 2026-11-25), only the `main` branch restriction.

## Two modes (decided by the owner's wording)

| Owner says | Mode | What you do |
|------------|------|-------------|
| "deploy to prod", "release to prod", "ship to production", "deploy" (meaning production), "release" | **Deploy** | Steps 1-5, then step 6: watch the PR checks and **merge automatically when green**, then watch the production deploy. The owner's request is the permission to merge; do **not** ask again |
| "create PR to main", "prepare a release PR", "open a PR", "give me the link" | **PR only** | Steps 1-5 and 7 (report). **Never merge**; the owner merges |

If the wording is ambiguous, treat it as **PR only** and ask once whether to merge.

Because staging is skipped, **nothing was exercised on staging**: be extra careful about migrations and config (step 2) and say so in the report. Make sure what ships is understood, tested and conflict-free.

Repo: `rockcodelabs/kw-app` (always pass `--repo rockcodelabs/kw-app` to `gh`). Production: `51.255.38.227`, `https://panel.kw.krakow.pl`. See `.rules` section 14.

`gh` prints an "upgrade available" banner on stderr; ignore it (or filter with `grep -v -i "new release\|brew upgrade\|releases/tag"`).

## Scope of a release

The release is **every commit on `origin/SRC` that is not on `origin/main`** (`git log origin/main..origin/SRC`), always computed fresh after `git fetch`. Not "what I worked on in this session", not the commits an older PR listed. The summary, title, risk check and CI check all cover that whole range and the exact current head of `origin/SRC`.

## Hard rules

1. **Never push to `main`, never force-push, never bypass branch protection** (no `--admin`, no disabling checks, no editing the ruleset). The only way to change `main` is merging the PR through `gh pr merge`.
2. **Merge only in Deploy mode** (owner said "deploy to prod" / "release to prod"), and only when every merge condition in step 6 holds. In PR-only mode never merge.
3. Only run when the user asks for a release / PR to main / deploy to prod.
4. Do not change code in this flow. If a check fails, report it and stop; fixing is a separate task.
5. **Do not push to `staging` by default** (it deploys staging). Only in the staging route, only after the owner asked, and only as a fast-forward (never `--force`).
6. Work from `origin/*` refs, not from the local checkout. Do not switch branches or touch the working tree. If the local `develop` has unpushed commits, tell the owner they are not in the release (the PR can only contain what is on `origin/develop`); pushing `develop` is a git operation: ask first.
7. Stop and report on any blocker below (a failing check, conflicts, a secret warning: never merge past them). Do not work around it.

## Steps

### 1. Preflight

```bash
git fetch -q origin
git status -sb | head -1                                   # local develop ahead of origin/develop? (unpushed commits are NOT released)
git rev-list --left-right --count origin/main...origin/develop   # "<only on main>  <only on develop>"
```

- `<only on develop>` = 0: nothing to release, say so and stop.
- `<only on main>` > 0 is normal (merge commits of earlier PRs, hotfixes). What matters is conflicts (step 4); if main has real commits that develop lacks, mention it.

### 2. What is going to production

```bash
git --no-pager log --oneline origin/main..origin/develop        # commits in the release
git --no-pager diff --stat origin/main...origin/develop | tail -n 40
git --no-pager diff --name-only origin/main...origin/develop
```

Flag these in the PR body and in your reply when present in the changed-file list:

| Changed path | Why it matters |
|--------------|----------------|
| `db/migrate/*`, `db/schema.rb`, `db/structure.sql` | **Migrations run on production at boot** (`db:prepare` in the image entrypoint) and were **not** rehearsed on staging. Read each migration: reversible? safe/fast on live data (locks, big backfills)? Say plainly in the report that it was not exercised on staging |
| `Gemfile`, `Gemfile.lock` | New or bumped gems; the image rebuilds |
| `config/deploy*.yml`, `.github/workflows/*`, `Dockerfile*`, `.kamal/*` | Deploy config: affects how production is deployed |
| `config/initializers/*`, `config/environments/production.rb`, `config/credentials/*.yml.enc`, `config/routes*` | Runtime behaviour on boot |
| `config/crontab`, `lib/tasks/*`, `app/jobs/*` | Cron/Sidekiq: runs unattended on production |
| `*.key`, `.env*`, anything that looks like a secret | **Stop.** Never release secrets; tell the user |

Quick secret sanity check on the diff (names only, never print matches):

```bash
git --no-pager diff origin/main...origin/develop -U0 | grep -c -i -E "(api[_-]?key|secret|password|token)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9/+_-]{16,}" || true
```

A non-zero count is a warning to look at the lines locally (`git diff ... | grep -n ...` and inspect), not proof; do not paste values into the chat.

### 3. Verify the exact commit that will ship

The release is the head of `origin/develop`:

```bash
SHA=$(git rev-parse origin/develop)
gh run list --repo rockcodelabs/kw-app --branch develop --limit 8 \
  --json workflowName,status,conclusion,headSha \
  --jq '.[] | select(.headSha=="'"$SHA"'") | [.workflowName,.status,.conclusion] | @tsv'
```

Need, **for that exact sha**: `Test Suite` `completed success`.

- `in_progress`: wait (poll every ~60 s, up to ~10 min, or `gh run watch <id> --exit-status`), then re-check.
- `failure`: **stop**, report the failing job (`gh run view <id> --log-failed`), do not open the PR.
- No `Test Suite` run for that sha: start one (it deploys nothing) and wait for it:

  ```bash
  gh workflow run test.yml --repo rockcodelabs/kw-app --ref develop
  ```

  Do not run the suite on the host (rules section 5). Local Docker runs are only valid when the checkout is exactly `origin/develop`.

`Deploy Staging` is **not** required (staging is skipped). Do not report its absence as a problem.

### 4. Mergeability (no conflicts)

```bash
git merge-tree --write-tree origin/main origin/develop >/dev/null 2>&1; echo "rc=$?"   # 0 = clean merge
```

Non-zero means conflicts with `main`: **stop** and report the files (`git merge-tree --write-tree --name-only origin/main origin/develop`). Resolving needs the user's decision (merging `main` into `develop` is a git operation: ask first).

### 5. Create or reuse the PR

Look for an existing one first:

```bash
gh pr list --repo rockcodelabs/kw-app --base main --state open --json number,url,title,headRefName
```

- None from `develop`: write the body to a temp file (avoids shell quoting problems), create the PR, delete the file.
- Open PR from `develop` exists: **reuse it, but always refresh it** so it describes the release as it is *now*. A PR opened earlier goes stale when more commits land on `develop` (the PR follows the branch head, but title/body and the CI line do not). Compare:

  ```bash
  gh pr view <n> --repo rockcodelabs/kw-app --json headRefOid,commits --jq '{head: .headRefOid, commits: (.commits|length)}'
  git rev-parse origin/develop                       # must equal PR head
  git rev-list --count origin/main..origin/develop   # must equal PR commits count
  ```

  Then regenerate title and body from the **full** current `git log origin/main..origin/develop` (same template as below, every commit listed, CI line for the current `origin/develop` sha) and apply them, even if the old body looks "close enough":

  ```bash
  gh pr edit <n> --repo rockcodelabs/kw-app --title "<title>" --body-file tmp/release_pr_body.md
  rm -f tmp/release_pr_body.md
  ```

  This only edits PR text (no merge, no push), so it needs no extra approval. In the report say that an existing PR was refreshed and from how many to how many commits.
- An open PR into `main` from another branch (e.g. `staging`): mention it, do not touch it; create the `develop` one unless the owner wants that one.

Write `tmp/release_pr_body.md` with `write_file`:

```markdown
## Release develop -> main

<2-4 line summary of what changed, grouped by area, from the commit list>

### Commits (<N> commits not on main)
<COMPLETE output of git log --oneline origin/main..origin/develop, one per line, as a list; never a subset, the count must match N>

### Risk check
- Migrations: <none | list, reversible?> (staging skipped: not rehearsed there)
- Gems / deploy config / cron / initializers: <none | list>
- CI on <short sha>: Test Suite <result>

### Deploy
Merging this PR **deploys to production automatically** (`Deploy Production`, after the `test` job; no approval step; staging was skipped). Watch it: `gh run list --repo rockcodelabs/kw-app --workflow deploy-production.yml --limit 1`.
```

Title: a short imperative summary of the release (e.g. `Release: <main change>, <second change>`); for a single-commit release use that commit's subject.

```bash
gh pr create --repo rockcodelabs/kw-app --base main --head develop --title "<title>" --body-file tmp/release_pr_body.md
rm -f tmp/release_pr_body.md
```

### 6. Deploy mode only: wait for green checks, merge, watch the deploy

Skip this step in PR-only mode.

1. Wait for the PR checks (the required `test` check runs on the PR itself):

   ```bash
   gh pr checks <n> --repo rockcodelabs/kw-app --watch --interval 30
   ```

   (bound it, e.g. `timeout_ms` ~15 min; re-run if it times out while still running).

2. Merge **only if all of these hold**, otherwise stop and report (do not merge, do not retry blindly):
   - all required checks `pass` (`gh pr checks <n> --repo rockcodelabs/kw-app` shows no `fail`/`pending`);
   - `gh pr view <n> --repo rockcodelabs/kw-app --json mergeable,mergeStateStatus,headRefOid` reports `mergeable: MERGEABLE`, `mergeStateStatus: CLEAN` (or `HAS_HOOKS`) and `headRefOid` still equals `git rev-parse origin/develop` after a fresh `git fetch` (nothing new landed while waiting; if it did, refresh the PR and wait for the new checks);
   - no step 2 secret warning and no conflicts;
   - the PR is `develop` -> `main` (or `staging` -> `main` in the staging route), base `main`.

3. Merge with a merge commit (history of `main` uses "Merge pull request #N"). Never `--admin`, never `--squash`/`--rebase` unless the owner asks:

   ```bash
   gh pr merge <n> --repo rockcodelabs/kw-app --merge
   ```

   If branch protection refuses, stop and report the reason; do not work around it.

4. Watch the production deploy that the merge started:

   ```bash
   gh run list --repo rockcodelabs/kw-app --workflow deploy-production.yml --limit 1 --json databaseId,status,conclusion,headSha
   gh run watch <databaseId> --repo rockcodelabs/kw-app --exit-status
   curl -s -o /dev/null -w '%{http_code}\n' https://panel.kw.krakow.pl/up     # expect 200
   ```

   (use a generous `timeout_ms`, the deploy builds an image). On failure report the failing step and `gh run view <id> --log-failed` excerpt (no secrets); **do not rollback or redeploy on your own**: `kamal rollback -d production` needs the owner's approval.

### 7. Report back (always end with this)

Give the user, in this order:

1. **PR link** (first line, so it is easy to click), and in Deploy mode the outcome: merged (merge commit sha) / not merged and why.
2. What ships: 3-6 bullets, plus the commit count.
3. Verification: which sha, `Test Suite` result, mergeability. State that staging was skipped.
4. Flags from step 2 (migrations, gems, deploy config...) or "none".
5. Unpushed local commits that are not in the release, or "none".
6. PR-only mode: one line "Merging deploys to production automatically after the `test` job." Deploy mode: the `Deploy Production` result and the `/up` status code.

Optionally add a PR status snapshot: `gh pr view <n> --repo rockcodelabs/kw-app --json mergeable,mergeStateStatus --jq '{mergeable, mergeStateStatus}'`. The required `test` check runs on the PR itself (`pull_request` to `main`), so `mergeStateStatus` may be `BLOCKED`/`UNSTABLE` for a couple of minutes right after creation: that is normal, say "checks are running".

## After the owner merges (PR-only mode, only if asked to watch)

```bash
gh run list --repo rockcodelabs/kw-app --workflow deploy-production.yml --limit 1 --json databaseId,status,conclusion,headSha
gh run watch <databaseId> --repo rockcodelabs/kw-app --exit-status
curl -s -o /dev/null -w '%{http_code}\n' https://panel.kw.krakow.pl/up     # expect 200
```

Optional read-only version check: `ssh deploy@51.255.38.227 "docker ps --format '{{.Names}}'"` shows the new `kw-app-web-production-<sha>` (see the `console` skill). If the deploy fails, report the failing step and do not retry blindly; rollback is `kamal rollback -d production` and needs the owner's approval (`kamal-deployment` skill).

## Staging route (only when the owner explicitly asks)

Use this only if the owner says to go through staging (e.g. "test it on staging first"). Then `SRC` = `staging` and the PR is `staging` -> `main`:

1. Preflight: `git rev-list --left-right --count origin/staging...origin/develop` and `git log --oneline origin/staging..origin/develop`. Commits only on `develop` are not in a `staging` release. Promote them with `git push origin origin/develop:staging` (fast-forward only, never `--force`; **this deploys staging, ask first**), wait for `Test Suite` and `Deploy Staging`, then continue. If `origin/staging` does not exist, stop and tell the owner (`git push origin develop:refs/heads/staging` creates it and deploys staging).
2. Run steps 2-7 with `staging` in place of `develop` (log range, diff, CI sha, merge-tree, `--head staging`, body title `Release staging -> main`). Additionally require `Deploy Staging` `completed success` for that sha (warn and ask if it failed or is missing); with migrations, check staging is healthy on that sha.
3. A release PR from `develop` that is still open: do not reuse it; tell the owner to close it.

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `gh: command not found` / not authenticated | Tell the user to run `gh auth login`; do not paste tokens |
| `a pull request for branch "develop" into branch "main" already exists` | Reuse and refresh it (step 5) |
| `Test Suite` red on `develop` | Stop; report the failing job and log excerpt (no secrets) |
| `git merge-tree` rc != 0 | Conflicts; stop, list files, ask the user how to resolve |
| Local `develop` ahead of `origin/develop` | Those commits are not released; ask before pushing `develop` |
| Release contains only docs or comments | Still deploys (new image, no behaviour change); mention it |
