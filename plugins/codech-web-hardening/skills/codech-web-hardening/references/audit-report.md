# Audit and Remediation Deliverables

Two documents, written for different readers. Produce both when the engagement is an audit
rather than an emergency.

---

## 1. Audit — what is wrong and how bad

Written for the client's decision-maker. Lead with impact, not mechanism.

```markdown
# <Site> — Security & Stability Audit, <date>

## Summary
<3–5 sentences: what state the site is in, the single biggest risk, what it would cost
to be hit by it. No jargon.>

## Findings
| ID | Severity | Finding | Impact if exploited | Effort |
|----|----------|---------|---------------------|--------|
| F1 | Critical | …     | …                   | S/M/L  |

## Evidence
<Per finding: the exact command and its output. An audit without reproducible evidence
is an opinion.>

## Not findings
<What you checked and found healthy. Prevents a second audit re-treading it, and shows
the scope was real.>

## Out of scope / no access
<Systems you could not reach — name them explicitly so the gap is the client's decision,
not a silent hole.>
```

**Severity** — judge by *impact if exploited*, not how easy it was to find:

| | Meaning |
|---|---|
| **Critical** | Unauthenticated RCE, data exposure, site down now |
| **High** | Authenticated RCE, privilege escalation, credential leak |
| **Medium** | Information disclosure, enumeration, missing hardening |
| **Low** | Defence-in-depth, best practice |

Be honest about blast radius. "12 backup files publicly downloadable" sounds critical;
if they contain no PII it is Medium. Inspect before rating, and say what you inspected.

---

## 2. Remediation runbook — how to fix it safely

Written for whoever executes, possibly at 2am, possibly not you.

Every stage needs **five** parts:

```markdown
### Stage N — <change>

**Why:** <finding ID + one line>
**Risk:** <what breaks if this goes wrong>
**Backup:** <exact command, to a path outside the webroot>
**Apply:** <exact commands>
**Verify:** <command + the expected output, through the PUBLIC path>
**Rollback:** <the single command that undoes it>
```

Plus a progress table the operator ticks as they go:

| Stage | Status | Applied | By | Notes |
|-------|--------|---------|----|----|

Rules that make a runbook trustworthy:
- **One stage at a time**, each independently reversible.
- **Ordered by risk**, lowest first — build confidence before touching the dangerous parts.
- **Mark which stages interrupt traffic** and roughly for how long.
- **Never bundle** "while we're in there" changes.
- Anything deferred gets its own line with the reason, so it is a decision rather than
  an omission.

---

## Reporting honestly

- If a fix is unverified, say so. "Applied, not verified" is a legitimate status.
- If you broke something, lead with it, with the timestamp and the current state.
- If a step was skipped, say which and why.
- Distinguish **your** findings from the client's pre-existing problems — not to deflect,
  but so they know what changed under your hands.
- Record near-misses too; an accidental restart that proved the watchdog works is real
  evidence, and hiding it loses that.
