#!/usr/bin/env bash
# Fetch the latest VERIFIED nightly dump (+ manifest) from LIVE production
# (51.68.141.247) to a private temp dir on this machine and verify it.
#
# READ-ONLY on production: only `ls`, `grep` and `scp` *from* prod are used.
# Prints the path of the verified dump on the LAST line of stdout (and nothing
# else on that line), so callers can do:  DUMP=$(fetch-latest-prod-dump.sh | tail -n1)
#
# Usage: fetch-latest-prod-dump.sh [--name kw_app_production-YYYYMMDDTHHMMSSffffffZ.sql.gz] [--max-age-hours 36]
set -euo pipefail

PROD_USER_HOST="deploy@51.68.141.247"
PROD_DUMP_DIR="/var/lib/kw-db-backup/dumps"
PROD_STATUS="/var/lib/kw-db-backup/status.json"
NAME_RE='^kw_app_production-[0-9]{8}T[0-9]{12}Z\.sql\.gz$'
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)
MAX_AGE_HOURS=36
NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --max-age-hours) MAX_AGE_HOURS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

for tool in ssh scp jq shasum gzip; do
  command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 2; }
done

log() { echo "[fetch] $*" >&2; }

# 1. Pick the dump (strict name match; never glob on the remote side).
if [ -z "$NAME" ]; then
  NAME=$(ssh "${SSH_OPTS[@]}" "$PROD_USER_HOST" "ls -1 $PROD_DUMP_DIR" | grep -E "$NAME_RE" | sort | tail -n1)
fi
[[ "$NAME" =~ $NAME_RE ]] || { echo "refusing unexpected dump name: '$NAME'" >&2; exit 1; }
log "dump: $NAME"

# 2. Backup job must report a VERIFIED local copy.
LOCAL_STATUS=$(ssh "${SSH_OPTS[@]}" "$PROD_USER_HOST" "cat $PROD_STATUS" | jq -r '.local_status')
[ "$LOCAL_STATUS" = "VERIFIED" ] || { echo "prod backup local_status is '$LOCAL_STATUS', not VERIFIED" >&2; exit 1; }
log "prod local_status: VERIFIED (offhost_status is informational)"

# 3. Private destination (umask 077, dir 0700).
umask 077
DEST=$(mktemp -d "${TMPDIR:-/tmp}/kw-prod-dump.XXXXXX")
chmod 700 "$DEST"

# 4. Copy dump + manifest from prod (source only, never write to prod).
scp -q "${SSH_OPTS[@]}" "$PROD_USER_HOST:$PROD_DUMP_DIR/$NAME" "$PROD_USER_HOST:$PROD_DUMP_DIR/$NAME.manifest.json" "$DEST/"
DUMP="$DEST/$NAME"
MANIFEST="$DEST/$NAME.manifest.json"

# 5. Verify against the manifest written by the backup job.
sha256_of() { shasum -a 256 | cut -d' ' -f1; }
size_of() { if stat -f %z "$1" >/dev/null 2>&1; then stat -f %z "$1"; else stat -c %s "$1"; fi; }

EXP_BYTES=$(jq -r .compressed_bytes "$MANIFEST")
EXP_SHA=$(jq -r .sha256 "$MANIFEST")
EXP_RAW=$(jq -r .raw_sha256 "$MANIFEST")
ACT_BYTES=$(size_of "$DUMP")
ACT_SHA=$(sha256_of < "$DUMP")
gzip -t "$DUMP"
ACT_RAW=$(gzip -dc "$DUMP" | sha256_of)

fail=0
[ "$EXP_BYTES" = "$ACT_BYTES" ] || { log "FAIL size   exp=$EXP_BYTES act=$ACT_BYTES"; fail=1; }
[ "$EXP_SHA"   = "$ACT_SHA"   ] || { log "FAIL sha256 exp=$EXP_SHA act=$ACT_SHA"; fail=1; }
[ "$EXP_RAW"   = "$ACT_RAW"   ] || { log "FAIL raw    exp=$EXP_RAW act=$ACT_RAW"; fail=1; }
[ "$fail" = 0 ] || { log "verification FAILED, removing $DEST"; rm -rf "$DEST"; exit 1; }
log "verified: size, sha256, gzip CRC and raw sha256 match manifest"

# 6. Freshness (warn only; the caller decides).
STARTED=$(jq -r .started_utc "$MANIFEST")
AGE_H=$(python3 - "$STARTED" <<'PY'
import sys, datetime
s = sys.argv[1].replace("Z", "+00:00")
t = datetime.datetime.fromisoformat(s)
print(int((datetime.datetime.now(datetime.timezone.utc) - t).total_seconds() // 3600))
PY
)
log "dump taken $STARTED UTC (${AGE_H}h ago), $(jq -r .raw_bytes "$MANIFEST") raw bytes"
if [ "$AGE_H" -gt "$MAX_AGE_HOURS" ]; then
  log "WARNING: dump is older than ${MAX_AGE_HOURS}h"
fi

echo "$DUMP"
