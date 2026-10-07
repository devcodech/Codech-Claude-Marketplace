# Caching and Capacity

Capacity work is mostly **keeping PHP out of the request path**. A bigger server buys a
linear improvement; a cache buys two orders of magnitude.

Measured on a 2 vCPU / 1.9 GB VPS: `/en/` **440 ms → 3 ms**, a heavy translated page
**6.6 s → 3 ms**. Same hardware.

---

## 1. Size the pool to the memory limit

```
pm.max_children ≈ (limit − overhead) / peak_worker_RSS
```

Measure, don't assume: `ps -o rss= -C php-fpm | sort -rn | head -1`.

WordPress + Elementor peaks ~180–200 MB/worker, so a 512 MB container supports **3**, not
the image default of 5. Oversizing does not degrade — it **OOM-loops**, which looks like
"the server is too small" and is not.

Always set:

| Directive | Why |
|---|---|
| `request_terminate_timeout = 60s` | A wedged worker must release its slot |
| `pm.max_requests = 200` | Recycles workers; caps leak growth |
| `pm.status_path` / `ping.path` | Watchdog input |
| `slowlog` + `request_slowlog_timeout` | Turns "slow" into a stack trace |

The proxy's read timeout must sit **above** `request_terminate_timeout`.

---

## 2. Database before caching

A cache hides a slow query; it does not fix one. Check first:

- **InnoDB buffer pool** — 128 MB on a 7.5 GB box made one query take 8,690 ms that took
  40 ms elsewhere. Size it to the working set.
- **MyISAM tables** take table-level write locks. Converting hot counter tables to InnoDB
  with a covering index took a tracked write from 489 ms to 160 ms.
- **OPcache** — verify it is actually installed. Adding it cut admin bootstrap 2.2 s → 0.21 s.
- **Revision bloat** — 19,997 Elementor revisions carrying 1.8 GB of postmeta made a 53-post
  site a 3.1 GB database. Delete old revisions (keep ~5/post), `OPTIMIZE`, then cap:
  ```php
  define( 'WP_POST_REVISIONS', 5 );
  ```
  Measured result: **3.1 GB → 506 MB**. Delete in batches on a live DB; MariaDB rejects
  `DELETE … JOIN … LIMIT`, so use `DELETE FROM t WHERE id IN (SELECT …) LIMIT n`.

---

## 3. Origin page cache

Static HTML served by the web server, PHP never invoked. With Caddy + Cache Enabler:

```caddyfile
@cacheable {
    method GET HEAD
    path */
    not header_regexp Cookie (wordpress_logged_in_|wp-postpass_|comment_author_)
    expression {http.request.uri.query} == ""
    file /wp-content/cache/cache-enabler/{host}{path}https-index.html
}
handle @cacheable {
    rewrite * /wp-content/cache/cache-enabler/{host}{path}https-index.html
    header X-Cache-Enabler hit-caddy
    file_server { precompressed gzip }
}
```

Three traps that make this silently cache nothing — see `gotchas.md`: configure with
`wp --url=…`, warm with `Accept: text/html`, and watch the trailing-slash rule. The file is
`https-index.html`, not `index.html`.

Add a `X-Cache-Bypass` header the warm-up script can send to force a fresh render.

---

## 4. CDN edge cache

Where an event is actually won. Three Cloudflare Cache Rules, **in order**:

1. **Bypass dynamic** — `/wp-admin`, `/wp-json`, `*.php`, status endpoints.
2. **Static assets long** — `/wp-content/`, `/wp-includes/` → Edge 30 days, Browser 1 day.
   Safe because WordPress versions assets with `?ver=`.
3. **HTML for anonymous visitors** → Edge 2 h, Browser 300 s.

Expression traps (`gotchas.md`): avoid `not http.cookie contains …`; exclude by path.
Edge TTL minimum is 2 hours; Browser TTL is entered in raw seconds. Audit legacy **Page
Rules** — they evaluate first and silently override Cache Rules.

Also enable Tiered Cache and Always Online.

**Verify, don't assume:**

```bash
curl -sI https://host/page/   # twice — second must be cf-cache-status: HIT
```

---

## 5. Warm the cache

Before an event, from the **event's region**:

- Pull every URL from the sitemap — but **verify the sitemap is correct first**; one site's
  SEO plugin listed 19 of 20 posts at URLs that 404'd.
- Expand to every language.
- Send a browser-like `Accept` and `User-Agent`.
- Fetch twice: once to fill, once to prove `HIT`.
- Parallelise (`xargs -P 6`) — sequential took 18 min, parallel 64 s for 208 pages.
- Exit non-zero below a HIT threshold so it fails loudly.

---

## 6. Capacity arithmetic

| Path | Throughput | Limit |
|---|---|---|
| CDN edge HIT | effectively unbounded | visitor bandwidth |
| Origin page cache | ~80+ req/s on 2 vCPU | network |
| Uncached PHP | `max_children / avg_render` ≈ 2–3 req/s | CPU + RAM |

Measured: 3,000 requests at concurrency 30 against a cached page → 83 req/s, p95 456 ms,
**origin PHP active stayed at 1** and memory *fell*. The same box uncached: 2.56 req/s,
degrading by queueing — not dying.

That ratio is the whole argument for caching.
