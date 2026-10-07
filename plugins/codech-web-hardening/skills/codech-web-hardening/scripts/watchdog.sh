#!/bin/bash
# Self-healing liveness watchdog.  Cron: */2 * * * *
#
# Detects the failure mode a container-status check CANNOT see: container "running",
# every PHP worker wedged, OOM-kill loop. Captures evidence FIRST (a restart destroys
# the state that explains the incident), restarts once per cooldown, re-probes, alerts.
# A restart LOOP is an alert, not a remedy.
set -uo pipefail

HOST=__HOST__
CONTAINER=__APP_CONTAINER__
STATE=__STATE_DIR__
INCIDENTS=__INCIDENTS_DIR__
LOG=__WATCHDOG_LOG__
ACCESS_LOG=__ACCESS_LOG__
ALERT_TO=__ALERT_EMAIL__

FAILS_BEFORE_RESTART=2   # consecutive failed probes (2 min apart => ~4 min)
SATURATION_RUNS=3        # consecutive runs with 0 idle workers AND a listen queue
OOM_SPIRAL=5             # OOM kills in the container cgroup within 5 minutes
RESTART_COOLDOWN=600
PROBE_TIMEOUT=20

mkdir -p "$STATE" "$INCIDENTS"
exec 9>"$STATE/lock"; flock -n 9 || exit 0   # never overlap with the previous run

log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
get() { cat "$STATE/$1" 2>/dev/null || echo 0; }
put() { echo "$2" > "$STATE/$1"; }

# Probe a never-cached PHP path. ANY real HTTP response means PHP is alive;
# only 000 (timeout/refused) and 5xx mean dead.
# Do NOT whitelist specific 2xx/3xx codes: on a multilingual site /wp-login.php
# answers 301 and a strict list causes false-positive restarts.
probe() {
  curl -sk -o /dev/null -m "$PROBE_TIMEOUT" -w '%{http_code}' \
       --resolve "$HOST:443:127.0.0.1" "https://$HOST/wp-login.php" 2>/dev/null || echo 000
}

code=$(probe)
case "$code" in
  000|5??) put probe_fails $(( $(get probe_fails) + 1 )) ;;
  *)       put probe_fails 0 ;;
esac

st=$(curl -sk -m 10 --resolve "$HOST:443:127.0.0.1" "https://$HOST/fpm-status?json" 2>/dev/null || true)
idle=$(jq -r '."idle processes" // empty' <<<"$st" 2>/dev/null || true)
queue=$(jq -r '."listen queue" // empty' <<<"$st" 2>/dev/null || true)
if [ "${idle:-1}" = "0" ] && [ "${queue:-0}" -gt 0 ]; then
  put saturation $(( $(get saturation) + 1 ))
else
  put saturation 0
fi

cid=$(docker inspect "$CONTAINER" --format '{{.Id}}' 2>/dev/null || echo nomatch)
oom=$(journalctl -k --since "5 minutes ago" -o cat 2>/dev/null | grep -c "oom-kill:.*${cid}" || true)

reason=""
[ "$(get probe_fails)" -ge "$FAILS_BEFORE_RESTART" ] && reason="probe failed $(get probe_fails)x (last HTTP $code)"
[ "$(get saturation)"  -ge "$SATURATION_RUNS" ]      && reason="${reason:+$reason; }pool saturated (idle=0 queue=$queue)"
[ "${oom:-0}" -ge "$OOM_SPIRAL" ]                    && reason="${reason:+$reason; }$oom OOM kills in 5 min"

if [ -z "$reason" ]; then
  log "ok http=$code idle=${idle:-?} queue=${queue:-?} oom=${oom:-0}"
  exit 0
fi

now=$(date +%s); since=$(( now - $(get last_restart) ))
if [ "$since" -lt "$RESTART_COOLDOWN" ]; then
  log "DEGRADED ($reason) -- restarted ${since}s ago, NOT restarting again; alerting"
  exit 0
fi

# Evidence BEFORE the restart.
dir="$INCIDENTS/$(date -u +%Y%m%d-%H%M%S)"; mkdir -p "$dir"
echo "$reason"                  > "$dir/reason.txt"
docker stats --no-stream        > "$dir/docker-stats.txt" 2>&1
docker top "$CONTAINER"         > "$dir/docker-top.txt"   2>&1
docker logs --since 15m "$CONTAINER" > "$dir/app.log"     2>&1
journalctl -k --since "15 minutes ago" -o short-iso > "$dir/kernel.log" 2>&1
echo "$st"                      > "$dir/fpm-status.json"
tail -n 500 "$ACCESS_LOG"       > "$dir/access-tail.jsonl" 2>/dev/null
jq -r '.request.client_ip' "$dir/access-tail.jsonl" 2>/dev/null | sort | uniq -c | sort -rn | head -10 > "$dir/top-ips.txt"

docker restart -t 10 "$CONTAINER" >> "$LOG" 2>&1
put last_restart "$now"; put probe_fails 0; put saturation 0
sleep 20
after=$(probe)
log "RESTARTED $CONTAINER -- $reason -> after=HTTP $after, evidence: $dir"

{
  echo "watchdog restarted $CONTAINER on $(hostname) at $(date -u '+%F %T UTC')"
  echo "Reason:        $reason"
  echo "After restart: HTTP $after"
  echo "Evidence:      $dir"
  echo; echo "Top client IPs (last 500 requests):"; cat "$dir/top-ips.txt"
} | mail -s "[WATCHDOG] $CONTAINER restarted: $reason" "$ALERT_TO" 2>/dev/null \
  || log "alert e-mail FAILED"
