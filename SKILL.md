---
name: "muse_leakage_guard"
description: "Validate an AI assistant's private-memory leakage protection: enumerate every path private data could leave, red-team the egress and brief gates with synthetic payloads, verify shim interception, and report gaps. Run after any change to the protection layer."
---

# Muse Leakage Guard

A validation skill for private-memory leakage protection. It does not
protect anything itself — it *proves* the protection works, and finds the
holes. Run it after any change to the gates, shims, or briefing policy,
and on a schedule if you want continuous assurance.

## What it checks

1. **Installation integrity** — gates and shims exist, are executable,
   syntactically valid, and the shims actually shadow the real CLIs.
2. **Gate effectiveness (red team)** — synthetic payloads (fake secrets,
   test SSN/card shapes, figures, phones, clean text) are fired at every
   gate and every send path; each must return exactly the expected
   verdict, and blocked sends must never reach the real binary.
3. **Coverage gaps (static checks)** — every known exfiltration path is
   mapped in `references/attack-surface.md`; the audit verifies each
   path's stated control is actually in place (cron PATH wiring, briefing
   mandates, memory audit green).
4. **Audit-log review** — recent gate decisions are summarized; approval
   overrides and blocked attempts are surfaced for human review.
5. **Known residuals** — paths that cannot be technically gated are
   reported explicitly, never silently.

## Usage

```bash
# Full validation against the local installation:
bin/leakage-audit

# Against a different install of the memory skill:
PERSONAL_MEMORY_SKILL=/path/to/skill bin/leakage-audit

# Audit log location override:
MOCHI_EGRESS_LOG=/path/to/egress-gate.log bin/leakage-audit
```

Exit 0 = all checks pass. Exit 1 = at least one check failed; the report
names every failure. A report is printed to stdout; save it with
`bin/leakage-audit | tee reports/<date>.md`.

The report is responsive: it fits the terminal width (or
`MOCHI_REPORT_WIDTH`, clamped to 40–76), wraps every line so nothing
scrolls sideways on a phone, shortens `$HOME` to `~`, and switches the
summary table to a stacked layout on narrow screens.

## Layout

- `bin/leakage-audit` — the validation runner (all checks, all fixtures).
- `bin/fixtures/` — synthetic payloads only. Never put real private data
  here; the fixtures are designed to trip the detectors without being
  anyone's real secret (`123-45-6789`, `4111-1111-1111-1111`,
  `sk-testfakekey…`, `415-555-0132`).
- `references/attack-surface.md` — the enumerated leakage paths, each
  with its control and coverage status.
- `references/test-matrix.md` — what each test proves and why it matters.

## Design notes

- The gates under test live in the personal-memory-system skill
  (`bin/egress-gate`, `bin/brief-gate`, `bin/shims/`,
  `bin/memory-egress-check`). This skill resolves them via
  `PERSONAL_MEMORY_SKILL` (default
  `~/workspace/skills/personal-memory-system`) and never duplicates
  their logic — it only verifies behavior.
- Tests use fake "real" binaries (`MOCHI_REAL_*` overrides) so no test
  ever sends anything anywhere.
- All public examples are synthetic and impersonal, per policy.
