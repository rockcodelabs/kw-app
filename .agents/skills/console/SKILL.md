---
name: console
description: Uruchamia kod Ruby na produkcyjnej konsoli Rails serwera kw-app (przez SSH + `docker exec ... rails runner`). Użyj, gdy user chce coś sprawdzić/policzyć w bazie produkcyjnej, "odpalić na konsoli prod", "connect to prod console" lub wykonać jednorazowy snippet Ruby/ActiveRecord na produkcji. Domyślnie TYLKO odczyt.
disable-model-invocation: true
---

# Prod Rails console (kw-app)

Odpala kod Ruby na produkcji przez SSH i `rails runner` wewnątrz kontenera web.
Terminal agenta jest nieinteraktywny, więc **nie** otwieraj klasycznej
interaktywnej konsoli (`rails console` zawiesi się) — zamiast tego wykonuj
wyrażenia przez `rails runner` czytając skrypt ze stdin.

> Stan na 2026-11-25: produkcja to **nowy serwer `51.255.38.227`** (cutover
> 2026-11-20, `panel.kw.krakow.pl` wskazuje na niego). Stary serwer
> `51.68.141.247` jest zamrożony i nie obsługuje już panelu — nie używaj go do
> sprawdzania danych aplikacji (jego baza jest nieaktualna od 2026-11-20).

## Dane serwera

- Host: `51.255.38.227` (OVH VPS, Ubuntu 26.04, Docker + Kamal)
- User SSH: `deploy` (grupa `docker`, **bez sudo**)
- Aplikacja: kontenery `kw-app-web-production-<sha>`, `kw-app-job-production-<sha>`,
  `kw-app-cron-production-<sha>`; akcesoria `kw-app-postgres` (PG 16),
  `kw-app-redis`; proxy `kamal-proxy`
- Ruby: `3.2.11` (w obrazie, żadnego rbenv na hoście), Rails env: `production`
- Katalog aplikacji w kontenerze: `/rails`

Kontener web wyznaczamy po nazwie (sha zmienia się przy każdym deployu):

```
W=$(docker ps -q -f name=kw-app-web-production)
```

Podczas deployu mogą na chwilę działać dwa kontenery web — wtedy `$W` zawiera
dwa ID. Sprawdź `docker ps` i poczekaj na koniec deployu.

## Procedura

1. **Najpierw sprawdź połączenie** (raz na sesję):

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.255.38.227 "hostname; docker ps --format '{{.Names}}\t{{.Status}}'"
   ```

2. **Krótki snippet** — przekaż przez stdin (`-i` jest wymagane, `-` = czytaj ze stdin):

   ```
   echo 'puts Db::User.count' | ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.255.38.227 'docker exec -i $(docker ps -q -f name=kw-app-web-production) bin/rails runner -e production -'
   ```

3. **Dłuższy skrypt** — zapisz go lokalnie do `tmp/<opisowa_nazwa>.rb`, a potem
   uruchom na prodzie czytając ze stdin (unikasz piekła cudzysłowów):

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.255.38.227 'docker exec -i $(docker ps -q -f name=kw-app-web-production) bin/rails runner -e production -' < tmp/<opisowa_nazwa>.rb
   ```

   Jeśli skrypt trzeba fizycznie wgrać na serwer, użyj skilla **scp**.

4. **Posprzątaj** lokalny plik `tmp/*.rb`, którego użyłeś jako źródło.

Uwagi do outputu: na początku pojawiają się linie `INFO -- : CarrierWave: ...`
(to normalne). Wyniki drukuj przez `puts`; do podsumowań można dopisać `| tail -n 30`.

Alternatywa przez Kamal z laptopa (natywny Ruby 3.2.11 przez chruby, patrz skill
`kamal-deployment`): `kamal app exec -d production --reuse "bin/rails runner '...'"`.

## Zasady bezpieczeństwa

- **Domyślnie tylko ODCZYT** (`SELECT`, `.count`, `.where`, `puts`). Nie modyfikuj
  danych bez wyraźnej, jednoznacznej zgody usera w tej samej rozmowie.
- Zanim uruchomisz cokolwiek, co **zapisuje/usuwa** (`update`, `destroy`,
  `save`, `create`, `delete_all`, `update_all`, migracje), **pokaż userowi dokładny
  kod i poproś o potwierdzenie**. Nigdy nie zgaduj. Przy zapisie owijaj w
  transakcję z `raise ActiveRecord::Rollback` do próby na sucho, a dopiero potem
  uruchom właściwy zapis.
- To jest **żywa produkcja** z prawdziwymi danymi i mailami: nie wywołuj kodu,
  który wysyła maile/powiadomienia (`deliver_now`, joby mailerów) ani woła
  Dotpay/Strava.
- Ustaw `timeout_ms` (np. 120000) dla komend `rails runner`, bo boot Railsów trwa.
- Nie loguj ani nie drukuj sekretów/tokenów (`access_token`, `encrypted_password`,
  `strava_*` itp.).
- Podawaj userowi surowy output oraz krótkie podsumowanie.
