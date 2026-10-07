# codech-web-hardening

> Harden and stabilise a live web server without being the person who takes it down.

Every rule in this plugin was paid for by a real incident on a client server: an 11-hour
outage, a 50-minute SSH lockout, a 3.1 GB database behind a 53-post website, a scanner that
was 99 % of all traffic, a sitemap that had been serving 404s to Google for months.

## What it covers

| Area | What you get |
|---|---|
| **Safety** | Break-glass-first order of operations; the lockout traps that make hardening dangerous |
| **Capacity** | Sizing php-fpm to RAM (the usual root cause of "the server is too small"), timeouts, status endpoints |
| **Defence** | fail2ban jails driven by the reverse proxy's own access log, banning at the proxy so the real client IP is used |
| **Isolation** | Locking the origin to CDN ranges — including the UFW/Docker trap where `ufw deny` does nothing |
| **Performance** | Origin page cache + CDN edge rules; the three silent ways a page cache caches nothing |
| **Resilience** | Self-healing watchdog that captures evidence before restarting |
| **Events** | Why every per-IP defence must be *disabled* for a campaign spike, and how to load-test prod without causing an outage |
| **Deliverables** | Audit report and staged remediation runbook templates |

## Install

```
/plugin marketplace add codech-dev/Codech-Claude-Marketplace
/plugin install codech-web-hardening
```

## Use

The skill triggers on its own for things like:

- "the site is down / timing out / 502"
- "secure the server", "we're being scanned", "stop the attack"
- "it dies under load", "prepare for our launch event"
- "run a security audit"

Or invoke directly: `/codech-web-hardening`.

## Structure

```
skills/codech-web-hardening/
  SKILL.md                          the workflow: break glass → measure → triage → verify
  references/
    hardening-playbook.md           ordered steps with commands
    gotchas.md                      ← read this first when something looks impossible
    caching-and-capacity.md         pool sizing, page cache, CDN rules, DB bloat
    events-and-shared-ips.md        campaign spikes, CGNAT, safe load testing
    wordpress-specific.md           inherited-site audit, enumeration, sitemaps
    audit-report.md                 audit + remediation runbook templates
  templates/                        php-fpm, fail2ban, caddy, ufw (placeholders only)
  scripts/
    triage.sh                       read-only diagnostic sweep
    watchdog.sh                     self-healing liveness check
```

## Conventions

- Templates use `__UPPERCASE__` placeholders. **Never commit a filled-in copy** — real IPs
  and tokens do not belong in this repo.
- Secrets live in root-owned `0600` files on the server. Point people at the file; never
  ask anyone to paste a token into chat.
- Every change in the playbook has a backup, a verification **through the public path**,
  and a rollback.

## Contributing

If a problem cost you more than 30 minutes, it belongs in `references/gotchas.md` in the
Symptom / Cause / Fix format. See the repo's `CONTRIBUTING.md`.
