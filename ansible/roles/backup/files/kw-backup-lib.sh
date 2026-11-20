# shellcheck shell=bash
# Shared helpers of the kw-backup jobs (installed by Ansible role "backup" to /usr/local/lib/kw-backup/lib.sh).
# Sourced by kw-backup, kw-restore-test and kw-restic-check, which all run `set -euo pipefail`.
#
# Contract of every job:
#   * config + secrets come from the root-only env file (KW_BACKUP_ENV), never from arguments
#   * exactly one healthchecks.io ping per run: success -> /<slug>, any error -> /<slug>/fail
#   * a ping that cannot be delivered is logged but never changes the job result

: "${KW_BACKUP_ENV:=/etc/kw-backup/env}"
: "${KW_LOCK_DIR:=/run/lock}"
: "${KW_TABLE_DIGEST:=/usr/local/lib/kw-backup/table_digest.py}"
: "${HC_PING_BASE:=https://hc-ping.com}"

kw_log() { printf '%s\n' "$*" >&2; }

kw_load_env() {
  [ -r "$KW_BACKUP_ENV" ] || { kw_log "cannot read $KW_BACKUP_ENV"; exit 2; }
  set -a
  # shellcheck disable=SC1090
  . "$KW_BACKUP_ENV"
  set +a
}

# kw_ping [fail] [message]: ping body is the message, so the check log shows why a run failed.
kw_ping() {
  local suffix="${1:+/$1}"
  curl -fsS -m 15 --retry 3 -o /dev/null --data-raw "${2:-}" \
    "${HC_PING_BASE}/${HC_PING_KEY}/${KW_SLUG}${suffix}" ||
    kw_log "healthchecks ping failed (job result is unaffected)"
}

kw_finish() {
  local rc=$1
  trap - EXIT
  if declare -F kw_cleanup >/dev/null; then kw_cleanup || true; fi
  if [ "$rc" -eq 0 ]; then
    kw_log "${KW_SLUG}: ok"
    kw_ping
  else
    kw_log "${KW_SLUG}: FAILED (exit ${rc})"
    kw_ping fail "exit code ${rc}"
  fi
  exit "$rc"
}

# kw_start <healthchecks slug>: from here on the run always ends with exactly one ping.
kw_start() {
  KW_SLUG="$1"
  trap 'exit 143' TERM INT
  trap 'kw_finish $?' EXIT
}

# The three jobs share one lock: a restore test must never overlap a backup or a check.
kw_lock() {
  exec 9>"${KW_LOCK_DIR}/kw-backup.lock"
  flock -w 3600 9 || { kw_log "could not get the kw-backup lock"; exit 75; }
}

# kw_prune_local <dir> <keep-daily> <keep-weekly> <keep-monthly>
# Keeps, newest first, the latest dump of each of the N newest days / ISO weeks / months
# (same idea as restic forget). Everything else matching *.sql.gz goes, together with its .sha256.
kw_prune_local() {
  local dir=$1 keep_d=$2 keep_w=$3 keep_m=$4
  local f name day week month keep n_d=0 n_w=0 n_m=0
  local -A seen_d=() seen_w=() seen_m=()
  while IFS= read -r f; do
    name=$(basename "$f")
    if [[ ! $name =~ -([0-9]{8})T[0-9]+Z\.sql\.gz$ ]]; then
      kw_log "keeping ${name}: unexpected file name"
      continue
    fi
    day=${BASH_REMATCH[1]}
    week=$(date -u -d "$day" +%G-%V)
    month=${day:0:6}
    keep=0
    if [ -z "${seen_d[$day]:-}" ] && [ "$n_d" -lt "$keep_d" ]; then
      seen_d[$day]=1; n_d=$((n_d + 1)); keep=1
    fi
    if [ -z "${seen_w[$week]:-}" ] && [ "$n_w" -lt "$keep_w" ]; then
      seen_w[$week]=1; n_w=$((n_w + 1)); keep=1
    fi
    if [ -z "${seen_m[$month]:-}" ] && [ "$n_m" -lt "$keep_m" ]; then
      seen_m[$month]=1; n_m=$((n_m + 1)); keep=1
    fi
    if [ "$keep" -eq 0 ]; then
      rm -f -- "$f" "${f}.sha256"
      kw_log "pruned ${name}"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.sql.gz' | sort -r)
}
