---
name: codech-web-hardening
description: Harden and stabilise a live web server (WordPress/PHP behind Caddy, nginx, Apache or cPanel, usually fronted by Cloudflare) without taking it down. Use when a site is down, slow, OOM-killing, being scanned or flooded, when asked to "secure the server", "stop the attack", "fix the 502/520/timeout", "it dies under load", "prepare for an event/campaign spike", or when a security audit or remediation runbook is wanted. Covers break-glass-first safety, capacity triage (php-fpm workers vs RAM), fail2ban jails driven by the reverse proxy's own access log, locking the origin to Cloudflare, page caching, a self-healing watchdog, and the shared-IP rules that make per-IP defences dangerous during events. Also use before any load test on production.
---

# Codech Web Hardening

Make a live site survive attacks, traffic spikes and its own misconfiguration — **without
being the person who takes it down.** Every step here was paid for by a real incident on a
client server; the gotchas are the point.

**Core principle:** on production, the order of operations *is* the safety mechanism.
Break-glass before hardening, measure before changing, one change at a time, verify through
the public path. A hardening step applied in the wrong order is an outage you caused.

## When to use

- Site is down, timing out, 502/520/525, or "slow then fine then slow"
- OOM kills, php-fpm saturation, `D`-state workers, load average climbing
- Scanner/bot flood, credential stuffing, scraper eating bandwidth
- "Secure the server", security audit, remediation runbook
- Preparing for an event, campaign or launch spike (see `references/events-and-shared-ips.md`)
- **Before any load test on a production box**

## Phase 0 — Break glass FIRST (never skip)

> This phase exists because hardening a box locked a user out of their own production
> server for ~50 minutes. Do it before touching SSH, UFW or fail2ban.

1. **Confirm the provider's console works** — not "exists". Log in to the VPS/host panel's
   web console once, confirm the root password is known and accepted. If you cannot get a
   shell that way, **stop and tell the user** before any firewall change.
2. **Admin SSH allowlist in `before.rules`, not numbered rules.** UFW numbered ALLOWs get
   pushed down when fail2ban re-inserts its REJECTs at position 1. Use
   `templates/ufw/before.rules.admin-allowlist`.
3. **Record the rollback** for each change (backup path + the one command that reverts it)
   before making it.
4. **Never `fail2ban-client set <jail> banip <your-own-IP>`** to test. `ignoreip` governs
   *automatic* detection only; a manual ban bypasses it and severs your session instantly.
   Test with RFC 5737 `203.0.113.99`.

## Phase 1 — Measure before you change

Run `scripts/triage.sh` (read it first; it is read-only) or gather equivalently:

| Question | Command | What a bad answer looks like |
|---|---|---|
| Is it memory? | `free -m`, `docker stats --no-stream` | container at ~100 % of its limit |
| OOM kills? | `journalctl -k --since -1h \| grep -c oom-kill` | any non-zero on a quiet box |
| Workers wedged? | `ps aux \| grep php-fpm`, `top -bn1` | `D` state, high `%wa` (I/O wait) |
| Pool saturated? | `curl …/fpm-status?json` | `active == max_children`, `listen queue > 0` |
| Who is the traffic? | top client IPs in the proxy access log | one IP = most of your traffic |
| Is it reaching PHP? | origin `curl` vs public `curl` | origin fast, public slow → proxy/CDN layer |

**Write the numbers down before changing anything.** "It feels slow" is not a baseline, and
you will need the before/after to prove the fix.

The two root causes that account for most "the server is too small" claims:
- **php-fpm pool larger than RAM allows.** `pm.max_children × peak worker RSS` must fit the
  container/host limit with headroom. WordPress + Elementor peaks ~180–200 MB/worker.
  5 workers × 185 MB = 925 MB against a 512 MB cap → OOM loop under any concurrency.
- **A missing cache layer**, so every visitor runs PHP. See `references/caching-and-capacity.md`.

## Phase 2 — Triage order

Fix in this order; each step reduces the blast radius of the next.

1. **Capacity** (`templates/php-fpm/zz-pool-tuning.conf`) — right-size the pool, add
   `request_terminate_timeout` so a wedged worker cannot hold a slot forever, expose
   `pm.status_path` for the watchdog.
2. **Stop the bleeding** — block the specific attacker now (proxy-level `abort`, WAF rule,
   or a single firewall rule). Fast and reversible beats elegant.
3. **Observability** — proxy access log in JSON with the *real* client IP, a liveness
   watchdog, a monitor that only emails when something is wrong.
4. **Automated banning** — fail2ban jails reading the proxy log (`templates/fail2ban/`).
5. **Caching** — page cache at origin + CDN edge; this is the real capacity multiplier.
6. **Lock the origin** — CDN-only ingress, so the CDN's rules stop being decorative.
7. **Hygiene** — remove abandoned plugins/mu-plugins, close enumeration endpoints,
   cap revisions, restore auto-updates.

Details and exact commands: `references/hardening-playbook.md`.

## Phase 3 — Verify through the public path

A check against `127.0.0.1` proves the container is alive, not that the **site** works.
After every change:

```bash
curl -sI -m 20 https://<host>/            # through the CDN, as a visitor
curl -sk --resolve <host>:443:<origin-ip> https://<host>/   # origin directly
```

Both must be correct. A direct-container check hides proxy-layer breakage — a container
recreate that changes an IP leaves nginx with a stale upstream and a site-wide 502.

## Non-negotiables

- **One change at a time**, with its verification, on a live box. Batched changes make the
  failing one unidentifiable.
- **Back up to a path the webserver does not serve.** An in-webroot `security-backups/`
  directory serves your backups to the internet (confirmed with a canary file on a live site).
- **Never put secrets in the repo or in chat.** Tokens go in root-owned `0600` files on the
  server; point the user at the file, don't ask them to paste the value.
- **Per-IP defences are dangerous during events** — a venue shares one NAT IP and mobile
  carriers use CGNAT. Read `references/events-and-shared-ips.md` before a campaign.
- **Scope the allowlist to the task.** Hardcoded admin IPs in a committed config are both a
  leak and a liability; template them.

## Reference files

| File | Read when |
|---|---|
| `references/hardening-playbook.md` | Doing the work — step-by-step with commands |
| `references/gotchas.md` | **Something behaves impossibly.** Read this before debugging |
| `references/caching-and-capacity.md` | Sizing pools, page cache, CDN cache rules |
| `references/events-and-shared-ips.md` | Campaign/event spike, QR-code moment, load test |
| `references/wordpress-specific.md` | WordPress: plugins, enumeration, DB bloat, sitemaps |
| `references/audit-report.md` | Producing an audit or remediation runbook deliverable |

## Templates

Placeholders are `__UPPERCASE__`; never commit a filled-in copy containing real IPs or tokens.

| Path | Purpose |
|---|---|
| `templates/php-fpm/zz-pool-tuning.conf` | Right-sized pool + timeouts + status endpoint |
| `templates/fail2ban/filter.d/proxy-flood.conf` | Flood detection from a JSON access log |
| `templates/fail2ban/filter.d/proxy-scanner.conf` | 403/404 scanner detection |
| `templates/fail2ban/jail.d/proxy.local` | Jails with CDN + admin ignoreip |
| `templates/fail2ban/action.d/proxy-blocklist.conf` | Ban via the proxy, not the firewall |
| `templates/caddy/blocklist.sh` | Rewrites a proxy include + graceful reload |
| `templates/ufw/before.rules.admin-allowlist` | Durable admin SSH allowlist |
| `templates/ufw/after.rules.docker-block` | Make UFW actually filter Docker-published ports |
| `scripts/triage.sh` | Read-only diagnostic sweep |
| `scripts/watchdog.sh` | Self-healing liveness check with evidence capture |

## Related skills

- `superpowers:systematic-debugging` — when the cause is not yet known
- `superpowers:verification-before-completion` — before claiming anything is fixed
- `codech-project-superpower` — if the engagement needs a full document set
