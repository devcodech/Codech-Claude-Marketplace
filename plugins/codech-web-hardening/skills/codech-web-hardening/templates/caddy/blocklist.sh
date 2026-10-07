#!/bin/bash
# Rewrite the proxy's banned-IP include and reload gracefully.
# Called by the fail2ban proxy-blocklist action.
#   blocklist.sh ban <ip> | unban <ip> | rebuild | list
set -euo pipefail

LIST=__BLOCKLIST_TXT__                 # plain text, one IP per line
INC=__BLOCKLIST_CADDY__                # generated include, imported by the Caddyfile
CONTAINER=__PROXY_CONTAINER__          # e.g. otso_caddy
LOG=__BLOCKLIST_LOG__

touch "$LIST"
case "${1:-}" in
  ban)     grep -qxF "$2" "$LIST" || echo "$2" >> "$LIST" ;;
  unban)   grep -vxF "$2" "$LIST" > "$LIST.tmp" || true; mv "$LIST.tmp" "$LIST" ;;
  rebuild) ;;
  list)    cat "$LIST"; exit 0 ;;
  *)       echo "usage: $0 ban <ip> | unban <ip> | rebuild | list" >&2; exit 2 ;;
esac

# Only well-formed IPv4/IPv6 reach the config: one bad token makes the proxy reject
# the whole file and the reload fails (leaving the OLD config live).
# `|| true` is REQUIRED: grep exits 1 on an EMPTY list, which under `set -e` aborts
# exactly the unban-the-last-entry path.
ips=$(grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$|^[0-9a-fA-F:]+(/[0-9]{1,3})?$' "$LIST" | sort -u | tr '\n' ' ' || true)

{
  echo "# MANAGED BY FAIL2BAN -- rewritten by $0 ($(date -u +%FT%TZ))"
  echo "# 192.0.2.1 is RFC 5737 TEST-NET-1 so the matcher is never empty."
  echo "@banned client_ip 192.0.2.1 $ips"
  echo "handle @banned {"
  printf '\tabort\n'
  echo "}"
} > "$INC.tmp"
mv "$INC.tmp" "$INC"

# Graceful: no dropped connections, every host stays up.
if docker exec "$CONTAINER" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
  echo "[$(date -u +%FT%TZ)] ${1} ${2:-} -> $(wc -w <<<"$ips") banned, proxy reloaded" >> "$LOG"
else
  echo "[$(date -u +%FT%TZ)] ${1} ${2:-} -> RELOAD FAILED (old config still live)" >> "$LOG"
  exit 1
fi
