# Events, Spikes and Shared IPs

For a campaign, conference, product launch or anything with a "scan this QR code now"
moment — and for every load test on production.

---

## The counter-intuitive rule

**Every per-IP defence becomes a liability during an event.**

- A venue's Wi-Fi presents **one** public IP for the whole room.
- Mobile carriers use **CGNAT** — thousands of subscribers behind one address.

So a rate limit, a flood jail, "Security Level: High", or bot-challenge mode will fire on
**the audience**, not on an attacker. The defences that protect you on a normal Tuesday are
the ones that break your launch.

This is not theoretical: during a load test from a single laptop, the flood jail banned the
tester's own IP and Cloudflare served **520** while the origin was perfectly healthy. That
is precisely what 2,000 phones behind one NAT would have triggered.

**Therefore:** build an explicit *event mode* that relaxes per-IP defences for the window,
and **verify both sides come back afterwards**.

---

## Load model

Estimate the burst rather than guessing:

```
peak_rps ≈ (attendees × scan_rate) / burst_seconds
```

2,000 phones in 2 minutes ≈ **17 page views/s**, plus 20–60 asset requests each.

Against an uncached WordPress on 3 workers at ~1 s/render → **3 req/s**, i.e. an
11-minute queue and mass timeouts. With HTML served from the edge, the origin sees
almost nothing. **Caching is the entire strategy**; the server size is not the lever.

---

## Preparation checklist

**T-2 weeks**
- Hardening playbook Steps 1–7 complete.
- CDN cache rules live and **verified** (`cf-cache-status: HIT` on the target page).
- Confirm the exact URL the QR code will encode, and make every hop to it static
  (a `/` → `/en/` redirect through PHP costs one PHP request per scan).

**T-1 week**
- Rehearse at smaller scale if there is an earlier event.
- Load test at night, announced, ramped, watched (below).
- External uptime monitor with alerts to two phones.
- Name the on-call person and give them the runbook.

**T-1 day** — change freeze. No plugin/theme/core updates, no config changes.

**T-1 hour**
- `event-mode.sh on` — stop per-IP jails, lower CDN security level, disable rate limiting,
  disable bot-fight mode.
- Raise edge cache TTL.
- Warm the cache from the **event's region** so the right PoP is primed.
- Open the live dashboard.

**During** — watch pool `active`/`queue`, 5xx, OOM. Let a queue drain; only intervene if
5xx are actually being served.

**After** — `event-mode.sh off`, **assert** jails and CDN settings are restored, lower TTL,
write the post-mortem the same day.

---

## Event mode must verify its own restore

`fail2ban-client start <jail>` does **not** work on a stopped jail — the server has
forgotten it. The `off` path must do a full `reload` and then *assert*:

```bash
running=$(fail2ban-client status | grep -oE 'proxy-[a-z]+' | tr '\n' ' ')
case "$running" in
  *proxy-flood*proxy-scanner*) echo "restored: $running" ;;
  *) echo "NOT RESTORED (running: ${running:-none}) — run: fail2ban-client reload" ;;
esac
```

A smoke test that skipped this left a production site with no jails for 45 minutes.

---

## Load testing production

Only with the user's explicit agreement. A load test *is* a small DDoS you are aiming at
your client's business — at concurrency 8 it once saturated every Apache worker and
returned site-wide 502s to real visitors.

Rules:
- Night-time, announced, **ramped** (200 → 500 → full), never straight to full concurrency.
- **Event mode on first**, or you ban yourself.
- Watch from a second terminal; abort on any 5xx or OOM kill.
- Test the cached path *and* an uncached path (`?nocache=1`) — they measure different things.
- Kill the test immediately when done.

Reading the results:
- `ab`'s `Failed requests … (Length: N)` is response-size variance, **not** errors.
- Trust `Non-2xx responses` and the server's own access log.
- Record origin `active`/`queue`/memory during the run, not just client-side numbers.

Healthy shape under overload: requests **queue and complete slowly**. Unhealthy: 5xx,
OOM kills, restarts.

---

## What you do not control

The venue's own uplink. 2,000 phones × a 3–4 MB page ≈ 7 GB in two minutes (~500 Mbit/s).
No server-side change fixes that — only a lighter page. Raise it with the organiser early;
it is their constraint to manage, but your outage if nobody mentions it.
