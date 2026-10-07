# Codech Claude Marketplace

> Codech's internal collection of Claude Code plugins — workflows, skills, and tools used across client engagements.

A Claude Code [marketplace](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces) installable by anyone on the Codech team.

---

## Available Plugins

| Plugin | Version | Description |
|---|---|---|
| [`codech-project-superpower`](./plugins/codech-project-superpower) | `1.1.0` | End-to-end engagement workflow: requirements docs → bilingual proposal (MD/HTML/PDF) → FSD/SAD/TDD/SRS → interactive React prototype → production development with prototype as pixel-diff contract |
| [`codech-mockup-design`](./plugins/codech-mockup-design) | `1.4.2` | Structured design ideation and visual prototyping — design system documents (tokens, principles, accessibility rules) + self-contained HTML showcases. 7-axis differentiation, optional Framer Motion + shadcn/ui interactive prototypes |
| [`codech-client-proposal`](./plugins/codech-client-proposal) | `1.0.0` | Packages a Codech engagement into a deployed, client-shareable HTML proposal. Applies a per-client design system to the canonical proposal anatomy, captures prototype screenshots via Playwright, deploys to Cloudflare Pages with a `*.pages.dev` URL |
| [`codech-web-builder`](./plugins/codech-web-builder) | `0.1.0` | Turn reference website(s) + a brand logo into a deployed site: vision-extracted palette, taste-skill design system + HTML prototype, then convert to WordPress or static and deploy |
| [`fintech-compliance-copy`](./plugins/fintech-compliance-copy) | `1.0.0` | Design, build, and keep regulator-safe a crypto / digital-asset / payment / fintech marketing website. Compliance baked in — disclaimers, unlaunched-service tagging, lawyer-approved wording |
| [`codech-cinematic-web`](./plugins/codech-cinematic-web) | `1.0.0` | Cinematic marketing-page effects: a Three.js hero object lit by one analytic screen-space atmosphere, plus a sticky scroll deck over full-bleed video — with the measurement scripts that catch shell-banded glow, skipped panels and silent iOS autoplay failure |
| [`codech-web-hardening`](./plugins/codech-web-hardening) | `1.0.0` | Harden and stabilise a live web server without taking it down. Break-glass-first safety, capacity triage (php-fpm vs RAM), proxy-log fail2ban, origin lockdown, origin + edge caching, self-healing watchdog, event/campaign spike readiness, safe load testing, audit + remediation runbook templates |

More plugins will be added over time.

---

## Installation

### Step 1 — Add the marketplace (one-time)

In Claude Code (any project), run:

```
/plugin marketplace add codech-dev/Codech-Claude-Marketplace
```

> If the repo is **private**, see [Private Repo Setup](#private-repo-setup) below.

Claude Code will fetch `.claude-plugin/marketplace.json` and confirm the marketplace was added.

### Step 2 — Install a plugin

Install whichever plugins you need. Example for the pre-development workflow:

```
/plugin install codech-project-superpower@codech-marketplace
```

Or for the deployed-proposal delivery workflow:

```
/plugin install codech-client-proposal@codech-marketplace
```

Both are installable side-by-side — they compose: `codech-project-superpower` produces the prototype + design system, and `codech-client-proposal` packages those into a deployed proposal site.

That's it. Restart Claude Code and the skill will activate automatically based on trigger phrases (see each plugin's README).

### Verify installation

```
/plugin list
```

You should see the installed plugins listed under `codech-marketplace`.

---

## Usage

Once installed, the skills activate automatically based on what you say.

### `codech-project-superpower` triggers on:

- _"Generate a project proposal from these requirement docs"_
- _"Scope this project"_
- _"Draft the FSD / SAD / TDD / SRS"_
- _"Build a PoC prototype"_
- _"Convert the proposal to HTML and PDF"_

Or when Claude detects a `Requirements doc/` folder in your project.

See [`plugins/codech-project-superpower/README.md`](./plugins/codech-project-superpower/README.md) for the full skill documentation.

### `codech-client-proposal` triggers on:

- _"Build a proposal"_ / _"draft a client proposal"_
- _"Make a proposal site"_ / _"deploy the proposal"_
- _"Cloudflare Pages proposal"_ / _"package as proposal"_
- _"Capture mockup screenshots for the proposal"_
- _"Add password protection to the proposal"_

Or when Claude detects a `design-system.md` and `prototype-app/*.html` files in your project.

See [`plugins/codech-client-proposal/README.md`](./plugins/codech-client-proposal/README.md) for the full skill documentation.

### `codech-mockup-design` triggers on:

- _"Design the UI"_ / _"create a mockup"_
- _"Explore different styles"_ / _"show me what it would look like"_
- _"Build a visual prototype"_ / _"design a landing page"_
- _"Create a design system"_ / _"design 2-3 directions"_
- _"What should the homepage look like?"_

Requires the `ui-ux-pro-max` skill for the Phase 1 design intelligence queries.

See [`plugins/codech-mockup-design/README.md`](./plugins/codech-mockup-design/README.md) for the full skill documentation.

### Composing plugins across an engagement

The typical Codech engagement chains three plugins in sequence — each takes the previous plugin's output as its input:

```
codech-project-superpower      codech-mockup-design           codech-client-proposal
─────────────────────────  →   ────────────────────────  →   ─────────────────────────
Requirements → FSD/SRS         design-system.md +             design-system + prototype
+ engagement scope             HTML showcase + optional        + content →
                               interactive prototype           deployed *.pages.dev URL
```

Or, for a full website deliverable rather than a proposal, `codech-web-builder` replaces the final step by turning references + logo into a deployed WordPress or static site.

---

### `codech-web-hardening` triggers on:

- "the site is down" / "502" / "520" / "timing out" / "it dies under load"
- "secure the server" / "we're being scanned" / "stop the attack"
- "run a security audit" / "write a remediation runbook"
- "prepare for our launch event" / "we expect a traffic spike"
- **Before any load test on a production server**

## Updates

Plugins are updated whenever new lessons are learned from real engagements. To pull the latest versions:

```
/plugin marketplace update codech-marketplace
/plugin update codech-project-superpower
/plugin update codech-mockup-design
/plugin update codech-client-proposal
/plugin update codech-web-builder
/plugin update fintech-compliance-copy
```

Run this periodically — especially before starting a new client project.

---

## Private Repo Setup

If this marketplace is hosted on a **private** GitHub repo, your team members need a GitHub token configured in Claude Code before they can install:

1. Generate a fine-grained Personal Access Token at <https://github.com/settings/tokens?type=beta>
   - **Repository access:** Only this repository (`Codech-Claude-Marketplace`)
   - **Permissions → Contents:** Read-only
2. In Claude Code, set the token via environment variable:
   ```powershell
   # Windows PowerShell
   [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "ghp_xxxxx", "User")
   ```
   ```bash
   # macOS / Linux
   echo 'export GITHUB_TOKEN="ghp_xxxxx"' >> ~/.zshrc   # or ~/.bashrc
   source ~/.zshrc
   ```
3. Restart Claude Code, then run the `/plugin marketplace add` command above.

---

## Repository Structure

```
Codech-Claude-Marketplace/
├── .claude-plugin/
│   └── marketplace.json              # Marketplace manifest (lists all plugins)
├── plugins/
│   ├── codech-project-superpower/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json           # Plugin manifest
│   │   ├── README.md                 # Plugin docs
│   │   └── skills/
│   │       └── codech-project-superpower/
│   │           ├── SKILL.md          # Main orchestrator
│   │           ├── gotchas.md        # Battle-tested fixes
│   │           ├── templates/        # Document structures
│   │           └── recipes/          # Reusable commands
│   └── codech-client-proposal/
│       ├── .claude-plugin/
│       │   └── plugin.json           # Plugin manifest
│       ├── README.md                 # Plugin docs
│       └── skills/
│           └── codech-client-proposal/
│               ├── SKILL.md          # 6-step workflow entry point
│               ├── references/       # Anatomy, idioms, deploy, voice
│               ├── scripts/          # Playwright + wrangler runners
│               ├── assets/           # Logo, closing section, skeleton
│               └── examples/         # JY Global worked reference
├── LICENSE                            # MIT
├── CHANGELOG.md                       # Version history
├── CONTRIBUTING.md                    # How to update plugins
└── README.md                          # This file
```

---

## For Maintainers — How to Update a Plugin

Each plugin's content lives in **`plugins/<plugin-name>/skills/<skill-name>/`**.

To improve a plugin based on a new engagement:

1. Clone this repo (if you haven't):
   ```bash
   git clone https://github.com/codech-dev/Codech-Claude-Marketplace.git
   cd Codech-Claude-Marketplace
   ```
2. Edit the relevant file(s) inside the plugin's skill folder
3. Bump the version in BOTH:
   - `.claude-plugin/marketplace.json` → the matching `plugins[].version`
   - `plugins/<plugin-name>/.claude-plugin/plugin.json` → `version`
4. Add an entry to `CHANGELOG.md`
5. Commit and push:
   ```bash
   git add -A
   git commit -m "feat(<plugin-name>): <what changed>"
   git push
   ```
6. Notify the team to run `/plugin marketplace update codech-marketplace` followed by `/plugin update <plugin-name>`

Versioning follows [Semantic Versioning](https://semver.org/):
- **Patch (1.0.x):** Bug fixes, typo corrections, gotcha additions
- **Minor (1.x.0):** New references, new recipes, new templates
- **Major (x.0.0):** Breaking changes to workflow phases or naming conventions

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidance.

---

## Roadmap

Potential future plugins for this marketplace:

- `codech-contract-templates` — MSA, SOW, DPA generation
- `codech-ai-prompt-library` — Reusable production-grade system prompts
- `codech-deployment-runbook` — Standard Codech deployment patterns
- `codech-uat-test-generator` — Auto-generate UAT scripts from SRS REQ IDs

Suggestions welcome — open an issue or PR.

---

## License

[MIT](./LICENSE) — use freely within Codech and beyond. Attribution appreciated but not required.

---

## Contact

- **Team:** Codech Engineering
- **Email:** team@codech.dev
- **Issues:** [GitHub Issues](https://github.com/codech-dev/Codech-Claude-Marketplace/issues)
