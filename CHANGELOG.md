# Changelog

All notable changes to plugins in this marketplace are documented here.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## codech-web-hardening

### [1.0.0] — 2026-10-07

First release. Generalised from four real engagements: an 11-hour OOM outage and event-readiness programme on a live broker site, a WordPress production security audit, a cPanel directory-site performance recovery, and an SSH lockout during firewall hardening.

**Contents:**
- `SKILL.md` — break-glass-first workflow (Phase 0 safety → measure → triage order → verify through the public path)
- `references/hardening-playbook.md` — the ordered steps, each with backup → change → verify → rollback
- `references/gotchas.md` — ~25 entries in Symptom / Cause / Fix form, all paid for in production time
- `references/caching-and-capacity.md` — php-fpm sizing arithmetic, DB bloat, origin page cache, CDN cache rules
- `references/events-and-shared-ips.md` — why per-IP defences must be disabled for campaign spikes (venue NAT + carrier CGNAT), and how to load-test prod without causing an outage
- `references/wordpress-specific.md` — inherited-site audit, enumeration, multilingual traps, SEO-plugin sitemap caching
- `references/audit-report.md` — audit report + staged remediation runbook templates
- `templates/` — php-fpm pool tuning, fail2ban filters/jails/actions, proxy blocklist script, UFW admin allowlist and Docker block (all `__PLACEHOLDER__`, no real IPs or tokens)
- `scripts/triage.sh` — read-only diagnostic sweep; `scripts/watchdog.sh` — self-healing liveness check with evidence capture

**Notable lessons encoded:**
- `pm.max_children × peak worker RSS` must fit the memory cap — the single most common cause of "the server is too small"
- Single-file bind mounts: `sed -i` replaces the inode and the container keeps the old file
- A manual `fail2ban banip` bypasses `ignoreip` and will cut your own SSH session
- `ufw deny` does nothing to Docker-published ports; load CDN allow rules *before* the block
- Cloudflare expressions using `not http.cookie contains …` never match a request with no Cookie header
- Verify front-end optimisation logged-out — page caches skip logged-in sessions and make a working cache look broken

**Integration:**
- Composes with `superpowers:systematic-debugging` (unknown cause) and `superpowers:verification-before-completion` (before claiming a fix)
- Hands off to `codech-project-superpower` when the engagement needs a full document set

## codech-mockup-design

### [1.4.2] — 2026-06-28

Migrated into the central `codech-marketplace` from the standalone `codech-dev/codech-mockup-design` repo. This is the first release published through the central marketplace; version continues from the standalone's `package.json` (1.4.2) rather than resetting to 1.0.0.

**Contents:**
- `SKILL.md` — 7-phase design workflow (Gather intelligence → Design system → Showcase HTML → Mobile mockup → AI image generation → Present & iterate → Multiple directions + lock)
- `references/differentiation-axes.md` — the 7-axis differentiation checklist for multi-direction comparisons
- `references/showcase-template.md` — self-contained HTML showcase structure
- `references/interactive-prototype-scaffold.md` — Framer Motion + shadcn/ui prototype scaffold
- `scripts/generate_mockup_images.py` — Hugging Face Inference API image generator for hero banners, product shots, lifestyle photos, textures

**Integration:**
- **Requires** `ui-ux-pro-max` for Phase 1 design intelligence queries
- Composes with `codech-project-superpower` (Phase 2 proposal step) and `codech-client-proposal` (consumes the produced `design-system.md`)

**Migration note:**
- Standalone repo `codech-dev/codech-mockup-design` still exists but is not the source of truth going forward. Future updates land here; the standalone repo will be marked as archived / redirect-only in a follow-up.

---

## codech-web-builder

### [0.1.0] — 2026-06-29

Initial release. Productizes the Coway agent-site build arc (taste-skill design + coway-starter deploy) into a reusable, stack-agnostic plugin.

**Added:**
- 5-phase pipeline: Palette → Capture references → Design → Convert → Deploy, with two human gates (after design, before deploy)
- `SKILL.md` lean orchestrator with trigger-focused description and a references/adapters map
- `references/01-palette-from-logo.md` — vision-based palette extraction + fixed token schema with WCAG AA contrast checks
- `references/02-capture-references.md` — Playwright (visual + DOM) + Firecrawl (structured) capture with a degradation ladder
- `references/03-design-handoff.md` — hands tokens + analysis to a taste skill (`design-taste-frontend`/`frontend-design`) as the design engine
- `references/04-conversion-contract.md` — the versioned portable-artifact spec every adapter consumes (stack-neutral seam)
- `references/00-preflight.md` + `scripts/preflight.mjs` — Phase 0 dependency check (required/optional/conditional tiers); stops and asks the user to install missing required skills/tools before any pipeline work
- `references/05-gates-and-qa.md` — the two gates + post-deploy live-screenshot QA
- `references/06-source-images.md` — source real topical images locally (no placeholders, no hotlinking)
- `scripts/fetch-images.mjs` — downloads stock images: Pexels/Unsplash via API key, Openverse (CC, no key) fallback, with license + attribution recorded
- `adapters/static.md` — static site to Cloudflare Pages (universal fallback)
- `adapters/wordpress.md` — maps the artifact onto coway-starter (new skin + provisioner), with unique no-prices SEO
- `scripts/capture.mjs` — Playwright multi-viewport screenshot + DOM dump (dynamic import so usage works without Playwright)

---

## codech-client-proposal

### [1.0.0] — 2026-06-28

Initial release. Extracted from the JY Global AI Portal proposal engagement (Q2 2026).

**Added:**
- 6-step workflow: Discover → Gather → Build → Capture → Deploy → Handoff
- `SKILL.md` entry point with trigger-focused description and references map
- `references/proposal-anatomy.md` — 11-section canonical catalogue with required/optional markers
- `references/visual-idioms.md` — copy-paste markup for eyebrow pills, featured dark cards, browser-chrome mockups, anim-up gates, mobile lightbox, sticky nav active state, stat banner, responsive grid rule
- `references/using-design-system.md` — how to plug per-client tokens into the Tailwind config; locked Codech elements list
- `references/voice-and-copy.md` — short clauses, no puffery rules, banned words list, voice presets, forbidden phrasings table
- `references/screenshot-pipeline.md` — Playwright capture method with MCP variant
- `references/cloudflare-deploy.md` — wrangler workflow with optional Basic Auth middleware
- `references/composing-skills.md` — delegation rules with codech-mockup-design and codech-project-superpower
- `scripts/capture-screenshots.mjs` — Playwright runner that tags mockups, forces settled state, element-screenshots each
- `scripts/deploy.sh` — wrangler wrapper that prepares `_deploy/` folder and deploys
- `scripts/add-password.sh` — Pages Functions Basic Auth middleware setup (prompts user for password)
- `assets/codech-logo.png` — locked Codech identity
- `assets/codech-closing-section.html` — locked closing card with logo + contact card + WhatsApp CTA
- `assets/proposal-skeleton.html` — empty scaffold with all canonical sections stubbed
- `examples/jy-global-reference.md` — worked example with iteration history

**Locked Codech idioms across all client design systems:**
- Closing section (Codech logo + contact card + WhatsApp green CTA)
- Confidentiality pill in utility bar
- Mobile lightbox tap-to-zoom UX
- End-of-proposal sign-off marker

**Integration:**
- Composes with `codech-mockup-design` (delegates design-system creation)
- Composes with `codech-project-superpower` (consumes its prototype HTML output)

**Tested on:**
- JY Global AI Portal — Cayman Islands compliance advisory firm — live at https://jy-global-proposal-ai-portal.pages.dev

---

## codech-project-superpower

### [1.1.0] — 2026-06-29

Phase 5 — Production Development extension. The skill now carries an approved pre-dev package through into a shipping production codebase, not just to the prototype. Backward-compatible: Phases 1–4 are unchanged.

**Added:**
- Phase 5 — Production Development section in `SKILL.md`: master implementation plan, gated TDD sub-plan loop, foundation/auth/module universal (stack-agnostic) patterns, CLAUDE.md + cross-session-memory + pixel-diff discipline, Phase 5 approval gates
- `templates/master-plan-structure.md` — 11-section master implementation plan
- `recipes/pixel-diff-harness.md` — cross-platform Playwright visual-regression setup
- `recipes/backend-crud-module-fastapi.md` — CRUD module reference impl (FastAPI + SQLModel + Alembic)
- `recipes/field-level-encryption-python.md` — AES-256-GCM + AES-256-SIV reference impl
- Phase 5 trigger phrases ("ready to proceed development", "scaffold the monorepo", "build the X module"; `docs/` with FSD/SAD/TDD/SRS present)

**Changed:**
- `README.md` + both manifests updated from "4-phase, ends at prototype" to the full 5-phase end-to-end workflow; removed the now-false "production code generation / real backend — NOT in scope" lines

**Integration:**
- Phase 5 additionally orchestrates `superpowers:writing-plans`, `superpowers:executing-plans`, `superpowers:subagent-driven-development`, `superpowers:finishing-a-development-branch`

**Tested on:**
- CGG Agricultural ERP — drove the production build through 20+ gated TDD sub-plans to a live staging deployment

---

### [1.0.0] — 2026-05-21

Initial release. Extracted from the CGG Agricultural ERP engagement (2026).

**Added:**
- 4-phase workflow: Ingest → Proposal → Pre-dev Docs → PoC Prototype
- `SKILL.md` orchestrator with phase decision tree and approval gates
- `gotchas.md` with 20+ battle-tested fixes from real engagement
- `templates/proposal-structure.md` — 19-section proposal template with bilingual conventions
- `templates/pre-dev-docs-structure.md` — FSD/SAD/TDD/SRS templates with ID schemes
- `templates/poc-prototype-html.md` — Single-file React + Tailwind + Framer Motion scaffold
- `recipes/pdf-export.md` — Chrome headless PDF export with all flags documented
- `recipes/architecture-diagram.md` — Inline SVG architecture diagram conventions
- Industry adaptations: agriculture, finance, healthcare, e-commerce, SaaS
- Locale adaptations: Trad Chinese, Simp Chinese, Japanese, English

**Integration:**
- Orchestrates `docx`, `superpowers:brainstorming`, `ui-ux-pro-max:ui-ux-pro-max`

**Tested on:**
- CGG Agricultural ERP (Hong Kong, Trad Chinese, AI-enabled, ~6-month engagement)

---

## Versioning policy

| Version bump | Trigger | Example |
|---|---|---|
| **Patch (1.0.x)** | Bug fixes, typos, gotcha additions, minor template polish | Add a new entry to `gotchas.md` |
| **Minor (1.x.0)** | New templates, recipes, optional features; backward-compatible | Add a `templates/test-plan-structure.md` |
| **Major (x.0.0)** | Breaking changes to workflow phases, file conventions, or skill name | Restructure phases or rename outputs |

## Update workflow

When updating a plugin:

1. Edit the relevant files
2. Bump the version in **both** manifests:
   - `.claude-plugin/marketplace.json` → `plugins[N].version`
   - `plugins/<plugin>/.claude-plugin/plugin.json` → `version`
3. Add a CHANGELOG entry above
4. Commit with conventional commit message (`feat:`, `fix:`, `docs:`, etc.)
5. Push to `main`
6. Notify team to run `/plugin marketplace update codech-marketplace`
