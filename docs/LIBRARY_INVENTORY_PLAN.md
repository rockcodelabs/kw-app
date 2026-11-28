# Library Inventory (Inwentaryzacja biblioteki) Plan

Status: **APPROVED** by the user on 2026-11-25. Implementation starts next day at step 0 (see "Start here" below). Branch `develop`.

Goal: a librarian walks along the shelves with a phone and inventories every physical book (confirm the library number, photograph cover / contents / map, let AI prefill the catalog fields, print a label for new books), ending with a report of what is found, lent out, missing or new. The same catalog data powers a better member-facing search and display of the library (filters by country and book type, nice on a phone).

### Start here (handoff for the next session)

1. **Step 0, printer spike**: needs the NIIMBOT D110_M, and the label roll size (printed on the roll or box, e.g. 12x40 mm). No code.
2. **Step 1, test baseline**: factory + spec for `Library::ItemRecord`, Docker only.
3. **Step 2, migration**: needs the user's explicit go (Ask-First). Production was re-checked read-only on 2026-11-25 (see section 1, "Production check"): `reading_room` has 0 nulls, so `NOT NULL DEFAULT false` is safe. **SSH to production**: use the `ssh-access` skill (`.agents/skills/ssh-access/scripts/kw-ssh.sh prod "..."`); plain ssh fails here with "Too many authentication failures" because of the 1Password agent. Read-only commands only.
4. **Before step 3**: the user confirms or edits the fixed lists of rodzaje and kraje (4.0). **Before step 9**: the AI vendor and API key (via `bws-secrets`) and the vendor's data-use terms.

Commands: all app commands in Docker (`docker-compose exec -T app bundle exec rspec ...`, `rubocop ...`), see `docs/DEV_COMMANDS.md`. Do not commit or push without the user asking.

Related: `app/components/library/`, `.agents/skills/feature-plan`, `docs/FEATURE_WORKFLOW.md`, `.rules` sections 2-4, 8.

Legend: **[V]** verified in repo, **[R]** recommendation, **[?]** open question, **[ASK]** needs explicit approval (`.rules` section 8).

---

## 1. Current state [V]

| Area | Fact |
|------|------|
| Model | `Library::ItemRecord` (`app/components/library/item_record.rb`), table `library_items`: `title`, `description`, `attachments` (CarrierWave, JSON array), `area_id`, `doc_type` enum (`book`, `magazine`, `guide`), `item_id` (**this is the "numer biblioteczny" shown in the UI**), `number` (string, unused anywhere, 0 rows filled), `autors` (**misnamed**: the form calls it "Wydawnictwo", the show page "Wydanie", and the data in 919 of 1083 items is place and year, e.g. `Katowice 2017`, `Zakopane, 2016`, `1995`; a real publisher such as `Explo` is rare), `reading_room` (never null), `publishment_at` (date, year used), `slug` (friendly_id from title) |
| Relations | `authors` (via `item_authors`), `tags` (via `item_tags`), `library_item_reservations` (rentals; `back_at` nil = lent out). Note: reservation `item_id` points to `library_items.id`, not to the library number |
| Areas | `Library::AreaRecord` / `library_areas` exists but has no UI and no associations |
| Controllers | `Library::ItemsController` (CRUD, `index` + `show` need an active member, no `authorize!`), `AuthorsController`, `ItemReservationsController`, `Admin::TagsController`. Views are Slim with Foundation 6, in `app/components/library/*/` |
| Authorization | CanCan: role `library` has `can :manage, Library::ItemRecord` (`app/models/ability.rb`) |
| Uploads | CarrierWave 3 + `fog-openstack` (OVH cloud storage), `Library::AttachmentUploader` with a 180x180 `thumb` for images, MiniMagick. **[V] staging data**: 83 legacy files in 34 items (79 images, 4 PDFs), stored in the single `attachments` JSON column, with no per-file label or order |
| Frontend | Sprockets + CoffeeScript/jQuery (`app/assets/javascripts`), some webpack code in `app/javascript`, Foundation 6.4, `data-tokeninput` for authors, Trix for description |
| Background jobs | Sidekiq available, Redis in prod |
| AI/OCR/barcode gems | None in `Gemfile` |
| Tests | No `spec/` coverage for library at all |
| Member search today **[V]** | `Library::ItemsController#index` uses Ransack: exact library number, `title`/`description` substring (`_cont`), author name substring. Plain table (type, number, title, authors, reading room, in club, year), 20 per page, sorted by `updated_at`. **No cover photos in the list, no filters by type/tag/region/discipline/availability, no diacritic-insensitive matching** (searching `Tatry` vs `tatry` works, `Mieguszowiecki` vs `Mięguszowiecki` does not). The search field in the view posts `title_or_description_cont` even though the label says title/description/publisher |
| Member display today **[V]** | `show` page: title, number, type, reading room, publisher (`autors`), tags, authors, year, description, photo thumbnails opening a full-size reveal. Tags link to `Library::Admin::Tags` page. Not mobile-optimised |
| Search infrastructure **[V]** | `searchkick` is in the `Gemfile` but effectively unused (only a commented-out line in `mountain_route.rb`) and there is no Elasticsearch/OpenSearch in the deploy configs. PostgreSQL only has `plpgsql` enabled: no `unaccent`, no `pg_trgm` yet. Both ship with the standard Postgres image (prod and staging use PG 16) |
| Data snapshot **[V]** (staging DB, a restored copy from before the 2026-11-20 cutover, so slightly stale; counts only) | 1083 items, every one has `item_id`, 1078 distinct, range 1..1134 (so about 55 gaps). **5 duplicated numbers**: 302-305 are used by both a Tatry climbing guide (ids 290-293) and a "Polskie Himalaje" book (ids 1134-1137), and 1071 is the same title twice (ids 1032 and 1049). No unique index exists. `doc_type`: 663 book, 420 guide, 0 magazine. Only 34 items have attachments (photos). 160 are reading-room only. 50 reservations are open (lent out) |
| Production check **[V]** (live prod `51.255.38.227`, read-only counts, 2026-11-25) | **Confirms the staging snapshot.** 1096 items (664 book, 432 guide, 0 magazine), all with `item_id`, 1091 distinct, range 1..1134. The **same 5 duplicated numbers** (302, 303, 304, 305, 1071, two items each). `reading_room` nulls: 0. 34 items with attachments. `autors` filled in 924 items. 36 tags. 50 open reservations. PostgreSQL **16.16**. Extensions `unaccent` 1.1 and `pg_trgm` 1.6 are **available but not installed** (enabling them in step 12 is a plain `CREATE EXTENSION`, no image change) |
| Tags **[V]** (same snapshot) | 36 tags, 23 of them top level. A region tree already exists but is messy and bilingual: `Europa > Hiszpania` and `Europa > Spain`, `Szwecja` and `Sweden`, `Tenerife` and the typo `Tereryfa`, `Dolomites` and `Dolomity`, `Brasil` and `Brazylia`, `Germany` and `Niemcy`. Generic tags `guide` and `przewodnik` both exist. There is no discipline tag (sport climbing, ski touring...) |
| Quirks | Many item actions do `redirect_to ... unless active` without `return`; `authors_names` setter is odd. Not in scope unless we touch them |

## 2. Decisions

| # | Question | Answer | Date |
|---|----------|--------|------|
| 1 | What does "inventory" mean? | **Reconcile (B), plus new books**: most books already exist in the system. For each physical book: confirm the library number, add photos, add categorization. Books not in the system must also be addable on the spot. Climbing and ski-touring guidebooks need special categorization | 2026-11-25 |
| 2 | How structured should guidebook data be? | **Option B**: tags plus a few dedicated fields on the item (discipline, region/mountain range, country), shown for guidebooks. **Fields must be suggested and prefilled automatically from the photos** (cover / first page / table of contents), user confirms or edits | 2026-11-25 |
| 3 | External AI or self-hosted? | **External vision AI API (A)**, because the verified pricing is negligible (section 3.1). Self-hosted OCR (C) rejected as primary. ISBN barcode lookup may be added later as a free helper | 2026-11-25 |
| 4 | How does the physical book get its number? | **The app prints labels (B)**. Many books already carry a physical number (e.g. 1223), so existing numbers are authoritative and must be kept. Labels are for new books, and optionally for relabeling | 2026-11-25 |
| 5 | Flow on the phone per book? | **Number first (A)**: type the number from the spine, app opens that item, take photos, AI suggests fields and tags, user confirms. Unknown number or no label: "new book" assigns the next free number and offers a label to print. Gives a "seen on the shelf" tick per number | 2026-11-25 |
| 6 | What is stored about the inventory? | **Inventory rounds (B)**, kept simple: one named round, each check recorded in it, closing gives a report (found, missing, duplicates, newly added). **One person manages it** (role `library`), so no parallel-work complexity. Assumption **[R]**, accepted with the plan approval: books with an open reservation show as "lent out", not "missing" | 2026-11-25 |
| 7 | How are labels printed? | User owns a **NIIMBOT D110_M** label printer and wants printing automated as far as possible. D110 is named in the niimblue project topics; the exact `_M` variant is **not verified**, so a short spike (print a test label from Chrome via Web Bluetooth) comes first. Phone: the user has an **iPhone** (Safari has no Web Bluetooth), but other users may have Android, so the print path must work without browser Bluetooth | 2026-11-25 |
| 8 | Scope extension | **Members also need a good search and display page** for the library (new requirement). Depends on the inventory data (photos, disciplines, countries, tags) | 2026-11-25 |
| 9 | How do members search and what must the page offer? | **Search box plus filters on one page**. Must-have filters: **country** and **book type** (guide / book / magazine). Must look good on a **phone**. Design in 4.5, steps 12-14 | 2026-11-25 |
| 10 | Search technology? | **`pg_search` gem on PostgreSQL, no new service.** Pinned to 2.3.7 because 2.3.8+ need Ruby >= 3.3 and we run 3.2.11 (verified on rubygems.org: 2.3.7 needs Ruby >= 3.0 and ActiveRecord >= 6.1) | 2026-11-25 |
| 11 | Required catalog fields | The user's field list (section 4.0): library number, original title, Polish title, authors, edition info, reading room yes/no, publisher, guide qualification (type, country, region), description, and up to 5 scans (cover, contents, map...). **All of number, both titles, authors, publisher, guide type, country, region must be searchable** | 2026-11-25 |
| 12 | Legacy `autors` column | Evidence (staging data): it holds place and year (`Katowice 2017`), not a publisher. **[R]** treat it as "informacja o wydaniu": copy into the new `edition_info`, add a new `publisher` column, stop using `autors` in the UI, keep the old column untouched for rollback. **Confirmed by the user (A)** | 2026-11-25 |

## 3. Options considered

### 3.1 Photo -> metadata prefill: pricing check (fetched 2026-11-25 from vendor pricing pages)

Assumption **[R]**: about 3 photos per book (cover, title page, contents) = roughly 5,000 input tokens (images are about 1,500 tokens each) and about 500 output tokens of JSON. Token counts per image are my estimate, not measured; the real number comes from the first test run.

| Option | Verified price per 1M tokens (in / out) | Estimated cost per book | Per 1,000 books | Notes |
|--------|------------------------------------------|-------------------------|-----------------|-------|
| Anthropic Claude Haiku 5.5 | $0.10 / $0.50 (prompts up to 100k) | about $0.0008 | about $0.75 | Aimed at extraction and classification. Batch API is 50% cheaper |
| Anthropic Claude Sonnet 5.5 | $2 / $10 | about $0.015 | about $15 | Best quality, good as the "retry with a stronger model" fallback |
| Google Gemini 3.5 Flash-Lite | $0.30 / $2.50 (thinking tokens count as output) | about $0.003 | about $3 | Paid tier does not train on data. **Free tier does**, avoid it |
| Google Gemini 2.5 Flash-Lite | $0.10 / $0.40 | about $0.001 | about $1 | Older model, check deprecation before choosing |
| OpenAI gpt-6.2-sol | $2 / $10 | about $0.015 | about $15 | Cheaper tiers (gpt-6.1-terra, gpt-6-luna) listed only under Flex beta |
| Self-hosted OCR (Tesseract) | free | $0 | $0 | Weak on stylised covers and Polish diacritics, no semantic guess of region or discipline. Prod VPS has 2 vCPU / 3.8 GB, no GPU, so a self-hosted vision model is not realistic |

**Conclusion [R]**: even the most expensive hosted option is about $15 per 1,000 books, so cost does not justify the quality loss of self-hosting. Start with a cheap model (Haiku 5.5 or Gemini Flash-Lite) and keep the model name in config so it can be switched. Exact model IDs and the API key (stored via `bws-secrets`) are decided at implementation.

Open point **[?]**: vendor data-use terms for the chosen provider must be confirmed before go-live (Google paid vs free tier differs, confirmed on the pricing page; Anthropic and OpenAI terms not checked here).

### 3.2 Label printing with a NIIMBOT printer (researched 2026-11-25, github.com/MultiMote/niimblue and niimbluelib)

Facts **[V]** from the project READMEs:
- NIIMBOT has no official web API we can call from a Rails app. There is an open-source (MIT), reverse-engineered JS library `@mmote/niimbluelib` plus the `niim.blue` web app built on it. It talks to the printer over **Web Bluetooth** or **USB**, and states it is unaffiliated with the vendor.
- Web Bluetooth works in Chrome-based browsers (Android and desktop). **iOS Safari has no Web Bluetooth**; the README only mentions a third-party Safari extension as a workaround.
- Supported models are not guaranteed; the project keeps a community list of tested models (B1, B21, D110 are in its topics). A packet dump of the official app helps if a model fails.
- Pages must be served over HTTPS (we are).
- The `niim.blue` web app can **load a label from a URL** (`https://niim.blue/#load=<base64 gzipped label JSON>`), supports QR codes, Code 128 barcodes, CSV batch printing, and has experimental standalone Android (apk) and iOS apps. So a zero-protocol integration exists: our app builds a label link and the user taps Print in niim.blue (needs the label JSON format from the project, to verify).

Options:

| Option | How it works | Automation | Limits |
|--------|--------------|------------|--------|
| P1. Print from our page via Web Bluetooth + niimbluelib | The item screen has a "Print label" button. The page renders the label (big number + QR) to a canvas and sends it to the printer over Bluetooth. Pair once per session | High: one tap per label, no leaving the app | Android Chrome or desktop Chrome only. Not supported on iPhone Safari. Unofficial protocol, may break with firmware |
| P2. Generate a label image, share it into the official NIIMBOT app | App produces a PNG at the label size, you open it in the NIIMBOT app and print | Low: several taps per label | Works on any phone, no reverse-engineered protocol |
| P3. A4 sticker sheet PDF | Regular printer, batch of labels | Medium for batches | Needs sheets, not the printer you own |
| P4. Server-side print agent (e.g. Pi with `niimblue-node`) | Rails queues labels, a device near the printer prints them | Highest | Prod is a remote VPS and the printer is local, so this needs a new agent plus networking. Over-engineered for one person |

**Recommendation [R] (revised after the iPhone answer)**: browser Bluetooth is not usable on iPhone, and labels are only needed for new books (rarely, in small batches), so direct printing is not worth building first.

1. **Phase 1 (this plan)**: the app serves each label as a PNG at the exact pixel size of the roll (big number, optional short title; size configurable) and a "Labels to print" queue page. From there the user prints either via the official NIIMBOT app (works on iPhone and Android: download or share the PNG) or in batch on a computer through `niim.blue` (CSV batch import, QR/Code 128 supported). No reverse-engineered protocol, no new gems.
2. **Later, optional**: a "Print" button using `niimbluelib` over Web Bluetooth for Android and desktop Chrome, after the D110_M spike confirms the model works.
3. P3 (A4 sheets) and P4 (print agent) are out of scope.

QR codes are not needed in the number-first flow (the number is typed), so no QR gem is added. A QR can be added later if scanning is wanted.

### 3.3 Other design choices considered

| Topic | Chosen **[R]** | Rejected | Why |
|-------|----------------|----------|-----|
| Photos / scans | New table `library_item_scans` (`item_id`, `kind` cover / contents / map / other, `position`, `image`), at most 5 per item, own uploader with `thumb` and portrait `card` versions. Existing `attachments` stays for PDFs and other files | Reuse the single `attachments` JSON column for photos | The requirement needs labelled scans (cover, contents, map) and a limit of 5. `attachments` has no per-file label or order, so "which one is the cover" would be a fragile convention and the AI could not be told which photo is which. Reverses the earlier choice, see decision 11 |
| AI call | Synchronous request from the controller (a few seconds, spinner) | Sidekiq job + polling | One user, one book at a time. Move to a job only if requests prove slow |
| HTTP client | Faraday (already in `Gemfile.lock`) behind a small client class | Vendor SDK gem | No Gemfile change, easy to stub with WebMock (already used) |
| Tags | AI may only pick from the **existing** tag list, and may propose a new region as text for the user to approve | AI creates tags freely | The tag list is already messy (3.1 data snapshot), free creation would make it worse |
| Guide fields | `disciplines` (text array), `countries` (text array), `region` (text) on `library_items`; values for the first two come from fixed lists of **Polish names** (constants, validated on save) | Separate guide table; ISO codes; free text | Option B from decision 2. Fixed lists keep filters clean (no more Hiszpania/Spain). Storing the Polish names themselves, not codes, makes them directly searchable by `pg_search` (decision 11) with no extra mapping. A guide can cover several countries and be both climbing and ski touring, hence arrays |
| Member search | `pg_search` (`pg_search_scope`, tsearch + trigram, `ignoring: :accents`) over PostgreSQL, one query object around it | Ransack-only substrings; Elasticsearch/Searchkick; hand-written `unaccent`/`pg_trgm` SQL | No new service. The gem gives weighting, prefix match, accent folding, typo tolerance and ranking declaratively, and chains with `where`/kaminari. Searchkick is installed but unused and there is no ES in deploy |
| Inventory data | `library_inventories` + `library_inventory_checks` | Per-item stamp only | Decision 6 |

## 4. Design

### 4.0 Catalog fields (requirement of 2026-11-25) mapped to the schema

| Required field | Column / source | Today | Searchable | Notes |
|----------------|-----------------|-------|------------|-------|
| Nr książki w księgozbiorze | `item_id` | exists | yes: exact match and "jump to number" | Unique index only after the duplicate fix (step 18). The unused `number` column is left alone |
| Tytuł oryginalny | `original_title` (string) | **new** | yes | Nullable. Shown only when filled |
| Tytuł polski | `title` | exists, relabelled "Tytuł polski" | yes | Stays required, slug stays generated from it. Existing titles are mostly Polish (sampled); a foreign book without a Polish title keeps its title here until one is set |
| Autor / autorzy | `authors` (existing association) | exists | yes | Already linked for 1,022 of 1,083 items |
| Informacja o wydaniu | `edition_info` (string) | **new**, backfilled from `autors` (decision 12) | no (low value) | e.g. "Katowice 2017", "wyd. 3 popr." |
| Czytelnia TAK/NIE | `reading_room` | exists | filter | Never null today; make `NOT NULL DEFAULT false`. Displayed as TAK/NIE |
| Wydawnictwo | `publisher` (string) | **new** (`autors` is not a publisher) | yes | Filled by inventory/AI over time |
| Kwalifikacja przewodnika: rodzaj (wspinaczkowy / skiturowy / trekkingowy ...) | `disciplines` (text[]) from a fixed Polish list | **new** | yes + filter | Multi-select. Only for `doc_type = guide` |
| Kwalifikacja: kraj | `countries` (text[]) from a fixed Polish list | **new** | yes + filter | Multi-select. Only for guides |
| Kwalifikacja: region | `region` (string) | **new** | yes | e.g. "Tatry Wysokie", "Dolomity". Only for guides |
| Pole opisowe | `description` (Trix) | exists | yes (low weight) | HTML is stored; search should strip tags. Only 24 items have one today |
| Skany (do 5: okładka, spis treści, mapa...) | `library_item_scans` | **new** | no | Max 5 per item, kind per scan, at most one cover (see 4.6) |

Proposed fixed lists (to confirm): **disciplines** wspinaczkowy, skiturowy, trekkingowy, alpinistyczny, bouldering, lodowy, jaskiniowy, ferraty, rowerowy, inny. **countries** a list of about 40 mountain-relevant countries with Polish names (Polska, Słowacja, Austria, Szwajcaria, Włochy, Francja, Hiszpania, Norwegia, Nepal, ...).

### 4.1 Layers (per `.rules`)

All new code lives in `app/components/library/` (existing convention for this component), models as `*Record`, operations with dry-monads (`Dry::Monads[:result, :do]`), thin controllers, Slim + Foundation views.

| Layer | New / changed | Responsibility |
|-------|---------------|----------------|
| Models | `Library::InventoryRecord` (`library_inventories`: `name`, `state` open/closed, `started_at`, `closed_at`) | One inventory round |
| | `Library::InventoryCheckRecord` (`library_inventory_checks`: `inventory_id`, `item_id`, `checked_at`, `note`, unique `[inventory_id, item_id]`) | "Seen on the shelf" for one item in one round |
| | `Library::ItemRecord` + columns `original_title`, `edition_info`, `publisher`, `disciplines` (text[]), `countries` (text[]), `region`, `label_printed_at`; `reading_room` NOT NULL default false; `has_many :scans`; validations (disciplines and countries inside the fixed lists); scope `duplicated_numbers`; class method `next_number` | Catalog fields, guide qualification, number helpers |
| | `Library::ScanRecord` (`library_item_scans`: `item_id`, `kind` enum cover/contents/map/other, `position`, `image`); `Library::ScanUploader` | Up to 5 labelled scans per item |
| | `Library::Catalog` (constants `DISCIPLINES`, `COUNTRIES`) | Fixed Polish lists used by validations, forms, filters and the AI contract |
| Operations | `Library::Inventory::Operation::Start` / `Close` | Round lifecycle (only one open round at a time) |
| | `Library::Inventory::Operation::Check` | Number typed -> `Success(item)` and a check recorded, or `Failure(:unknown_number)` / `Failure(:ambiguous_number, candidates)` |
| | `Library::Inventory::Operation::CreateItem` | New book: takes `next_number` inside a transaction with a lock, creates the item and a check |
| | `Library::Inventory::Operation::Report` | found, not found (split into lent out / missing), duplicates, added in this round |
| | `Library::Inventory::Operation::SuggestMetadata` | Photos in, validated suggestion out (never saves) |
| Contracts | `Library::Inventory::SuggestionContract` (dry-validation) | Validates the AI JSON: Polish title, original title, authors, publisher, edition info, year, `doc_type`, disciplines and countries (must be inside `Library::Catalog` lists), region, `tag_ids` (must exist), short description, notes |
| Client | `Library::Inventory::VisionClient` (Faraday) | Only place that talks to the AI vendor; model name and key from config/ENV |
| Controllers | `Library::Admin::InventoriesController`, `Library::Admin::InventoryChecksController`, label actions on `Library::ItemsController` | Thin; `authorize! :manage, Library::ItemRecord` (role `library`) |

### 4.2 Phone flow (number first)

1. Start or resume the open round.
2. Big numeric field (`inputmode=numeric`) -> **Find**.
3. Known number: item card with current data, photo count, tags, and buttons **Mark found**, **Add photos**.
4. **Add photos**: `<input type=file accept=image/* capture=environment>` per scan slot (Okładka, Spis treści, Mapa, Inne; maximum 5 per book, shown as "3/5"). Each photo is resized, stored as a `ScanRecord` with its kind, then **Suggest** sends them to the AI together with their kinds (so it knows which one is the contents page). The suggestion pre-fills the item form (Polish and original title, authors, publisher, edition info, year, type, and for guides disciplines / countries / region / tags). The user edits and saves; nothing is saved automatically.
5. Unknown number or no label: **New book** -> app takes the next free number, same form, then the item is queued for a label.
6. Number that belongs to two items: the screen lists both so the user picks the one in hand (and the other is flagged for correction).
7. **Close round** -> report.

### 4.3 Guide categorization

- `disciplines` (multi-select, fixed Polish list from 4.0) and `countries` (multi-select, fixed Polish list), plus free-text `region` with suggestions from existing values. The whole "Kwalifikacja przewodnika" block is shown and editable only when `doc_type` is `guide`.
- Tags: the AI picks from the existing list (for example `Tatry`, `Alpy`, `Dolomity`, `przewodnik`); the optional tag cleanup step merges the bilingual duplicates first and moves the country-like tags (`Hiszpania`, `Norwegia`, ...) into `countries`.

### 4.4 Authorization, errors, safety

- Only role `library` (and `admin` if the ability already grants it) can reach inventory screens; request specs cover an unauthorized user.
- AI failure, timeout, or invalid JSON: show "could not read the photos, fill in manually", never block the check.
- The API key lives in Bitwarden Secrets (`bws-secrets` skill) and is read from ENV; photos sent are book covers only.
- No automatic data changes: every AI field is a suggestion the user confirms.
- The current `index`/`show`/`edit`/`update` actions do `redirect_to ... unless active` without `return`, so the rest of the action still runs. The rewritten member pages use one `before_action` for the active-member check instead (steps 13-14). Staff actions keep `authorize!`.

### 4.5 Member search and display (mobile first)

Audience: active club members (same access rule as today: `Membership::Activement`). Users' decision: filters by **country** and **book type** (guide, book, magazine) are a must, and the pages must be nice on a phone.

Search backend (`pg_search`, verified against its README on 2026-11-25; a small query object `Library::Search::Query` wraps it):
- `Library::ItemRecord` gets `include PgSearch::Model` and one `pg_search_scope :text_search` with weights: **A** Polish title, original title, authors' names (`associated_against: { authors: :name }`); **B** publisher, region, `countries`, `disciplines`, tag names; **C** description (HTML stripped). `using: { tsearch: { prefix: true, dictionary: 'simple' }, trigram: { only: [:title, :original_title] } }` and `ignoring: :accents`. `simple` means no Polish stemming (PostgreSQL ships none), prefix matching covers partial words, trigram covers typos in titles. **[?] to verify in step 12**: that `pg_search` can search the two text[] columns directly (it casts columns to text; not stated in the README), with a fallback of one denormalized `search_keywords` text column kept in sync on save.
- Needs two PostgreSQL extensions, both bundled with the standard Postgres image: `unaccent` (accents) and `pg_trgm` (typos). Enabled by one reversible migration `[ASK]`. Searching across associations cannot use indexes (README), which is fine for about 1,100 items, so no tsvector columns or extra indexes at first.
- A bare number in the box jumps to that library number first (plain `where(item_id: n)`, not a text search). Each field in 4.0 marked searchable is covered by the scope above or by this jump.
- With text: ordered by pg_search rank (ties by newest). Without text: the chosen sort (newest, title A-Z, year). Kaminari pagination works on the pg_search relation (README).
- Filters (combinable, plain ActiveRecord `where` chained after the search): **type** (Wszystkie / Książki / Przewodniki / Czasopisma), **country** (`countries && ARRAY[...]`, multi-select from the countries actually used), **rodzaj przewodnika** (`disciplines && ARRAY[...]`, appears when type = guide), **region** (suggestions from used values), **tag**, **czytelnia TAK/NIE**, **available now** (no open reservation). Filter state lives in the URL, so results are shareable and the back button works.
- Sort: relevance (when searching), newest, title A-Z, year.

Phone-first layout (Foundation 6, existing stack, no new JS framework):
- Sticky search field at the top; under it a horizontally scrollable row of type chips (one tap) and a **Filters** button that opens a full-height sheet (Foundation reveal) with country, rodzaj, region, tag, czytelnia, availability, and an "Apply (N results)" button. Active filters show as removable chips. Filters list only values that actually exist, so they stay short while the catalog is still being filled in.
- Results as cards: cover (the scan of kind `cover`, else the first scan, else a placeholder), Polish title with the original title in smaller text, authors, year, number badge, and badges for availability (Dostępna / Wypożyczona) and Czytelnia. 1 column on phones, 2 on tablets, 3-4 on desktop. Pagination with kaminari (already installed).
- Scans get a portrait-friendly `card` version (resize-to-limit about 400 px) because the old 180x180 `thumb` crops covers.
- Detail page: large cover with swipeable gallery of all scans (labelled Okładka / Spis treści / Mapa), facts block with every field from 4.0 (number, Polish and original title, authors, publisher, edition info, year, Czytelnia TAK/NIE, and for guides the Kwalifikacja block: rodzaj, kraje, region), tags as chips that link to the filtered list, availability, description. Staff-only actions (edit, reservations) stay below for the `library` role.
- Empty states ("no results, clear filters"), and a visible total count.

Out of scope for now: public (non-member) access, reservations by members themselves, favorites, full-text search inside the table of contents.

### 4.6 Scans (up to 5 images per book)

- Table `library_item_scans`: `item_id`, `kind` (enum `cover`, `contents`, `map`, `other`), `position`, `image` (CarrierWave on the existing OVH storage), timestamps. Validation: at most 5 per item, at most one `cover`.
- `Library::ScanUploader`: accepts images only, downsizes the stored original to about 2000 px on the long edge (phone photos are 3-5 MB), versions `thumb` (180x180 fill) and `card` (about 400 px limit).
- The same component is used by the phone flow and the admin form (5 slots with the kind chosen per slot, replace, delete, reorder).
- The old `attachments` column stays for non-image files (the 4 PDFs) and for rollback. The 79 legacy images are copied into scans by a reviewed task (step 15), originals kept until verified.

## 5. Checklist

Legend for steps: `[ASK]` = on the `.rules` Ask-First list (your "go" on that step counts as the approval, I will state it before starting). Each step ends with specs in Docker and RuboCop green, and leaves the app working.

- [ ] 0. **Printer spike** (no repo changes): print one test label on the D110_M from `niim.blue` (desktop Chrome, or the NIIMBOT app on the iPhone) to confirm the roll size and that the printer works. Result decides the label PNG size.
- [ ] 1. **Test baseline**: factory + spec for `Library::ItemRecord` (none exist today). Docker rspec.
- [ ] 2. **Migration** `[ASK]`: create `library_inventories`, `library_inventory_checks`, `library_item_scans`; add to `library_items`: `original_title`, `edition_info`, `publisher`, `disciplines` (text[]), `countries` (text[]), `region`, `label_printed_at`; set `reading_room` NOT NULL default false (0 nulls on staging, re-check on prod). Reversible, no unique index on `item_id` yet, `autors` untouched.
- [ ] 3. **Models + specs** `[ASK: touches associations/validations]`: `InventoryRecord`, `InventoryCheckRecord`, `ScanRecord` (max 5, one cover), `Library::Catalog` lists, `ItemRecord` (validations against the lists, `has_many :scans`, `duplicated_numbers`, `next_number`).
- [ ] 4. **Backfill `edition_info` from `autors`** `[ASK: production data]` (decision 12 is confirmed): reviewed task with dry-run counts, run on staging first, `autors` kept.
- [ ] 5. **Operations + specs**: `Start`, `Close`, `Check`, `CreateItem` (concurrency-safe next number), `Report`.
- [ ] 6. **Controllers + routes + request specs**: inventories and checks, `authorize!` for role `library`.
- [ ] 7. **Phone UI (without photos yet)**: round screen, number field, item card, Mark found, New book, ambiguous-number picker. Mobile-first Slim/Foundation. The photo slots are added by step 8.
- [ ] 8. **Scans upload**: `ScanUploader` (images only, downsize to about 2000 px, `thumb` and `card` versions), 5 labelled slots (Okładka / Spis treści / Mapa / Inne) with the `3/5` counter and replace/delete/reorder, used by the phone flow. Specs with fixture images, including the 6th-scan rejection.
- [ ] 9. **AI suggestion backend**: `VisionClient` (Faraday), `SuggestionContract` (all fields of 4.0), `SuggestMetadata` operation that sends scans with their kinds, WebMock specs (success, bad JSON, timeout, values outside the fixed lists, unknown tag ids). Secret via `bws-secrets` `[ASK]` (deploy/secrets config).
- [ ] 10. **Suggestion UI**: Suggest button, loading state, prefilled form with changed-field highlighting, manual fallback on failure.
- [ ] 11. **Admin item form with all catalog fields** `[ASK: changes existing form and permitted params]`: Tytuł polski, Tytuł oryginalny, Autorzy, Wydawnictwo, Informacja o wydaniu, Rok, Czytelnia TAK/NIE, Opis, the "Kwalifikacja przewodnika" block (rodzaj, kraj, region) for guides, and the scans manager. Fixes the misleading "Wydawnictwo"/"Wydanie" labels.
- [ ] 12. **Search backend with `pg_search`**: add `gem 'pg_search', '2.3.7'` `[ASK: Gemfile]`; migration `[ASK]` enabling `unaccent` and `pg_trgm`; `pg_search_scope :text_search` on `Library::ItemRecord` plus `Library::Search::Query` (text, number jump, filters, sort). Specs for diacritics (`Mieguszowiecki` finds `Mięguszowiecki`), typos, prefix, **each searchable field of 4.0** (number, both titles, authors, publisher, rodzaj, kraj, region), combined filters, ranking, pagination. First verify that `pg_search` handles the text[] columns (else the `search_keywords` fallback) and that dev Postgres (docs say 10.3) and prod/staging (16) both support the used features.
- [ ] 13. **Member list page (mobile first)**: single active-member `before_action` (fixes the missing `return`), sticky search, type chips, Filters sheet (country, rodzaj, region, tag, czytelnia, availability), removable active-filter chips, card grid with covers and badges, empty state, pagination. Request specs plus a manual phone-width check.
- [ ] 14. **Member detail page redesign**: cover + labelled gallery, facts block with every field of 4.0, tag chips linking to the filtered list, availability, staff-only actions kept for role `library`.
- [ ] 15. **Legacy images into scans** `[ASK: production data]`: copy the 79 images from `attachments` into `library_item_scans` (kind `other`, first one as fallback cover), dry-run first, originals kept; PDFs stay in `attachments`.
- [ ] 16. **Labels**: `GET /library/items/:id/label.png` at the roll size, "Labels to print" queue page, mark printed, CSV export for `niim.blue` batch. No new gems.
- [ ] 17. **Inventory report page + CSV export** (found / lent out / missing / duplicates / added this round).
- [ ] 18. **Duplicate numbers data fix** `[ASK: production data]`: resolve 302-305 and 1071 against the physical books (re-check counts on prod read-only first), then add a unique index on `library_items.item_id`.
- [ ] 19. **(Optional) Tag cleanup** `[ASK: production data]`: merge bilingual duplicates and typos (3.1), move country-like tags into `countries`, via a reviewed rake task with dry-run output.
- [ ] 20. **(Optional) Direct Bluetooth printing** for Android / desktop Chrome via `niimbluelib`, after step 0 confirms the model.
- [ ] 21. **Wrap-up**: full relevant specs, RuboCop, manual run on staging (`staging-controller-testing` skill), then release via the `release-pr` skill if you want.

## 6. Risks and open questions

- **[?]** Inventory number semantics: `item_id` is the physical number and stays authoritative. Duplicates (302-305, 1071) must be resolved against the physical books during the inventory, not silently overwritten.
- **[?]** Tag cleanup (merge English/Polish duplicates, fix typos) is needed before AI-suggested tags are useful; step 19 is optional, decide when we get there.
- **[V]** Production was re-checked on 2026-11-25 over SSH (read-only): the counts match the staging snapshot, `reading_room` has no nulls, and `unaccent` / `pg_trgm` are available on the production Postgres 16.16. Re-check counts again right before any data task (steps 4, 15, 18), because production is live.
- **[V]** Decision 12 (`autors` becomes `edition_info`) confirmed by the user.
- **[?]** Fixed lists of disciplines and countries (4.0) are proposals; the user has not answered yet. Must be confirmed or edited before step 3.
- **[?]** AI vendor, model and API key are not chosen yet, and the vendor's data-use terms are unchecked (only Google's paid vs free tier difference is known). Needed before step 9.
- **[?]** `pg_search` on text[] columns is unverified (step 12 checks it first, fallback `search_keywords`).
- **[?]** Postgres versions differ: `.rules` lists 10.3 for development while prod and staging run 16. `pg_search` features used (tsearch prefix, trigram, unaccent) exist in both, but step 12 must run its specs in the Docker dev DB and re-check on staging.
- **[?]** `pg_search` newer than 2.3.7 needs Ruby >= 3.3. Pin `2.3.7` until the Ruby upgrade, then revisit.
- **[?]** The new filters (country, rodzaj, region) only become useful as books get filled in. Until the inventory has covered most guides the member page will show few filter values; this is expected, not a bug.
- **[?]** Printer: D110_M support and the label roll size are unknown until step 0.
- **[?]** Production deploy order: migrations (steps 2, 12) and the data tasks (4, 15, 18) must run on staging first, then production through the normal release flow (`release-pr` skill); data tasks need the user's explicit go.

## 7. Change log

- 2026-11-25: doc created, current-state survey done.
- 2026-11-25: scope extended with member search and display (decisions 8-9, section 4.5). Guide `country` text field replaced by `countries` array. Checklist renumbered 0-19.
- 2026-11-25: search implemented via `pg_search` 2.3.7 instead of hand-written SQL (decision 10).
- 2026-11-25: catalog field list added (decision 11, section 4.0): new columns `original_title`, `edition_info`, `publisher`, `disciplines[]`, `countries[]`, `region`; scans moved from the `attachments` column to a new `library_item_scans` table (section 4.6); `autors` found to hold edition info (decision 12). `discipline` single value and ISO country codes replaced by arrays of Polish names. Checklist renumbered 0-21.
- 2026-11-25: plan approved by the user. Doc reviewed end to end: status set to APPROVED, "Start here" handoff added, stale step references fixed, risks consolidated, active-member `before_action` noted for the member pages.
- 2026-11-25: production SSH fixed and the read-only production check recorded in section 1. The SSH recipe now lives in the `ssh-access` skill.
