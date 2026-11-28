#!/usr/bin/env bash
# kw-app SSH wrapper for the two real hosts. See ../SKILL.md.
#
#   kw-ssh.sh prod    <remote command...>   deploy@51.255.38.227  (LIVE production, read-only by default)
#   kw-ssh.sh staging <remote command...>   rege@pi5main.local    (Raspberry Pi staging)
#   kw-ssh.sh prod-opts                     print the ssh/scp/rsync options for prod (host is deploy@51.255.38.227)
#
# Why this exists: ~/.ssh/config sends every host through the 1Password agent, which offers
# many keys at once, so prod answers "Too many authentication failures" before the right key is
# tried. We pin ONE key (the PUBLIC half is enough, the private half stays in 1Password) with
# IdentitiesOnly. Only public data is written to disk. No secrets in this file.
#
# stdin is passed through, so you can do:  kw-ssh.sh prod 'docker exec -i <c> bin/rails runner -e production -' < tmp/x.rb
set -euo pipefail

# Public key authorized for deploy@51.255.38.227 (fingerprint SHA256:cVosxEGq1KeMtKf7ZFjdClkq0UNUf1SAooo1NJTX8WA).
PROD_PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSIODacfq4bX1GtRPzuDskVULAvgM5UsyY/8Z5xBV9B kw-prod-deploy (main key, private half in 1Password)'
PROD_HOST='deploy@51.255.38.227'
STAGING_HOST='rege@pi5main.local'

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

[ $# -ge 1 ] || usage
target="$1"
shift

cleanup_file=""
trap '[ -z "$cleanup_file" ] || rm -f "$cleanup_file"' EXIT

prod_key_file() {
  cleanup_file="$(mktemp "${TMPDIR:-/tmp}/kw_prod_key.XXXXXX")"
  printf '%s\n' "$PROD_PUBKEY" >"$cleanup_file"
  printf '%s' "$cleanup_file"
}

case "$target" in
  prod)
    [ $# -ge 1 ] || { echo "kw-ssh.sh prod: missing remote command" >&2; exit 2; }
    key="$(prod_key_file)"
    ssh -o IdentitiesOnly=yes -o IdentityFile="$key" -o BatchMode=yes -o ConnectTimeout=10 \
      "$PROD_HOST" "$@"
    ;;
  staging)
    [ $# -ge 1 ] || { echo "kw-ssh.sh staging: missing remote command" >&2; exit 2; }
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$STAGING_HOST" "$@"
    ;;
  prod-opts)
    # Persistent (not auto-deleted) copy so callers can reuse the options across commands.
    persistent="${TMPDIR:-/tmp}/kw_prod_key.pub"
    printf '%s\n' "$PROD_PUBKEY" >"$persistent"
    printf '%s\n' "-o IdentitiesOnly=yes -o IdentityFile=$persistent -o BatchMode=yes -o ConnectTimeout=10"
    ;;
  *)
    usage
    ;;
esac
