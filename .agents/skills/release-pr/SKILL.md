---
name: release-pr
description: Checks, verifies and opens the release pull request staging -> main for kw-app (branch flow develop -> staging -> main), then returns the PR link so the owner can merge it (merging deploys to production automatically). Use when the user asks to "create PR to main", "release", "deploy to production", "prepare a release PR" or "ship staging". Never merges, never pushes to main.
allowed-tools: Read, Write, Bash
---

# Release PR: staging -> main (kw-app)

Branch flow (each branch has one meaning):

| Branch | Environment | What a push does |
|--------|-------------|------------------|
| `develop` | development / integration | Runs `Test Suite` only. **No deploy** |
| `staging` | staging (`pi5main.local`) | Runs `Test Suite` and `Deploy Staging` |
| `main` | production (`51.255.38.227`) | Merging a PR runs `Deploy Production` |

Code moves `develop` -> `staging` -> `main`. The release PR is **`staging` -> `main`**, so only code that was already deployed to staging can ship.

Merging a PR into `main` **deploys to production automatically** once the `test` job is green: the `production` Environment has no required reviewer (removed 2026-11-25), only the `main` branch restriction. So the PR link is the last human gate. Make sure what the owner is about to merge is understood, tested and conflict-free, then hand over the link.

Repo: `rockcodelabs/kw-app` (always pass `--repo rockcodelabs/kw-app` to `gh`). Production: `51.255.38.227`, `https://panel.kw.krakow.pl`. See `.rules` section 14.

`gh` prints an "upgrade available" banner on stderr; ignore it (or filter with `grep -v -i "new release\|brew upgrade\|releases/tag"`).

## Scope of a release

The release is **every commit on `origin/staging` that is not on `origin/main`** (`git log origin/main..origin/staging`), always computed fresh after `git fetch`. Not "what I worked on in this session", not the commits an older PR listed. The summary, title, risk check and CI check all cover that whole range and the exact current head of `origin/staging`.

Commits that are only on `develop` are **not** part of the release. Step 1 reports them so the owner can decide to promote them to `staging` first.

## Hard rules

1. **Never merge the PR, never push to `main`, never force-push.** Only create (or reuse) the PR and return the link.
2. Only run when the user asks for a release / PR to main.
3. Do not change code in this flow. If a check fails, report it and stop; fixing is a separate task.
4. Pushing `staging` redeploys **staging** (`Deploy Staging`). Promoting `develop` -> `staging` is a git push that deploys: **always ask first**, and only as a fast-forward (never `--force`).
5. Work from `origin/*` refs, not from the local checkout. Do not switch branches or touch the working tree.
6. Stop and report on any blocker below. Do not work around it.

## Steps

### 1. Preflight (what is where)

```bash
git fetch -q origin
git ls-remote --exit-code --heads origin staging >/dev/null || echo "NO staging branch on origin"
git rev-list --left-right --count origin/staging...origin/develop   # "<only on staging>  <only on develop>"
git --no-pager log --oneline origin/staging..origin/develop         # develop commits NOT yet on staging
```

- `origin/staging` does not exist: **stop**, tell the user to create it (`git push origin develop:refs/heads/staging`, which also deploys staging; ask first).
- `origin/staging` has commits that `origin/develop` lacks (left number > 0): report it (hotfix made on `staging`?) and continue; the release is based on `staging`.
- `origin/develop` has commits not on `staging` (right number > 0): list them and say clearly **they will NOT be in this release**. Ask whether to promote them first (`git push origin origin/develop:staging`, fast-forward only; this deploys staging, so wait for `Deploy Staging` and tests, then re-run this skill). If the push is rejected as non-fast-forward, stop and report; do not force.

### 2. What is going to production

```bash
git --no-pager log --oneline origin/main..origin/staging        # commits in the release
git --no-pager diff --stat origin/main...origin/staging | tail -n 40
git --no-pager diff --name-only origin/main...origin/staging
```

If `origin/main..origin/staging` is empty: nothing to release, say so and stop.

`main` also holds the merge commits of earlier PRs, so `staging` being "behind" `main` by those merge commits is normal. What matters is conflicts (step 4).

Flag these in the PR body and in your reply when present in the changed-file list:

| Changed path | Why it matters |
|--------------|----------------|
| `db/migrate/*`, `db/schema.rb`, `db/structure.sql` | **Migrations run on production at boot** (`db:prepare` in the image entrypoint). Confirm they are reversible, safe on live data, and were exercised on staging |
| `Gemfile`, `Gemfile.lock` | New or bumped gems; the image rebuilds |
| `config/deploy*.yml`, `.github/workflows/*`, `Dockerfile*`, `.kamal/*` | Deploy config: affects how production is deployed |
| `config/initializers/*`, `config/environments/production.rb`, `config/credentials/*.yml.enc`, `config/routes*` | Runtime behaviour on boot |
| `config/crontab`, `lib/tasks/*`, `app/jobs/*` | Cron/Sidekiq: runs unattended on production |
| `*.key`, `.env*`, anything that looks like a secret | **Stop.** Never release secrets; tell the user |

Quick secret sanity check on the diff (names only, never print matches):

```bash
git --no-pager diff origin/main...origin/staging -U0 | grep -c -i -E "(api[_-]?key|secret|password|token)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9/+_-]{16,}" || true
```

A non-zero count is a warning to look at the lines locally (`git diff ... | grep -n ...` and inspect), not proof; do not paste values into the chat.

### 3. Verify the exact commit that will ship

The release is the head of `origin/staging`:

```bash
SHA=$(git rev-parse origin/staging)
gh run list --repo rockcodelabs/kw-app --branch staging --limit 8 \
  --json workflowName,status,conclusion,headSha \
  --jq '.[] | select(.headSha=="'"$SHA"'") | [.workflowName,.status,.conclusion] | @tsv'
```

Need, **for that exact sha**:

- `Test Suite`: `completed success`. `in_progress`: wait (poll every ~60 s, up to ~10 min, or `gh run watch <id> --exit-status`), then re-check. `failure`: **stop**, report the failing job (`gh run view <id> --log-failed`), do not open the PR.
- `Deploy Staging`: `completed success`. This is the point of the `staging` branch: the code was really deployed and can be tested there. If it failed or is missing, warn the user clearly and ask whether to continue.
- No `Test Suite` run for that sha (e.g. the sha arrived by a merge that skipped CI): start one, which does not deploy anything, and wait for it:

  ```bash
  gh workflow run test.yml --repo rockcodelabs/kw-app --ref staging
  ```

  Do not run the suite on the host (rules section 5). Local Docker runs are only valid when the checkout is exactly `origin/staging`, which this flow does not switch to.

If migrations are in the diff, additionally check staging is on this sha and healthy: `curl -s -o /dev/null -w '%{http_code}\n' <staging health URL from docs/DEV_COMMANDS.md or the staging-logs-appsignal skill>`; skip if no URL is documented, and say you skipped it.

### 4. Mergeability (no conflicts)

```bash
git merge-tree --write-tree origin/main origin/staging >/dev/null 2>&1; echo "rc=$?"   # 0 = clean merge
```

Non-zero means conflicts with `main`: **stop** and report the files (`git merge-tree --write-tree --name-only origin/main origin/staging`). Resolving needs the user's decision (merging `main` into `staging` is a git operation that deploys staging: ask first).

### 5. Create or reuse the PR

Look for an existing one first:

```bash
gh pr list --repo rockcodelabs/kw-app --base main --state open --json number,url,title,headRefName
```

- An open PR into `main` from `develop` (left over from the old flow): do not reuse it. Tell the user it should be closed (`gh pr close` is theirs to run or approve) and create the `staging` one.
- None from `staging`: write the body to a temp file (avoids shell quoting problems), create the PR, delete the file.
- Exists from `staging`: **reuse it, but always refresh it** so it describes the release as it is *now*. A PR opened earlier goes stale when more commits land on `staging` (the PR follows the branch head, but title/body and the CI line do not). Compare:

  ```bash
  gh pr view <n> --repo rockcodelabs/kw-app --json headRefOid,commits --jq '{head: .headRefOid, commits: (.commits|length)}'
  git rev-parse origin/staging                       # must equal PR head
  git rev-list --count origin/main..origin/staging   # must equal PR commits count
  ```

  Then regenerate title and body from the **full** current `git log origin/main..origin/staging` (same template as below, every commit listed, CI line for the current `origin/staging` sha) and apply them, even if the old body looks "close enough":

  ```bash
  gh pr edit <n> --repo rockcodelabs/kw-app --title "<title>" --body-file tmp/release_pr_body.md
  rm -f tmp/release_pr_body.md
  ```

  This only edits PR text (no merge, no push), so it needs no extra approval. In the report say that an existing PR was refreshed and from how many to how many commits.

Write `tmp/release_pr_body.md` with `write_file`:

```markdown
## Release staging -> main

<2-4 line summary of what changed, grouped by area, from the commit list>

### Commits (<N> commits not on main)
<COMPLETE output of git log --oneline origin/main..origin/staging, one per line, as a list; never a subset, the count must match N>

### Risk check
- Migrations: <none | list, reversible?>
- Gems / deploy config / cron / initializers: <none | list>
- CI on <short sha>: Test Suite <result>, Deploy Staging <result>
- Not in this release (only on develop): <none | N commits>

### Deploy
Merging this PR **deploys to production automatically** (`Deploy Production`, after the `test` job; no approval step). Watch it: `gh run list --repo rockcodelabs/kw-app --workflow deploy-production.yml --limit 1`.
```

Title: a short imperative summary of the release (e.g. `Release: <main change>, <second change>`); for a single-commit release use that commit's subject.

```bash
gh pr create --repo rockcodelabs/kw-app --base main --head staging --title "<title>" --body-file tmp/release_pr_body.md
rm -f tmp/release_pr_body.md
```

### 6. Report back (always end with this)

Give the user, in this order:

1. **PR link** (first line, so it is easy to click).
2. What ships: 3-6 bullets, plus the commit count.
3. Verification: which sha, `Test Suite` / `Deploy Staging` results, mergeability.
4. Flags from step 2 (migrations, gems, deploy config...) or "none".
5. Commits still only on `develop` (not in this release), or "none".
6. One line: "Merging deploys to production automatically after the `test` job."

Optionally add a PR status snapshot: `gh pr view <n> --repo rockcodelabs/kw-app --json mergeable,mergeStateStatus,statusCheckRollup --jq '{mergeable, mergeStateStatus}'`. The required `test` check runs on the PR itself (`pull_request` to `main`), so `mergeStateStatus` may be `BLOCKED`/`UNSTABLE` for a couple of minutes right after creation: that is normal, say "checks are running".

## After the owner merges (only if asked to watch)

```bash
gh run list --repo rockcodelabs/kw-app --workflow deploy-production.yml --limit 1 --json databaseId,status,conclusion,headSha
gh run watch <databaseId> --repo rockcodelabs/kw-app --exit-status
curl -s -o /dev/null -w '%{http_code}\n' https://panel.kw.krakow.pl/up     # expect 200
```

Optional read-only version check: `ssh deploy@51.255.38.227 "docker ps --format '{{.Names}}'"` shows the new `kw-app-web-production-<sha>` (see the `console` skill). If the deploy fails, report the failing step and do not retry blindly; rollback is `kamal rollback -d production` and needs the owner's approval (`kamal-deployment` skill).

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `gh: command not found` / not authenticated | Tell the user to run `gh auth login`; do not paste tokens |
| `a pull request for branch "staging" into branch "main" already exists` | Reuse and refresh it (step 5) |
| `Test Suite` red on staging | Stop; report the failing job and log excerpt (no secrets) |
| `Deploy Staging` red | Warn; staging failure often means a boot/migration problem that would hit production too |
| `git merge-tree` rc != 0 | Conflicts; stop, list files, ask the user how to resolve |
| `develop` ahead of `staging` | Those commits are not released; ask whether to promote first (step 1) |
| `origin/staging` missing | Stop; the owner creates it (step 1) |
| Release contains only docs or comments | Still deploys (new image, no behaviour change); mention it |
