---
name: scp
description: Tworzy skrypt lokalnie, wgrywa go przez scp na produkcyjny serwer kw-app i uruchamia w kontenerze web. Użyj, gdy user chce "wrzucić skrypt na serwer", "scp na proda", odpalić większy skrypt Ruby/rake na produkcji z fizycznym plikiem na serwerze, albo gdy snippet jest za duży/złożony na przekazanie przez stdin.
disable-model-invocation: true
---

# scp skryptu na proda i uruchomienie (kw-app)

Buduje skrypt lokalnie, wgrywa go przez `scp` na serwer produkcyjny, kopiuje do
kontenera web, uruchamia i sprząta. Używaj, gdy potrzebny jest realny plik
(np. rake task, dłuższy skrypt Ruby, wieloetapowe zadanie). Do szybkich
odczytów przez stdin wystarczy skill **console**.

> Stan na 2026-11-25: produkcja to **nowy serwer `51.255.38.227`** (cutover
> 2026-11-20). Stary `51.68.141.247` jest zamrożony i nie obsługuje już panelu.

## Dane serwera

- Host: `51.255.38.227`, user SSH: `deploy` (grupa `docker`, **bez sudo**)
- Aplikacja działa w kontenerze `kw-app-web-production-<sha>`, katalog `/rails`,
  Ruby 3.2.11 w obrazie (bez rbenv na hoście)
- Katalog na hoście na pliki tymczasowe: `/tmp` (nie ma `~/kw-app/current`)
- Rails env: `production`

Kontener web: `W=$(docker ps -q -f name=kw-app-web-production)`

## Procedura (przetestowana 2026-11-25)

1. **Napisz skrypt lokalnie** do `tmp/<opisowa_nazwa>.rb` (użyj `write_file`).
   Nadaj unikalną, opisową nazwę (np. `tmp/july_gorskie_dziki.rb`).

2. **Sprawdź połączenie** (raz na sesję):

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.255.38.227 "echo ok"
   ```

3. **Wgraj skrypt** przez scp na hosta:

   ```
   scp -o ConnectTimeout=10 -o BatchMode=yes tmp/<opisowa_nazwa>.rb deploy@51.255.38.227:/tmp/<opisowa_nazwa>.rb
   ```

4. **Skopiuj do kontenera i uruchom** (ustaw `timeout_ms` np. 120000):

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.255.38.227 'W=$(docker ps -q -f name=kw-app-web-production); docker cp /tmp/<opisowa_nazwa>.rb $W:/rails/tmp/<opisowa_nazwa>.rb && docker exec $W bin/rails runner -e production tmp/<opisowa_nazwa>.rb'
   ```

   (Dla `.rake` użyj `docker exec $W bin/rake ...`.) Pliki w kontenerze znikają
   przy następnym deployu, ale i tak je usuń.

5. **Posprzątaj** plik w kontenerze, na hoście i lokalnie:

   ```
   ssh -o ConnectTimeout=10 -o BatchMode=yes deploy@51.255.38.227 'W=$(docker ps -q -f name=kw-app-web-production); docker exec $W rm -f /rails/tmp/<opisowa_nazwa>.rb; rm -f /tmp/<opisowa_nazwa>.rb'
   ```

   oraz usuń lokalny `tmp/<opisowa_nazwa>.rb` (`delete_path`).

## Zasady bezpieczeństwa

- **Domyślnie tylko ODCZYT.** Skrypt modyfikujący dane (`update`, `destroy`,
  `save`, `delete_all`, `update_all`, migracje) uruchamiaj **wyłącznie po
  pokazaniu userowi pełnej treści skryptu i uzyskaniu wyraźnej zgody** w tej
  samej rozmowie.
- To żywa produkcja: skrypt nie może wysyłać maili ani wołać Dotpay/Strava.
- Nie nadpisuj istniejących plików w `/tmp` na hoście — używaj unikalnych nazw.
- Zawsze sprzątaj po sobie (kontener, host i plik lokalny), chyba że user prosi,
  by zostawić.
- Nie drukuj sekretów/tokenów.
- Podaj userowi output oraz krótkie podsumowanie tego, co zrobił skrypt.
