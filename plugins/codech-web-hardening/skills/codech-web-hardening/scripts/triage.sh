#!/bin/bash
# READ-ONLY diagnostic sweep. Changes nothing. Run this BEFORE touching anything,
# and keep the output as the "before" baseline.
#   triage.sh <public-host> [container]
set -uo pipefail
HOST="${1:?usage: triage.sh <public-host> [container]}"
C="${2:-}"

echo "=== host ==="
nproc 2>/dev/null | xargs echo "cpus:"; free -m | sed -n 2p; uptime; df -h / | tail -1

echo; echo "=== OOM kills (24h) ==="
journalctl -k --since "24 hours ago" -o cat 2>/dev/null | grep -c oom-kill || echo 0

echo; echo "=== memory/IO pressure ==="
cat /proc/pressure/memory 2>/dev/null | head -1; cat /proc/pressure/io 2>/dev/null | head -1

echo; echo "=== containers ==="
docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null | head -10
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} cpu {{.CPUPerc}}' 2>/dev/null | head -10

echo; echo "=== top memory consumers ==="
ps aux --sort=-%mem 2>/dev/null | head -6 | awk '{printf "  %-6s %8.0fMB %s\n", $4, $6/1024, $11}'

echo; echo "=== php-fpm workers in D state (uninterruptible = wedged) ==="
ps -eo state,comm 2>/dev/null | awk '$1=="D" && $2 ~ /php-fpm/' | wc -l

echo; echo "=== public path ==="
curl -sI -m 20 "https://$HOST/" | grep -iE '^HTTP|^location|cf-cache-status|server:' | tr -d '\r' | sed 's/^/  /'

echo; echo "=== origin direct (bypass CDN) ==="
[ -n "$C" ] && docker exec "$C" sh -c "curl -sk -m 20 -o /dev/null -w '  code=%{http_code} time=%{time_total}s\n' --resolve $HOST:443:127.0.0.1 https://$HOST/" 2>/dev/null

echo; echo "=== listeners on 80/443 ==="
ss -tlnp 2>/dev/null | grep -E ':80 |:443 ' | sed 's/^/  /'

echo; echo "=== fail2ban ==="
fail2ban-client status 2>/dev/null | grep 'Jail list' | sed 's/^/  /' || echo "  not installed"

echo; echo "NEXT: identify the top client IPs in the proxy access log for the last hour."
echo "      If one IP is most of your traffic, that is the incident."
