#!/usr/bin/env bash
# Restore a verified kw-app prod dump onto a target Postgres (staging now, new prod later), 1:1.
#
#   restore.sh [-t staging|new-prod] <command> [options]
#
# Commands (run in this order):
#   preflight   <dump>                 check dump, ssh, container, disk, roles; changes nothing
#   restore     <dump> [--db NAME]     create a NEW scratch DB and load the dump into it (live DB untouched)
#   verify      <dump> --db NAME [--after-migrate]   rows + content digest + sequences + structure vs the dump
#   migrate     --db NAME              rehearse `db:migrate` on the scratch DB using the running web image
#   swap        --db NAME --yes [--ack-mail-risk] [--no-stop-app] [--live-db NAME]
#                                      stop web, rename live -> <live>_prev_<ts>, NAME -> live, start web
#   rollback    --prev NAME --yes [--no-stop-app] [--live-db NAME]
#                                      undo a swap: current live -> <live>_failed_<ts>, NAME -> live
#   drop        --db NAME --yes        drop a scratch/_prev/_failed DB (never the live DB)
#   list                               list databases on the target
#
# Every command prints names, counts and statuses only - never row data.
# The dump is expected to come from .agents/skills/scp-transfer/scripts/fetch-latest-prod-dump.sh (already verified).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=staging
if [ "${1:-}" = "-t" ]; then TARGET="${2:?target}"; shift 2; fi
CMD="${1:-}"; [ -n "$CMD" ] || { sed -n '2,22p' "$0" >&2; exit 2; }
shift

PROFILE="$HERE/profiles/$TARGET.env"
[ -f "$PROFILE" ] || { echo "unknown target '$TARGET' (no $PROFILE)" >&2; exit 2; }
# shellcheck disable=SC1090
. "$PROFILE"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)
DUMP_RE='^kw_app_production-[0-9]{8}T[0-9]{12}Z\.sql\.gz$'
DB_RE='^[a-z][a-z0-9_]{0,62}$'

log()  { echo "[$TARGET] $*" >&2; }
die()  { echo "[$TARGET] ERROR: $*" >&2; exit 1; }
rssh() { ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "$@"; }

# psql inside the PG container. $1 = database. SQL on stdin.
pg() { local db="$1"; shift; rssh "docker exec -i $PG_CONTAINER psql -U $PG_USER -d $db -X -q -At -v ON_ERROR_STOP=1 $*"; }
pgq() { printf '%s\n' "$1" | pg "${2:-postgres}"; }   # pgq "SQL" [db]

need_db()  { [[ "${1:-}" =~ $DB_RE ]] || die "bad or missing --db (must match $DB_RE)"; }
need_yes() { [ "${YES:-0}" = 1 ] || die "refusing without --yes. Get the user's explicit confirmation first."; }
db_exists() { [ "$(pgq "select 1 from pg_database where datname='$1'")" = 1 ]; }
check_dump() {
  [ -f "$1" ] || die "dump not found: $1"
  [[ "$(basename "$1")" =~ $DUMP_RE ]] || die "dump name does not match $DUMP_RE"
  gzip -t "$1" || die "gzip integrity check failed"
}
web_container() {
  local n; n="$(rssh "docker ps --filter name=$WEB_FILTER --format '{{.Names}}'")"
  [ "$(printf '%s\n' "$n" | grep -c .)" = 1 ] || die "expected exactly one running web container matching '$WEB_FILTER', got: ${n:-none}"
  printf '%s' "$n"
}
live_guard() { [ "$1" != "$LIVE_DB" ] || die "refusing to operate on the live DB ($LIVE_DB) with this command"; }

# ---- option parsing (after the command) -------------------------------------
DB=""; PREV=""; YES=0; ACK_MAIL=0; STOP_APP=1; AFTER_MIGRATE=0; DUMP=""; OWNER_FIX=1
while [ $# -gt 0 ]; do
  case "$1" in
    --db) DB="${2:-}"; shift 2;;
    --prev) PREV="${2:-}"; shift 2;;
    --live-db) LIVE_DB="${2:-}"; shift 2;;
    --yes) YES=1; shift;;
    --ack-mail-risk) ACK_MAIL=1; shift;;
    --no-stop-app) STOP_APP=0; shift;;
    --after-migrate) AFTER_MIGRATE=1; shift;;
    --keep-owner) OWNER_FIX=0; shift;;
    -*) die "unknown option $1";;
    *) DUMP="$1"; shift;;
  esac
done

case "$CMD" in
  list)
    pgq "select datname||'  '||pg_size_pretty(pg_database_size(datname)) from pg_database where datname not in ('template0','template1') order by 1"
    ;;

  preflight)
    check_dump "$DUMP"
    rssh true || die "ssh to $SSH_TARGET failed"
    ver="$(pgq 'show server_version')"; log "postgres $ver, container $PG_CONTAINER"
    log "live DB $LIVE_DB: $(pgq "select pg_size_pretty(pg_database_size('$LIVE_DB'))") (exists: $(db_exists "$LIVE_DB" && echo yes || echo NO))"
    log "role 'deploy' (owner of every object in the dump): $(pgq "select count(*) from pg_roles where rolname='deploy'") (0 = will be created NOLOGIN by restore)"
    log "disk free for PG data: $(rssh "docker exec $PG_CONTAINER df -h /var/lib/postgresql/data | tail -n1 | awk '{print \$4}'")"
    log "web container: $(web_container)"
    [ "${MAIL_GATE:-0}" = 1 ] && log "WARNING: this target sends real mail; 1:1 data has real member e-mails. swap needs --ack-mail-risk."
    log "preflight ok"
    ;;

  restore)
    check_dump "$DUMP"
    DB="${DB:-kw_restore_$(date +%Y%m%d%H%M%S)}"; need_db "$DB"; live_guard "$DB"
    db_exists "$DB" && die "database $DB already exists"
    if [ "$(pgq "select count(*) from pg_roles where rolname='deploy'")" = 0 ]; then
      log "creating NOLOGIN role 'deploy' (dump objects are OWNER TO deploy)"
      pgq "CREATE ROLE deploy NOLOGIN"
    fi
    log "creating database $DB (same encoding/locale as the live DB)"
    enc="$(pgq "select pg_encoding_to_char(encoding)||'|'||datcollate||'|'||datctype from pg_database where datname='$LIVE_DB'")"
    IFS='|' read -r e c t <<<"$enc"
    pgq "CREATE DATABASE $DB ENCODING '$e' LC_COLLATE '$c' LC_CTYPE '$t' TEMPLATE template0"
    log "loading dump into $DB (single transaction, stops on first error)"
    start=$(date +%s)
    if ! gzip -dc "$DUMP" | rssh "docker exec -i $PG_CONTAINER psql -U $PG_USER -d $DB -X -q -At -o /dev/null -v ON_ERROR_STOP=1 --single-transaction"; then
      log "load FAILED - dropping $DB"; pgq "DROP DATABASE IF EXISTS $DB" || true; exit 1
    fi
    log "loaded in $(( $(date +%s) - start ))s"
    if [ "$OWNER_FIX" = 1 ]; then
      log "reassigning objects owned by 'deploy' to $PG_USER (ownership only; use --keep-owner to skip)"
      pgq "REASSIGN OWNED BY deploy TO $PG_USER" "$DB"
    fi
    log "tables: $(pgq "select count(*) from pg_tables where schemaname='public'" "$DB")  size: $(pgq "select pg_size_pretty(pg_database_size('$DB'))")"
    echo "$DB"
    ;;

  verify)
    check_dump "$DUMP"; need_db "$DB"; db_exists "$DB" || die "database $DB does not exist"
    extra=(); [ "$AFTER_MIGRATE" = 1 ] && extra+=(--after-migrate)
    python3 "$HERE/table_digest.py" verify "$DUMP" ${extra[@]+"${extra[@]}"} \
      --psql "ssh ${SSH_OPTS[*]} $SSH_TARGET docker exec -i $PG_CONTAINER psql -U $PG_USER -d $DB -X -q -At"
    ;;

  migrate)
    need_db "$DB"; live_guard "$DB"; db_exists "$DB" || die "database $DB does not exist"
    [ -n "${DB_NAME_ENV:-}" ] || die "target $TARGET has no DB_NAME_ENV; cannot rehearse migrations (they run at web boot via db:prepare)"
    W="$(web_container)"
    log "pending migrations on $DB (via $W, scratch DB only):"
    rssh "docker exec -e $DB_NAME_ENV=$DB -e APPSIGNAL_ACTIVE=false $W bin/rails db:migrate:status" | grep -E '^[[:space:]]+down' || log "none"
    log "running db:migrate on $DB"
    rssh "docker exec -e $DB_NAME_ENV=$DB -e APPSIGNAL_ACTIVE=false $W bin/rails db:migrate" 2>&1 | grep -E '^(==|rails aborted|ActiveRecord::|PG::)' || true
    left="$(rssh "docker exec -e $DB_NAME_ENV=$DB -e APPSIGNAL_ACTIVE=false $W bin/rails db:migrate:status" | grep -cE '^[[:space:]]+down' || true)"
    [ "$left" = 0 ] || die "$left migrations still down after db:migrate"
    log "all repo migrations are up on $DB"
    ;;

  swap)
    need_db "$DB"; need_yes
    if [ "${MAIL_GATE:-0}" = 1 ] && [ "$ACK_MAIL" != 1 ]; then
      die "$TARGET sends real mail and this DB holds real member e-mails. Make sure mail is sandboxed/disabled, then pass --ack-mail-risk."
    fi
    db_exists "$DB" || die "database $DB does not exist"; db_exists "$LIVE_DB" || die "live DB $LIVE_DB does not exist"
    [ "$DB" != "$LIVE_DB" ] || die "--db is the live DB"
    PREV="${LIVE_DB}_prev_$(date +%Y%m%d%H%M%S)"
    W=""; if [ "$STOP_APP" = 1 ]; then W="$(web_container)"; log "stopping $W"; rssh "docker stop $W" >/dev/null; fi
    # from here on, make sure the app is started again whatever happens
    restart() { if [ -n "$W" ]; then log "starting $W"; rssh "docker start $W" >/dev/null; fi; }
    trap restart EXIT
    log "terminating remaining sessions on $LIVE_DB and $DB"
    pgq "select pg_terminate_backend(pid) from pg_stat_activity where datname in ('$LIVE_DB','$DB') and pid <> pg_backend_pid()" >/dev/null
    log "rename $LIVE_DB -> $PREV"
    pgq "ALTER DATABASE $LIVE_DB RENAME TO $PREV"
    log "rename $DB -> $LIVE_DB"
    if ! pgq "ALTER DATABASE $DB RENAME TO $LIVE_DB"; then
      log "second rename failed - restoring the original name"; pgq "ALTER DATABASE $PREV RENAME TO $LIVE_DB"; exit 1
    fi
    log "swapped. previous live DB kept as: $PREV"
    if [ -n "$W" ]; then
      trap - EXIT; restart
      log "waiting for the app to answer /up (db:prepare runs pending migrations on boot)"
      for i in $(seq 1 60); do
        code="$(rssh "docker exec $W curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/up" 2>/dev/null || true)"
        [ "$code" = 200 ] && { log "app healthy after ~$((i*3))s"; break; }
        sleep 3
        [ "$i" = 60 ] && { log "app did NOT become healthy in 180s - inspect logs; rollback: rollback --prev $PREV --yes"; exit 1; }
      done
    fi
    echo "$PREV"
    ;;

  rollback)
    need_db "$PREV"; need_yes
    db_exists "$PREV" || die "database $PREV does not exist"
    FAILED="${LIVE_DB}_failed_$(date +%Y%m%d%H%M%S)"
    W=""; if [ "$STOP_APP" = 1 ]; then W="$(web_container)"; log "stopping $W"; rssh "docker stop $W" >/dev/null; fi
    pgq "select pg_terminate_backend(pid) from pg_stat_activity where datname in ('$LIVE_DB','$PREV') and pid <> pg_backend_pid()" >/dev/null
    pgq "ALTER DATABASE $LIVE_DB RENAME TO $FAILED"
    pgq "ALTER DATABASE $PREV RENAME TO $LIVE_DB"
    [ -n "$W" ] && { log "starting $W"; rssh "docker start $W" >/dev/null; }
    log "rolled back. the DB that was live is kept as: $FAILED"
    echo "$FAILED"
    ;;

  drop)
    need_db "$DB"; need_yes; live_guard "$DB"
    [[ "$DB" == kw_restore_* || "$DB" == *_prev_* || "$DB" == *_failed_* || "$DB" == kw_swap_test_* ]] \
      || die "drop only handles kw_restore_*, *_prev_*, *_failed_* databases"
    pgq "select pg_terminate_backend(pid) from pg_stat_activity where datname='$DB' and pid <> pg_backend_pid()" >/dev/null
    pgq "DROP DATABASE IF EXISTS $DB"
    log "dropped $DB"
    ;;

  *) die "unknown command '$CMD'";;
esac
