---
name: console
description: Uruchamia kod Ruby na produkcyjnej konsoli Rails serwera kw-app (przez SSH + `rails runner`). Użyj, gdy user chce coś sprawdzić/policzyć w bazie produkcyjnej, "odpalić na konsoli prod", "connect to prod console" lub wykonać jednorazowy snippet Ruby/ActiveRecord na produkcji. Domyślnie TYLKO odczyt.
disable-model-invocation: true
---

# Prod Rails console (kw-app)

Odpala kod Ruby na produkcji przez SSH i `rails runner`. Terminal agenta jest
nieinteraktywny, więc **nie** otwieraj klasycznej interaktywnej konsoli
(`rails console` zawiesi się) — zamiast tego wykonuj wyrażenia przez
`rails runner` czytając skrypt ze stdin.

## Dane serwera

- Host: `51.68.141.247`
- User SSH: `deploy`
- Katalog aplikacji: `/home/deploy/kw-app/current`
- Ruby: `2.6.6` przez rbenv (`/home/deploy/.rbenv`)
- Rails env: `production` (staging i produkcja to ten sam serwer)

Prefiks rbenv do każdej komendy uruchamianej na serwerze:

```
RBENV_ROOT=/home/deploy/.rbenv RBENV_VERSION=2.6.6 /home/deploy/.rbenv/bin/rbenv exec bundle exec
```

## Procedura

1. **Najpierw sprawdź połączenie** (raz na sesję), żeby potwierdzić dostęp i env:

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 "cd /home/deploy/kw-app/current && cat REVISION 2>/dev/null; RBENV_ROOT=/home/deploy/.rbenv RBENV_VERSION=2.6.6 /home/deploy/.rbenv/bin/rbenv exec ruby -v"
   ```

2. **Krótki snippet** (jedno-/kilkuliniowy) — przekaż jako string do `-e`:

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 "cd /home/deploy/kw-app/current && RBENV_ROOT=/home/deploy/.rbenv RBENV_VERSION=2.6.6 /home/deploy/.rbenv/bin/rbenv exec bundle exec rails runner -e production -e 'puts Db::User.count'"
   ```

3. **Dłuższy skrypt** — zapisz go lokalnie do `tmp/<opisowa_nazwa>.rb`, a potem
   uruchom na prodzie czytając ze stdin (unikasz piekła cudzysłowów).
   Jeśli skrypt trzeba fizycznie wgrać na serwer, użyj skilla **scp**.

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 "cd /home/deploy/kw-app/current && RBENV_ROOT=/home/deploy/.rbenv RBENV_VERSION=2.6.6 /home/deploy/.rbenv/bin/rbenv exec bundle exec rails runner -e production -" < tmp/<opisowa_nazwa>.rb
   ```

4. **Posprzątaj** lokalny plik `tmp/*.rb`, którego użyłeś jako źródło.

## Zasady bezpieczeństwa

- **Domyślnie tylko ODCZYT** (`SELECT`, `.count`, `.where`, `puts`). Nie modyfikuj
  danych bez wyraźnej, jednoznacznej zgody usera w tej samej rozmowie.
- Zanim uruchomisz cokolwiek, co **zapisuje/usuwa** (`update`, `destroy`, `save`,
  `delete_all`, `update_all`, migracje), **pokaż userowi dokładny kod i poproś o
  potwierdzenie**. Nigdy nie zgaduj.
- Ustaw `timeout_ms` (np. 120000) dla komend `rails runner`, bo boot Railsów trwa.
- Nie loguj ani nie drukuj sekretów/tokenów (`access_token`, `encrypted_password`,
  `strava_*` itp.).
- Podawaj userowi surowy output oraz krótkie podsumowanie.
