---
name: scp
description: Tworzy skrypt lokalnie, wgrywa go przez scp do `tmp/` na produkcyjnym serwerze kw-app i uruchamia. Użyj, gdy user chce "wrzucić skrypt na serwer", "scp na proda", odpalić większy skrypt Ruby/rake na produkcji z fizycznym plikiem na serwerze, albo gdy snippet jest za duży/złożony na przekazanie przez stdin.
disable-model-invocation: true
---

# scp skryptu na proda i uruchomienie (kw-app)

Buduje skrypt lokalnie, wgrywa go przez `scp` do katalogu `tmp/` na serwerze
produkcyjnym, uruchamia i sprząta. Używaj, gdy potrzebny jest realny plik na
serwerze (np. rake task, dłuższy skrypt Ruby, wieloetapowe zadanie). Do
szybkich odczytów przez stdin wystarczy skill **console**.

## Dane serwera

- Host: `51.68.141.247`
- User SSH: `deploy`
- Katalog aplikacji: `/home/deploy/kw-app/current`
- Zdalny katalog na skrypty: `/home/deploy/kw-app/current/tmp`
- Ruby: `2.6.6` przez rbenv (`/home/deploy/.rbenv`)
- Rails env: `production`

Prefiks rbenv:

```
RBENV_ROOT=/home/deploy/.rbenv RBENV_VERSION=2.6.6 /home/deploy/.rbenv/bin/rbenv exec bundle exec
```

## Procedura

1. **Napisz skrypt lokalnie** do `tmp/<opisowa_nazwa>.rb` (użyj `write_file`).
   Nadaj unikalną, opisową nazwę (np. `tmp/july_gorskie_dziki.rb`), żeby uniknąć
   kolizji.

2. **Sprawdź połączenie** (raz na sesję):

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 "echo ok"
   ```

3. **Wgraj skrypt** przez scp do zdalnego `tmp/`:

   ```
   scp -o ConnectTimeout=10 -o BatchMode=yes tmp/<opisowa_nazwa>.rb deploy@51.68.141.247:/home/deploy/kw-app/current/tmp/<opisowa_nazwa>.rb
   ```

4. **Uruchom** na serwerze przez `rails runner` (dla skryptu Ruby) — ustaw
   `timeout_ms` np. 120000:

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 "cd /home/deploy/kw-app/current && RBENV_ROOT=/home/deploy/.rbenv RBENV_VERSION=2.6.6 /home/deploy/.rbenv/bin/rbenv exec bundle exec rails runner -e production tmp/<opisowa_nazwa>.rb"
   ```

   (Jeśli skrypt to `.rake` lub jednorazowy plik wykonywalny, uruchom go
   odpowiednim poleceniem, np. `... rbenv exec bundle exec rake ...`.)

5. **Posprzątaj** plik zdalny i lokalny:

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.68.141.247 "rm -f /home/deploy/kw-app/current/tmp/<opisowa_nazwa>.rb"
   ```

   oraz usuń lokalny `tmp/<opisowa_nazwa>.rb` (`delete_path`).

## Zasady bezpieczeństwa

- **Domyślnie tylko ODCZYT.** Skrypt modyfikujący dane (`update`, `destroy`,
  `save`, `delete_all`, `update_all`, migracje) uruchamiaj **wyłącznie po
  pokazaniu userowi pełnej treści skryptu i uzyskaniu wyraźnej zgody** w tej
  samej rozmowie.
- Nie nadpisuj istniejących plików w zdalnym `tmp/` — używaj unikalnych nazw.
- Zawsze sprzątaj po sobie (zdalny i lokalny plik), chyba że user prosi, by
  zostawić.
- Nie drukuj sekretów/tokenów.
- Podaj userowi output oraz krótkie podsumowanie tego, co zrobił skrypt.
