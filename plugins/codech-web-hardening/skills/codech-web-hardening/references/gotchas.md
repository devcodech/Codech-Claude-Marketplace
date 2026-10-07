# Gotchas

Every entry cost real time on a live client server. Read this **before** debugging
something that looks impossible.

---

## Safety / lockout

### Testing a fail2ban ban locked me out of SSH

**Symptom:** session frozen immediately after `fail2ban-client set <jail> banip <my-ip>`;
new SSH connections refused. ~50 minutes of lockout on a production box.

**Cause:** `ignoreip` only governs **automatic, log-triggered** detection. A manual `banip`
bypasses it entirely and the REJECT rule lands instantly.

**Fix:** test with an RFC 5737 documentation address instead. Confirm console access first.

```bash
fail2ban-client set <jail> banip 203.0.113.99    # never your own IP
```

### Admin allowlist silently stopped working

**Symptom:** admin SSH allow rule was in UFW, yet fail2ban still locked the admin out.

**Cause:** restarting fail2ban re-inserts REJECT rules at **position 1**, pushing numbered
ALLOW rules down. Order decides.

**Fix:** put the allowlist in `/etc/ufw/before.rules` under `ufw-before-input`, always
evaluated before dynamically inserted rules. Verify by banning a test IP and confirming a
**new** session still connects.

### Unbanning from one jail did not release the IP

**Cause:** a `recidive` jail had also banned it, often with `bantime = 1w`.

**Fix:** unban from **every** jail (`fail2ban-client status` lists them). Keep `recidive`
bantime short on a box you administer.

### UFW rules did nothing to Docker-published ports

**Symptom:** `ufw deny 80` with the site still reachable from anywhere.

**Cause:** Docker publishes ports via its own iptables chains in `FORWARD`/`DOCKER-USER`,
which bypass UFW's `INPUT` chain entirely.

**Fix:** `templates/ufw/after.rules.docker-block` + `ufw route allow` rules. **Load the
allow rules first** — the block drops everything not explicitly allowed the moment it loads.

---

## Reverse proxy

### `sed -i` edited the config but the container kept the old one

**Symptom:** file on disk is correct, `caddy reload` succeeds, behaviour unchanged.

**Cause:** the config is a **single-file bind mount**. `sed -i`, plain `rsync` and
atomic-save editors write a temp file and rename it — new inode, and the container still
holds the old one.

**Fix:** write in place.

```bash
cat new.conf > /path/Caddyfile        # in place
rsync --inplace new.conf host:/path/Caddyfile
# NOT: sed -i, mv, or plain rsync
```
Directory mounts are unaffected. Same trap applies to `uploads.ini`, pool configs, any
single file mounted into a container.

### Replacing a running script produced nonsense errors

**Symptom:** `line 99: some_arg: command not found` from a cron script that was fine.

**Cause:** bash reads scripts **incrementally**. Overwriting one mid-execution (`scp`,
`cat >`) makes it execute garbage from the new byte offsets.

**Fix:** use `rsync` (temp file + atomic rename) for scripts. The opposite of the bind-mount
rule above — know which one you are touching.

### Caddy `redir` silently served a blank 200

**Symptom:** `redir /en/ permanent` returned `200` with an empty body instead of a 301.

**Cause:** Caddy parsed `/en/` as the **matcher** and `permanent` as the **target**.

**Fix:** include the matcher explicitly.

```caddyfile
redir * /en/ permanent
```

### php-fpm status endpoint returned 403 through the proxy

**Cause:** php-fpm matches `pm.status_path` / `ping.path` against `SCRIPT_NAME`, and the
proxy was sending a filesystem path.

**Fix (Caddy):**

```caddyfile
reverse_proxy php:9000 {
    transport fastcgi {
        env SCRIPT_NAME {http.request.uri.path}
        env SCRIPT_FILENAME {http.request.uri.path}
    }
}
```

### Cloudflare reported 520 while the origin was healthy

**Symptom:** 520 to the browser; origin `curl` returns 200 in milliseconds.

**Cause:** a proxy-level `abort` (fail2ban blocklist) closed the connection without a
response. **My own IP had been banned by the flood jail during a load test.**

**Fix:** check the blocklist before suspecting the origin. 52x with a healthy origin almost
always means something closed the connection deliberately.

---

## fail2ban

### The unban action failed and the blocklist never shrank

**Symptom:** `Error unbanning <ip>`; the IP stayed in the proxy include file.

**Cause:** the rebuild script ran under `set -e`, and `grep` **exits 1 when it matches
nothing** — exactly the case when unbanning the last entry.

**Fix:** `ips=$(grep -E '…' "$LIST" | sort -u || true)`

### Jails were silently missing after an "event mode" toggle

**Symptom:** `fail2ban-client status` listed only `sshd`/`recidive`; the site ran unprotected
for ~45 minutes.

**Cause:** `fail2ban-client start <jail>` does **not** work for a jail that was stopped —
the server has forgotten it.

**Fix:** restore with a full `fail2ban-client reload`, then **assert** both jails are listed.
Any script that stops jails must verify on the way back.

### The Cloudflare ban action failed from the server only

**Symptom:** `Cannot use the access token from location: 2605:…`

**Cause:** the API token was IP-filtered to the server's **IPv4** address, but the host
prefers IPv6 for outbound.

**Fix:** force IPv4 in the action — `curl -4 …` — or add the IPv6 /64 to the token filter.

---

## Caching

### The page-cache plugin cached nothing, silently

Three independent causes, all seen on one site:

1. **No `--url` in WP-CLI.** Activating/configuring via `wp` without `--url=https://host`
   never writes the per-host settings file, so the plugin no-ops. Always pass `--url`.
2. **Missing `Accept: text/html`.** Cache Enabler *bypasses* any request whose `Accept`
   header lacks `text/html` — so `curl` with its default `*/*` warms **nothing**. Warm-up
   scripts must send a browser-like `Accept`.
3. **Trailing-slash mismatch.** With no-trailing-slash permalinks the plugin refuses to
   cache URLs ending in `/` — which is exactly the language homepages (`/en/`, `/zh/`).
   Either switch permalinks (site-wide 301s — not before an event) or pre-render those
   specific pages into the cache directory on a cron.

Cache file layout is `<host><path>/https-index.html` (+ `.gz`), **not** `index.html`.

### Cloudflare Cache Rule never matched

**Symptom:** rule deployed and enabled, HTML still `cf-cache-status: DYNAMIC`.

**Cause:** expressions using `not http.cookie contains "…"` do not evaluate true when the
request carries **no Cookie header at all**, so the rule never fires.

**Fix:** express the exclusion by path instead, and let an earlier bypass rule protect admin:

```
(http.host eq "__HOST__" and http.request.method eq "GET"
 and http.request.uri.query eq ""
 and not starts_with(http.request.uri.path, "/wp-admin")
 and not starts_with(http.request.uri.path, "/wp-json")
 and not http.request.uri.path contains ".php")
```

Trade-off: logged-in editors may see cached public pages until TTL expires.

### An old Page Rule quietly overrode everything

A legacy "Cache Everything" Page Rule on one path produced `HIT` even for URLs the new Cache
Rule excluded. Page Rules evaluate **before** Cache Rules. Audit and retire them.

### Edge TTL minimum is 2 hours

The Cache Rules UI offers no 1-hour option. 2 h is fine and usually better. Browser TTL
takes a **raw value in seconds** (type `300`), and is the one cache you cannot purge — keep
it short.

---

## Monitoring

### The monitor restarted a deliberately stopped service every 15 minutes

**Cause:** the self-heal loop treats any non-running container as a fault.

**Fix:** when decommissioning, remove the service from **both** the container loop **and**
the HTTP probe list — the probe will otherwise alert on the intended 000 forever. Document
how to re-add it.

### The watchdog restarted a healthy site

**Cause:** the liveness probe accepted `200|302|404`, but `/wp-login.php` returned **301**
on a multilingual site (language prefix redirect).

**Fix:** accept any real HTTP response as "PHP is alive"; only `000`/5xx mean dead. Verify
the probe's actual status code on the target site before trusting the list.

---

## Measurement

### Front-end optimisation looked broken but wasn't

**Symptom:** 48 stylesheets, no lazy-load, slow TTFB in the browser — after optimisation.

**Cause:** the browser session was **logged in as admin**, and both the page cache and the
asset optimiser deliberately skip logged-in users. Cost time twice on the same project.

**Fix:** verify front-end optimisation with logged-out `curl` or a private window. Never the
logged-in automation session.

### `ab` reported thousands of "failed" requests that were fine

**Cause:** `Failed requests: … (Length: N)` counts **response-size variance**, normal under
concurrent compression negotiation.

**Fix:** trust `Non-2xx responses` and the server's own access log. At low concurrency the
same URL reports 0 failures.

### `information_schema.table_rows` under-reported by millions

**Cause:** it is an **estimate** for InnoDB (exact only for MyISAM). Nearly caused a
re-run of a completed 56-minute migration.

**Fix:** judge completeness with exact `COUNT(*)`.

### A "fixed" sitemap kept serving stale URLs

**Symptom:** 19 of 20 sitemap entries 404; cache/transient purges and rewrite flushes did
nothing; `lastmod` was months old.

**Cause:** the SEO plugin serves **static XML files cached on disk**
(`wp-content/uploads/<plugin>/*.xml`), not regenerated content.

**Fix:** delete the cached XML files (back them up first), then request the sitemap to force
a genuine rebuild. Verify by testing **every** entry, not the first one.

---

## Hosting-specific

### Vendor mu-plugins disabled all security auto-updates

Host-installed `mu-plugins` (e.g. `hostinger-auto-updates.php`) can disable core security
auto-updates and reroute update checks through vendor mirrors that stop working after
migration. Audit `wp-content/mu-plugins/` on any inherited site; removing them is usually
right, but get sign-off — some are load-bearing.

### A by-reference foreach broke every REST route

**Symptom:** HTTP 500 on all REST endpoints after enabling a hardening plugin.

**Cause:** `foreach ($endpoints as &$handler)` left a dangling reference that corrupted the
shared endpoints map.

**Fix:** index-based write-back. **Pre-seed a hardening plugin's options before activating
it**, so unwanted toggles never fire on a live site.

### Backups in the webroot were publicly downloadable

A `wp-content/security-backups/` directory served its contents to the internet (confirmed
with a canary). Back up to a **host path outside the webroot**, always.
