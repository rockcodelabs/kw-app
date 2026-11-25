---
name: feature-plan
description: Plan and build a kw-app feature step by step through a living doc in docs/. Interviews the user one question at a time, researches the codebase and options, proposes solutions with trade-offs, stores the agreed plan as a checklist in docs/<FEATURE>_PLAN.md, then implements one checklist step at a time with user approval before each step. Use when the user asks for a "feature plan", wants to plan a larger or vague feature before coding, or says "@feature" for something that needs research and several steps.
---

# Feature Plan (kw-app)

A living plan doc drives the whole feature: discovery -> options -> agreed checklist -> step-by-step implementation. The doc is the single source of truth and is updated after every step.

This skill extends `docs/FEATURE_WORKFLOW.md` (same rules: questions one by one, propose before coding, tests before done). Follow `.rules` for everything else (Docker for app commands, dry-monads operations, "Ask First" list, no extra documents per session).

## Hard rules

1. **One question per message.** Wait for the answer. Prefer multiple choice with a recommended option, plus "other".
2. **Research before asking.** Read the relevant code, schema, routes, abilities and existing specs first, so questions are specific and never ask what the code already answers.
3. **No code until the plan is approved.** Only the plan doc may be written during phases 1-3.
4. **One checklist step at a time.** Before each step say what it will do and wait for the user to accept ("ok", "next", "go"). Never batch several steps.
5. **One doc per feature**: `docs/<UPPER_SNAKE_FEATURE>_PLAN.md` (e.g. `docs/LIBRARY_INVENTORY_PLAN.md`). Do not create other docs.
6. Respect the `.rules` "Ask First" list (migrations, Gemfile, deploy config, git operations, changing validations/associations): the plan marks these steps `[ASK]` and the user's step approval counts as the ask, but state it explicitly.
7. Never claim a step is done without running its verification (specs in Docker, RuboCop) and seeing it pass.

## Phase 0: Kickoff

- Name the feature, pick the doc path, create the doc from the template below with status `DISCOVERY`.
- Do a quick code survey (models, controllers, views, routes, abilities, uploaders, jobs, gems) and record it under "Current state" with file paths.

## Phase 1: Discovery (questions one by one)

Typical order, skip what is already answered by code or earlier answers:

1. Goal and the real-world scenario (who, where, how often)
2. Actors and permissions (roles in `app/models/ability.rb`)
3. Device and UX constraints (phone? offline? speed per item?)
4. Data to capture and where it lives (new tables vs existing columns)
5. Integrations and external services (cost, privacy, API keys, rate limits)
6. Edge cases (duplicates, partial runs, resuming, undo, bad input)
7. Out of scope / later

After **each answer**, append it to the "Decisions" table in the doc (question, answer, date). When enough is known, post a short summary and ask "Is this understanding correct?".

## Phase 2: Options and proposal

- Research real options (codebase fit, gems, APIs, browser capabilities). When facts may be outdated, verify with `fetch` rather than relying on memory.
- Present 2-4 options in a table: what it is, pros, cons, cost, effort, risk. State a recommendation and why.
- The user picks; record the choice in "Decisions" and the rejected options with reasons in "Options considered".

## Phase 3: Plan as checklist

Write the final plan into the doc:

- Architecture (layers from `.rules`: model `app/models/db/` or the component record, operation `app/components/<ns>/operation/`, contract, thin controller, job)
- DB changes (reversible migrations)
- Ordered checklist of small steps. Each step: goal, files, tests, verification command, `[ASK]` tag if applicable. Order so every step leaves the app working and shippable (migration -> model -> operation + spec -> controller + request spec -> UI -> polish).
- Risks and open questions

Set status to `APPROVED` only after the user says yes. Checkbox format:

```
- [ ] 3. Operation `Library::Inventory::Operation::MarkSeen` + spec  [ASK: none]
```

## Phase 4: Implementation loop

For every step, in order:

1. Say which step is next and what it will touch; wait for the user's go.
2. Implement tests first where the step has logic (TDD), then code.
3. Run verification in Docker (`docker-compose exec -T app bundle exec rspec <paths>`, `rubocop <paths>`).
4. Tick the checkbox in the doc, add a one-line note (date, result, deviations), and update "Status".
5. Report briefly: what changed, what ran, what is next. Then wait.

If reality contradicts the plan, stop, explain, and propose a plan edit before continuing. Record plan changes in the "Change log".

## Phase 5: Wrap-up

Run the full relevant spec set and RuboCop, set status `DONE`, list follow-ups, and offer (do not do) a commit / PR.

## Doc template

```markdown
# <Feature name> Plan

Status: **DISCOVERY | PROPOSED | APPROVED | IN PROGRESS | DONE**. Started <YYYY-MM-DD>, branch `<branch>`.

Goal: <one or two sentences>

Related: <skills, docs, files>

Legend: **[V]** verified in repo, **[R]** recommendation, **[?]** open question, **[ASK]** needs explicit approval (`.rules` section 8).

---

## 1. Current state
<what exists today, with file paths>

## 2. Decisions
| # | Question | Answer | Date |
|---|----------|--------|------|

## 3. Options considered
<table per decision: option, pros, cons, cost, verdict>

## 4. Design
<architecture, data model, flows, authorization, error handling>

## 5. Checklist
- [ ] 1. ...

## 6. Risks and open questions

## 7. Change log
```
