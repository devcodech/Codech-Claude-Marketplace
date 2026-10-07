# Hardening Playbook

The ordered sequence. Each step: **back up → change → verify through the public path**.
Do one at a time. If a step cannot be verified, stop and report rather than continuing.

Announce the two steps that interrupt traffic *before* running them.

---

## Step 0 — Break glass (see SKILL.md Phase 0)

Console confirmed working · admin allowlist in `before.rules` · rollback noted.

---

## Step 1 — Config as code

Put every server config in the project repo under `deploy/` and deploy with one script.
Without this, "what is actually running?" is unanswerable and rollbacks are guesswork.

```
deploy/
  <proxy>/          Caddyfile / nginx.conf, docker-compose.yml
  fail2ban/         filter.d/ action.d/ jail.d/
  ufw/              before.rules / after.rules fragments
  <app>/            pool config, scripts, crontab.txt
  sync.sh           push + validate + graceful reload
  README.md         what lives where, and the deploy traps
```

`sync.sh` must use `rsync --inplace` for single-file bind mounts (gotchas), validate before
reloading, and **never** silently recreate containers.

---

## Step 2 — Capacity (the usual root cause)

Right-size the pool to the memory limit:

```
pm.max_children ≈ (container_limit − overhead) / peak_worker_RSS
```

WordPress + Elementor peaks ~180–200 MB/worker. Measure with
`ps -o rss= -C php-fpm | sort -rn | head -1`.

Apply `templates/php-fpm/zz-pool-tuning.conf`. It also sets:

- `request_terminate_timeout` — a wedged worker must not hold its slot forever
  (one request was observed holding a slot for 6,705 seconds)
- `pm.max_requests` — recycles workers, caps leak growth
- `pm.status_path` / `ping.path` — the watchdog's input
- `slowlog` — turns "it's slow" into a stack trace

**Verify:** `docker exec <c> php-fpm -tt`, then pool memory under load stays below the cap.

Proxy-side, set a read timeout **above** `request_terminate_timeout` so php-fpm kills the
request first and the proxy returns a clean 502 instead of holding the connection.

---

## Step 3 — Observability

**Real client IPs.** Behind a CDN, configure the proxy to trust the CDN ranges and read the
real-IP header, otherwise every log line and every per-IP rule sees the CDN's edge.

```caddyfile
servers {
    trusted_proxies static __CDN_RANGES__
    client_ip_headers Cf-Connecting-Ip
}
```

**JSON access log** with ISO timestamps — fail2ban's default date detector reads them, and
`jq` makes incident analysis trivial.

**Watchdog** (`scripts/watchdog.sh`, cron every 2 min): probes a never-cached PHP path,
checks pool saturation and OOM kills, captures evidence **before** restarting, restarts at
most once per cooldown, then emails. A restart loop is an alert, not a remedy.

**Monitor** (cron every 15 min): containers up, sites responding, new/modified PHP files,
admin-user changes, core integrity, unexpected listeners, `authorized_keys` changes, disk
and backup freshness. **Email only when something is wrong**, or it becomes noise.

---

## Step 4 — fail2ban on the proxy log

Two jails (`templates/fail2ban/`):

- **flood** — >N dynamic requests/60 s → 1 h. Excludes static assets so a normal page load
  (60+ assets) is not a flood.
- **scanner** — >N 403/404 in 5 min → 24 h.

Ban **at the proxy**, not the firewall: the proxy already knows the real client IP, and a
reload is graceful. `templates/fail2ban/action.d/proxy-blocklist.conf` rewrites an include
file; `templates/caddy/blocklist.sh` regenerates it and reloads.

`ignoreip` must contain loopback, RFC1918, **the CDN ranges** and the admin IPs.

**Verify** against the real log before enabling:

```bash
fail2ban-regex /path/access.log /etc/fail2ban/filter.d/proxy-flood.conf
fail2ban-client set proxy-flood banip 203.0.113.99   # never your own IP
fail2ban-client set proxy-flood unbanip 203.0.113.99 # must shrink the list
```

---

## Step 5 — Caching

See `references/caching-and-capacity.md`. Origin page cache **and** CDN edge cache. This is
what turns "3 req/s" into "survives a campaign".

---

## Step 6 — Lock the origin to the CDN

Until this is done, every CDN rule is decorative — anyone hitting the origin IP bypasses
all of it.

**Order matters:** add the CDN allow rules **first**, then load the block. Reversed, you
black-hole all traffic.

```bash
/opt/<app>/refresh-cf-ranges.sh          # 1. allow CDN ranges (harmless alone)
cat after.rules.docker-block >> /etc/ufw/after.rules   # 2. the block
iptables-restore --test < /etc/ufw/after.rules         # 3. syntax check
ufw reload
```

Script the verification with an **automatic revert** if the public path breaks. Also move
certificate issuance to DNS-01, since port 80 is no longer open to the world.

**Verify:** direct-to-origin times out; every hostname still 200 through the CDN.

---

## Step 7 — Application hygiene (WordPress: `references/wordpress-specific.md`)

Remove abandoned plugins and vendor mu-plugins (archive first), close enumeration
endpoints, cap revisions, restore auto-updates, confirm backups land **outside the webroot**.

---

## Step 8 — Prove it

- Load test only with the user's agreement, at night, small and ramped, watched from a
  second terminal, abort on any 5xx or OOM (`references/events-and-shared-ips.md`).
- Re-run the Step 1 measurements and present before/after numbers.
- Write the runbook: symptom → command → expected output → rollback.
