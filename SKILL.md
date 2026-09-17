---
name: "muse_leakage_guard"
description: "Validate an AI assistant's private-memory leakage protection: enumerate every path private data could leave, red-team the egress and brief gates with synthetic payloads, verify shim interception, and report gaps. Run after any change to the protection layer."
---

# Muse Leakage Guard

A validation skill for private-memory leakage protection. It does not
protect anything itself — it *proves* the protection works, and finds the
holes. Every finding carries a concrete suggested remediation. The skill
never applies fixes itself: remediation belongs to the memory skill (or
the agent operating it) — this one stays focused on validation. Run it
after any change to the gates, shims, or briefing policy, and on a
schedule if you want continuous assurance. It is also the
leakage-protection step of the memory skill's daily health check.

## How to run

`bin/leakage-report [--out PATH]` — runs the full audit and writes a
mobile-friendly HTML outcome report (default:
`hidden_files/reports/leakage-validation-<timestamp>.html`). Each suite
gets a one-sentence green/red callout ("🟢 Red-team gates: 29 of 29
green."), with the full per-check evidence expandable underneath. The
command exits with the audit's exit code (0 = CLEAN). `bin/leakage-audit`
alone prints the same results as plain text.

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
names every failure. Exit 2 = usage error or a refused live-fire run
(environment problem, not findings). A report is printed to stdout; save it with
`bin/leakage-audit | tee reports/<date>.md`.

`bin/leakage-audit -h` prints usage. Unknown arguments are rejected with
exit 2, as is `bin/leakage-report --out` without a path.

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

- Scope: validate and suggest, never fix. Each failed check prints a
  concrete suggested remediation (and the HTML report shows it in the
  expanded evidence). Applying the fix is the memory skill's — or the
  operating agent's — job, followed by a re-run of this audit.
- The gates under test live in the personal-memory-system skill
  (`bin/egress-gate`, `bin/brief-gate`, `bin/shims/`,
  `bin/memory-egress-check`). This skill resolves them via
  `PERSONAL_MEMORY_SKILL` (default
  `~/workspace/skills/personal-memory-system`) and never duplicates
  their logic — it only verifies behavior.
- Tests use fake "real" binaries (`MOCHI_REAL_*` overrides) so no test
  ever sends anything anywhere — except the opt-in live-fire mode below,
  which exercises the genuine path deliberately.
- **Live-fire (opt-in, owner's installation only).**
  `MOCHI_LIVE_FIRE=1 MOCHI_TEST_EMAIL=<own address> bin/leakage-audit`
  sends a small synthetic subset for real, to the owner's own accounts
  only. Guards: must be set inline per invocation (a `local.env` value is
  ignored); refused without a TTY / under `$CI` unless
  `MOCHI_LIVE_FIRE_NONINTERACTIVE=1`; the email target must match the
  authenticated Gmail profile; the Messenger target must be an
  owner-only chat (anything else fails closed); stale `MOCHI_REAL_*`
  overrides are unset so a `LIVE-FIRE` run always means the genuine
  binaries; Drive share tests stay simulated. Do not enable live-fire
  during validation of changes — validate in simulated mode only.
- All public examples are synthetic and impersonal, per policy.
