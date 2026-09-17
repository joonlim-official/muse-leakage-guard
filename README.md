# muse-leakage-guard

A validation skill for AI-assistant private-memory leakage protection.
It doesn't protect anything itself — it **proves the protection works**
and finds the holes.

## What it does

`bin/leakage-audit` runs five suites against your installation of the
protection layer (the gates, shims, and policies from the
`personal-memory-system` skill family):

- **A. Installation integrity** — gates/shims exist, parse, and the shims
  actually shadow the real CLIs on `PATH`.
- **B. Red team** — synthetic payloads (fake API keys, test SSN/card
  shapes, figures, phones, clean text) fired at every gate and send path.
  Blocked sends must never reach the real binary. Nothing is ever really
  sent: tests run against fake binaries.
- **C. Attack-surface coverage** — every known exfiltration path
  (`references/attack-surface.md`) has its control verified in place.
- **D. Audit-log review** — recent gate decisions summarized; approval
  overrides surfaced for human review.
- **E. Known residuals** — paths that can't be technically gated are
  reported explicitly every run, never silently.

## Setup

```bash
cp local.env.example local.env   # gitignored; fill in your paths
bin/leakage-audit
```

Configuration is entirely env-driven (see `local.env.example`) — no
personal paths are baked into the skill. All test fixtures are synthetic
and impersonal (`123-45-6789`, `4111-1111-1111-1111`,
`sk-testfakekey…`); never put real private data in `bin/fixtures/`.

Exit 0 = all checks pass. Exit 1 = at least one failure, named in the
report.

## Layout

- `SKILL.md` — skill definition (for the agent).
- `bin/leakage-audit` — the validation runner.
- `bin/fixtures/` — synthetic payloads only.
- `references/attack-surface.md` — enumerated leakage paths and controls.
- `references/test-matrix.md` — what each check proves.
- `reports/` — saved audit reports (gitignored).

## Adding a new exfiltration path

1. Add a row to `references/attack-surface.md`.
2. Add the control (gate or policy).
3. Add the test to `bin/leakage-audit` and the expectation to
   `references/test-matrix.md`.

A path with no row is an unexamined path — the failure mode this skill
exists to prevent.
