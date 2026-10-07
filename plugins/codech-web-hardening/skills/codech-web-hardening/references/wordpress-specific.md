# WordPress Specifics

Applies on top of the generic playbook. Most inherited WordPress sites fail the same way.

---

## Inherited-site audit (first hour)

```bash
WP="wp --url=https://__HOST__ --path=__WPPATH__"     # --url matters; see gotchas

$WP core version && $WP core verify-checksums
$WP plugin list --status=inactive --format=count
ls -la wp-content/mu-plugins/                         # vendor leftovers hide here
$WP option get blog_public                            # 0 = site is noindex'd
curl -sI https://__HOST__/ | grep -i x-robots-tag     # noindex from the proxy?
curl -s https://__HOST__/wp-json/wp/v2/users          # user enumeration
curl -sI https://__HOST__/xmlrpc.php
find wp-content/uploads -name '*.php'                 # never legitimate
```

### Things that are nearly always wrong

| Finding | Why it matters | Fix |
|---|---|---|
| `noindex` left on after launch | Site invisible to Google, losing traffic daily | Scope the header to staging hostnames only |
| Vendor `mu-plugins` | Can disable **all** core security auto-updates | Archive, remove, get sign-off |
| 20+ inactive plugins | Unpatched code still on disk and reachable | Archive to a tarball **outside** the webroot, delete |
| REST user enumeration | Feeds credential stuffing | Hardening plugin or targeted filter |
| PHP under `uploads/` | Almost certainly a web shell | Investigate, then block execution at the proxy |
| Backups inside the webroot | Publicly downloadable (verified live) | Move to a host path outside the webroot |
| No `WP_POST_REVISIONS` cap | DB grows without bound | `define('WP_POST_REVISIONS', 5)` |
| Missing wp-cli in the container | WP-Cron, core checks and alert mail silently broken | Bind-mount a checksum-verified phar |

---

## Proxy-level WordPress rules

```caddyfile
# Never execute PHP under uploads — essential with php-fpm
@uploads_php path_regexp ^/wp-content/uploads/.*\.(php|phtml|phar|php[0-9]*)$
handle @uploads_php { respond 403 }

# Version/config/VCS leakage
@blocked path /xmlrpc.php /readme.html /license.txt /wp-config.php* \
              /wp-content/debug.log /*.sql /*.bak /.git/* /.env
handle @blocked { respond 403 }

# REST user enumeration
@userenum path_regexp ^/wp-json/wp/v2/users
handle @userenum { respond 403 }
```

Before blocking `xmlrpc.php`, check for Jetpack or a mobile app that needs it.

---

## Behind a CDN

WordPress generates `http://` URLs and redirect-loops unless it is told the connection is
HTTPS:

```php
if ( isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https' ) {
    $_SERVER['HTTPS'] = 'on';
}
if ( isset($_SERVER['HTTP_X_FORWARDED_FOR']) ) {
    $_SERVER['REMOTE_ADDR'] = trim(explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0]);
}
define('DISALLOW_FILE_EDIT', true);
define('DISABLE_WP_CRON', true);   // real cron on the host instead
define('WP_POST_REVISIONS', 5);
```

Run WP-Cron from system cron (`*/15`), or it only fires on visits — which a page cache
prevents.

---

## Multilingual (TranslatePress and friends)

- Language homepages are `/en/`, `/zh/` … and a bare `/` 301s to the default. That redirect
  goes **through PHP** unless you make it static at the proxy — one PHP request per visitor,
  which matters enormously at a QR-code moment.
- `/wp-login.php` may answer **301** (language prefix). Watchdog probes must accept it.
- Trailing-slash homepages collide with no-trailing-slash permalinks and defeat some page
  caches (`gotchas.md`).
- Translated pages can be dramatically slower uncached (6.6 s vs 0.4 s observed) — they
  benefit most from caching.

---

## SEO plugin sitemaps

Verify sitemaps resolve; do not assume. One site had 19 of 20 entries 404ing for months
because the plugin served **stale cached XML from disk**
(`wp-content/uploads/<plugin>/*.xml`) — cache purges and rewrite flushes did nothing.

```bash
curl -s https://__HOST__/post-sitemap.xml | grep -oE '<loc>[^<]+' | sed 's/<loc>//' \
  | while read -r u; do echo "$(curl -sL -o /dev/null -w '%{http_code}' "$u") $u"; done
```

Fix: back up and delete the cached XML, re-request the sitemap, then re-test **every** entry.

---

## Database maintenance

See `caching-and-capacity.md` §2. In short: cap revisions, delete old ones in batches,
`OPTIMIZE` to reclaim the tablespace (InnoDB does not return it automatically), convert hot
MyISAM tables to InnoDB with covering indexes, and verify completeness with exact
`COUNT(*)` — never `information_schema.table_rows`.

---

## Hardening plugins

**Pre-seed the options before activating**, so unwanted toggles (XML-RPC off, HSTS) do not
fire unexpectedly on a live site. Review the plugin's code for the by-reference `foreach`
bug pattern documented in `gotchas.md` — it 500'd every REST route on a production site.
