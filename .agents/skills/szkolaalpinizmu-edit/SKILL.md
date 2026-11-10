---
name: szkolaalpinizmu-edit
description: Edit text on the production WordPress site https://szkolaalpinizmu.pl (Szkola Alpinizmu KW Krakow), e.g. the "Klubowy kurs wspinaczki skalnej" page - schedules (turnusy), prices, payment info, intro text, and the accordion sections (Program kursu, Cena zawiera, Wymagania...). Use when the user wants to change, update or fix text on szkolaalpinizmu.pl.
---

# Editing szkolaalpinizmu.pl (WordPress over SSH + WP-CLI)

The site is a WordPress install on the same server as kw-app. We edit it with
WP-CLI over SSH. There are **no WP credentials in this repo** and the REST API
is read-only without auth.

## Access

- SSH: `deploy@51.68.141.247` (same as the `scp` skill).
- WP root: `/home/kwkrakow/webs/alp` (nginx site `sa`, owned by `www-data`).
- `deploy` may run WP-CLI as `www-data` without a password via
  `/etc/sudoers.d/deploy-wp`:
  `deploy ALL=(www-data) NOPASSWD: /usr/local/bin/wp`.
  Only this exact command works - always call `/usr/local/bin/wp` by full path.
- WP-CLI is old (2.3.0) on a newer PHP and prints `PHP Deprecated/Notice` noise.
  Filter it with `2>&1 | grep -v "^PHP "` (keeps real `Error:` lines).

Define this in every ssh command (each invocation is a fresh shell):

```
W="sudo -n -u www-data /usr/local/bin/wp --path=/home/kwkrakow/webs/alp"
```

Check access first (once per session):

```
ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 'sudo -n -u www-data /usr/local/bin/wp --path=/home/kwkrakow/webs/alp post get 405 --fields=ID,post_title,post_modified 2>&1 | grep -v "^PHP "'
```

If it says `a password is required`, the sudoers file is missing; tell the user
(do not try to work around it).

## Where the text lives

Page "Klubowy kurs wspinaczki skalnej" (`https://szkolaalpinizmu.pl/wspinanie/klubowy/`)
has its text in **two different places**:

| What | Where | How to edit |
|---|---|---|
| Intro, "Otwieramy zapisy" banner, Harmonogram I turnusu, II-IV turnus (accordion blocks), Platnosci, bank account | `post_content` of **page ID 405** (Gutenberg blocks) | `scripts/page.php` (get/set) |
| Sections Program kursu (0), Jak wyglada kurs? (1), Cena zawiera (2), Wymagania (3), Wyposazenie (4), Co po kursie? (5) | Easy Accordion post **ID 408** (`sp_easy_accordion`), serialized meta `sp_eap_upload_options` -> `accordion_content_source[i].accordion_content_description` | `scripts/accordion.php` |

Not editable here: the **ZAPISY table** (courses, dates, price, signups) is
rendered by PHP Everywhere code in post 408 from
`https://panel.kw.krakow.pl/api/courses.json` - that data comes from the kw-app
itself (course records), not from WordPress.

Note: the same info (dates, price 3900 zl, 2000 + 1900 split) may appear in
several places (intro, turnus blocks, accordion, ZAPISY table). When changing a
date or price, grep all of them and tell the user about any left unchanged.

## Procedure

Work in `tmp/sa/` (gitignored). Use a timestamp in file names. The `edit_file`
tool cannot see gitignored `tmp/`, so edit the `*-new.html` files with a small
`python3` script that asserts every old string occurs exactly once (or `sed`),
then review with `diff -u`.

1. **Clarify** exactly what text changes. Ask if the old text or location is
   ambiguous. Keep the existing language (Polish) and style/markup.

2. **Fetch the current raw content and back it up**:

   Page 405:
   ```
   mkdir -p tmp/sa
   ssh deploy@51.68.141.247 'sudo -n -u www-data /usr/local/bin/wp --path=/home/kwkrakow/webs/alp post get 405 --field=post_content 2>/dev/null' > tmp/sa/405-backup-<YYYYmmdd-HHMM>.html
   cp tmp/sa/405-backup-<ts>.html tmp/sa/405-new.html
   ```
   Check the file is non-empty and looks like Gutenberg HTML (`<!-- wp:` comments).

   Accordion item `<i>`:
   ```
   scp scripts/accordion.php  ->  /tmp/sa_accordion.php   (chmod 644)
   ssh ... "$W eval-file /tmp/sa_accordion.php list"
   ssh ... "$W eval-file /tmp/sa_accordion.php get <i>" > tmp/sa/acc<i>-backup-<ts>.html
   cp tmp/sa/acc<i>-backup-<ts>.html tmp/sa/acc<i>-new.html
   ```
   (`scp -o ConnectTimeout=10 -o BatchMode=yes .agents/skills/szkolaalpinizmu-edit/scripts/accordion.php deploy@51.68.141.247:/tmp/sa_accordion.php`)

3. **Edit the local `*-new.html`** with `edit_file`. Change only what was
   asked. Do not touch block comments (`<!-- wp:... -->`), classes, or other
   markup. In accordion items the content is classic HTML (`<strong>`, `<br />`,
   plain newlines), not blocks.

4. **Show the user the diff and get explicit confirmation** before writing to
   production:
   ```
   diff -u tmp/sa/405-backup-<ts>.html tmp/sa/405-new.html
   ```

5. **Write to production**:

   Page 405 (WordPress keeps a revision). **Do not use `wp post update 405 -`**:
   WP-CLI 2.3.0 ignores stdin and reports "Content, title, and excerpt are
   empty" without writing. Also, the page contains a **PHP Everywhere block**
   (the ZAPISY table), and that plugin aborts any save that is not made by an
   allowed user (administrator) - so a plain WP-CLI save, with no user, fails
   with the same message. Use `scripts/page.php` and **pass `--user=`** with an
   administrator login (currently `dariusz.finster`, WP user 16):
   ```
   scp -o ConnectTimeout=10 -o BatchMode=yes .agents/skills/szkolaalpinizmu-edit/scripts/page.php deploy@51.68.141.247:/tmp/sa_page.php
   scp -o ConnectTimeout=10 -o BatchMode=yes tmp/sa/405-new.html deploy@51.68.141.247:/tmp/sa_405_new.html
   ssh deploy@51.68.141.247 'chmod 644 /tmp/sa_page.php /tmp/sa_405_new.html; sudo -n -u www-data /usr/local/bin/wp --path=/home/kwkrakow/webs/alp --user=dariusz.finster eval-file /tmp/sa_page.php set 405 /tmp/sa_405_new.html 2>&1 | grep -v "^PHP "'
   ```
   Success looks like `Success: Updated post 405 (...), saved content matches
   the file.` If the admin user no longer exists, list admins with
   `$W user list --fields=ID,user_login,roles` and use another administrator
   (ask the user first).

   Accordion item (upload the new html, then set):
   ```
   scp tmp/sa/acc<i>-new.html deploy@51.68.141.247:/tmp/sa_acc_new.html
   ssh deploy@51.68.141.247 'chmod 644 /tmp/sa_acc_new.html; sudo -n -u www-data /usr/local/bin/wp --path=/home/kwkrakow/webs/alp eval-file /tmp/sa_accordion.php set <i> /tmp/sa_acc_new.html 2>&1 | grep -v "^PHP "'
   ```

6. **Flush the cache** (WP Super Cache is active, so visitors may otherwise
   see stale pages). There is no `wp super-cache` command on this install; call
   the plugin function:
   ```
   ssh deploy@51.68.141.247 'sudo -n -u www-data /usr/local/bin/wp --path=/home/kwkrakow/webs/alp eval "if (function_exists(\"wp_cache_clear_cache\")) { wp_cache_clear_cache(); echo \"flushed\\n\"; } else { echo \"no flush function\\n\"; }" 2>&1 | grep -v "^PHP "'
   ```
   If it prints `no flush function`, tell the user to use WP Super Cache ->
   "Delete Cache" in wp-admin.

7. **Verify** by fetching the public page and checking the new text is there
   and the old text is gone:
   ```
   curl -s "https://szkolaalpinizmu.pl/wspinanie/klubowy/?nocache=<ts>" | grep -c "<new text>"
   ```
   (or use the `fetch` tool on the page URL). Report the result. Notes:
   WordPress renders ` - ` in titles as an en dash (`&#8211;`), so grep for that
   form; `2026` will still appear in JSON-LD metadata (`dateModified`), which is
   fine. Also confirm the ZAPISY `<table` and the "Program kursu" accordion are
   still on the page.

8. **Clean up** remote temp files
   (`rm -f /tmp/sa_accordion.php /tmp/sa_acc_new.html /tmp/sa_page.php /tmp/sa_405_new.html`). Keep the local
   `tmp/sa/*-backup-*` files so the change can be rolled back, and tell the
   user where they are.

## Rollback

Page 405: upload `tmp/sa/405-backup-<ts>.html` and run `page.php set 405 <file>`
with `--user=` as in step 5 (or restore a revision from wp-admin -> page ->
Revisions).
Accordion: `... eval-file /tmp/sa_accordion.php set <i> <uploaded backup file>`.

## Rules

- Production site, public-facing, with real prices and bank details: **never
  write without showing the diff and getting a clear OK** in this conversation.
- Always back up before writing; never skip the verify step.
- Do not edit bank account numbers, prices, or dates unless the user states
  the exact new values. Never guess.
- Do not print passwords or `wp-config.php` contents. Do not run other WP-CLI
  commands that change site-wide state (plugins, users, options, db) from this
  skill.
- Do not edit the serialized meta `sp_eap_upload_options` by hand or with SQL;
  use `scripts/accordion.php`.
