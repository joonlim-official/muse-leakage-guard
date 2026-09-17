# muse-leakage-guard

A validation skill for AI-assistant private-memory leakage protection.
It doesn't protect anything itself — it **proves the protection works**,
finds the holes, and suggests the fix. Every failure carries a concrete
suggested remediation; the skill never applies fixes itself.

Two modes, two kinds of data:

- **This README — synthetic illustrations.** Every scenario below is shown
  with synthetic data only: shaped to trip the detectors, belonging to
  nobody (`123-45-6789`, `4111-1111-1111-1111`, `sk-testfakekey…`,
  `415-555-0132`). Never put real private data in `bin/fixtures/`.
- **A real run — real inputs and outputs.** `bin/leakage-report` runs the
  audit against your installation and the HTML report shows what was
  actually fed, what the gates actually returned, the findings, and the
  suggestions.

## Scenario catalog

### A. Installation integrity — is the protection layer actually installed?

| # | Scenario | Synthetic illustration | Expected |
|---|----------|------------------------|----------|
| A1 | Gate binaries exist and are executable | `ls bin/egress-gate bin/brief-gate bin/memory-egress-check` | all present, `+x` |
| A2 | All scripts parse | `bash -n bin/egress-gate` | no syntax errors — a gate that can't parse can't protect |
| A3 | Shim shadows the real CLI | `command -v hatch_gws_cli` → `…/bin/shims/hatch_gws_cli` | shim resolves first on `PATH` |
| A4 | Real binary reachable behind the shim | real `hatch_gws_cli` found later on `PATH` | shim can delegate after allowing |

### B. Red team — synthetic payloads at every gate and send path

Nothing is ever really sent: tests run against fake binaries, and every
blocked send must show the real binary was never invoked.

| # | Synthetic input | Target | Expected output |
|---|-----------------|--------|-----------------|
| B1 | `api_key: sk-testfakekey…` | `egress-gate` | `rc=1` — blocked |
| B2 | fake `-----BEGIN … PRIVATE KEY-----` block | `egress-gate` | `rc=1` — blocked |
| B3 | `my SSN is 123-45-6789` | `egress-gate` | `rc=1` — blocked |
| B4 | `charge card 4111-1111-1111-1111` | `egress-gate` | `rc=1` — blocked |
| B5 | `budget is $12,500 per month` | `egress-gate` | `rc=2` — refused without approval |
| B6 | `reach me at 415-555-0132` | `egress-gate` | `rc=2` — refused without approval |
| B7 | `confirming standup moved to 10am` (clean) | `egress-gate` | `rc=0` — passes, no false positive |
| B8 | all seven payloads above | `brief-gate` | `1 / 1 / 1 / 2 / 2 / 0 / 0` — briefs held to the same bar as sends |
| B9 | B1 body | gmail `+send` via shim | blocked, real binary silent (`invoked=0`) |
| B10 | B5 body | gmail `+send` via shim | refused (`rc=2`); with explicit approval → sent |
| B11 | B3 body | gmail `+reply` via shim | blocked — all send subcommands covered, not just `+send` |
| B12 | B4 inside base64-encoded MIME | raw `users messages send` | blocked — encoded payloads are decoded before the check |
| B13 | B1 body with `--draft` | gmail `+send --draft` | passes through — drafts never leave the account |
| B14 | B2 via stdin | messenger `send` via shim | blocked, real binary silent |
| B15 | B7 via stdin | messenger `send` via shim | allowed, stdin replayed byte-identical |
| B16 | `drive permissions create` | gws shim | refused (`rc=2`); with approval → allowed — sharing is never a free zone |
| B17 | `drive files list`, gmail `+triage` | gws shim | pass through — reads and own-Drive ops untouched |

`rc=1` = hard block (secrets, SSNs, cards). `rc=2` = needs the user's
explicit approval. `rc=0` = clean.

### C. Attack-surface coverage — is every path's control actually in place?

| # | Scenario | Illustration |
|---|----------|--------------|
| C1 | Agent manual mandates the shim `PATH` | static grep for the export line in the manual |
| C2 | Agent manual mandates brief gating | static grep for `brief-gate` in the manual |
| C3 | Briefing policy exists | `references/subagent-briefing.md` present |
| C4 | Free-share zones defined | `references/data-protection.md` defines the boundary |
| C5 | Cron prompts wire the shim `PATH` | every scheduled prompt statically checked |
| C6 | Memory audit green (opt-in) | `MOCHI_MEMORY_AUDIT=1` runs the memory skill's own audit |

### D. Audit-log review — what has the gate actually decided?

| # | Scenario | Synthetic illustration |
|---|----------|------------------------|
| D1 | Blocked attempts visible | log lines ending `\| BLOCKED` listed (synthetic contexts like `leakage-audit:…`) |
| D2 | Approval overrides surfaced | lines ending `\| approved-override` listed — the highest-risk events, for human review |
| D3 | Verdict distribution | counts per verdict — proves the gate is exercised, not bypassed |

### E. Known residuals — reported every run, never silent

| # | Scenario | Status |
|---|----------|--------|
| E1 | Browser-task sends (separate VM, shims can't reach) | policy-only: brief-level instruction |
| E2 | Absolute-path shim bypass | policy-only: forbidden by mandate, not technically preventable |
| E3 | Voice calls | out of text-gate scope: phone tool's own confirmation flow |
| E4 | Brief gating runs on mandate | no syscall interception for brief text |

## What a real run reports

`bin/leakage-report [--out PATH]` runs the audit and writes a
mobile-friendly HTML report. Per suite: a one-sentence green/red callout,
with the full per-check evidence expandable underneath — the real input
that was fed, the real output the gate returned, and, for every failure,
the finding plus a concrete suggested remediation. Exits with the audit's
exit code (0 = CLEAN).

For validation against **real data formats** (not synthetic), the
installation can additionally run a real-data verification: real
figures, addresses, and numbers through the real gates, reporting
verdicts per check. That harness must live outside this repo and never be
committed — this repo stays synthetic-only, always.

## Quickstart

```bash
git clone https://github.com/joonlim-official/muse-leakage-guard.git
cd muse-leakage-guard
cp local.env.example local.env   # gitignored; point PERSONAL_MEMORY_SKILL
                                 # at your memory-skill installation
bin/leakage-audit && bin/adversarial-run
```

What you need:

- A `personal-memory-system`-style installation to validate: the gates
  (`bin/memory-egress-check`), shims, and brief gate. Out of the box it
  looks next to itself at `~/workspace/skills/personal-memory-system`;
  set `PERSONAL_MEMORY_SKILL` (in `local.env` or the environment) to
  point anywhere else.
- `bash` + `python3`. No network. By default nothing is ever really sent —
  the red-team tests run against fake binaries and every blocked send
  verifies the real binary was never invoked.

What you get:

- `bin/leakage-audit` — five suites: installation integrity, red-team
  gate tests, attack-surface coverage, gate-log review, and the explicit
  residual-risk report. Exit 0 = CLEAN, exit 1 = failures, each with its
  evidence and a suggested remediation.
- `bin/adversarial-run` — detection performance: every payload in
  `bin/adversarial-corpus.txt` against the gates, want-vs-got per case.
  Fails closed on an empty or malformed corpus (a 0/0 pass is vacuous).
- `bin/leakage-report [--out PATH]` — a mobile-friendly HTML report of
  the audit: per-check inputs, outputs, findings, and suggestions.

Run the audit after any change to the protection layer — and on a
schedule. A protection nobody re-tests is a protection nobody has.

## Configuration

Configuration is entirely env-driven (see `local.env.example`) — no
personal paths are baked into the skill:

| Variable | Meaning | Default |
|---|---|---|
| `PERSONAL_MEMORY_SKILL` | memory skill under test | `~/workspace/skills/personal-memory-system` |
| `PERSONAL_MEMORY_ROOT` | memory root passed through to the gates | `~` |
| `MOCHI_CRON_PROMPT_DIRS` | dirs whose cron prompts must wire the shim `PATH` | unset (check skipped) |
| `MOCHI_MEMORY_AUDIT` | set to `1` to include the memory skill's own audit | `0` |
| `MOCHI_LIVE_FIRE` | set to `1` for live-fire mode (see below); must be set inline in the invoking environment — a value from `local.env` alone is ignored | unset (simulated) |
| `MOCHI_LIVE_FIRE_NONINTERACTIVE` | set to `1` to allow live-fire without a TTY (CI/automation); without it, non-interactive live-fire is refused | unset (refused) |
| `MOCHI_TEST_EMAIL` | live-fire email recipient — owner's own address only, verified against the Gmail profile before any send | **required** (no default) |
| `MOCHI_TEST_MESSENGER_CID` | live-fire Messenger target — must resolve to an owner-only chat | auto-discovered |

All test fixtures and corpus payloads are synthetic and impersonal —
shaped to trip the detectors, belonging to nobody. Never put real
private data in `bin/fixtures/` or `bin/adversarial-corpus.txt`.

## Live-fire mode (opt-in, owner's installation only)

The simulated red team proves the gates refuse bad sends — but nothing
ever really leaves the machine. Live-fire exercises the genuine
end-to-end path (shim → gate → real binary) with real sends:

```bash
MOCHI_LIVE_FIRE=1 MOCHI_TEST_EMAIL=<your own address> bin/leakage-audit
```

Rules, enforced by design:

- **Opt-in only, per invocation.** `MOCHI_LIVE_FIRE=1` must be set inline
  in the invoking environment — a value from `local.env` alone is ignored
  with a warning, so a stale config file can never arm real sends. Never
  export it. Without it, today's fake-binary behavior applies — safe for
  CI and external contributors. Live-fire is never the default.
- **No silent automation.** If stdin is not a TTY or `$CI` is set,
  live-fire is refused unless `MOCHI_LIVE_FIRE_NONINTERACTIVE=1` is also
  set explicitly — scheduled audits stay simulated.
- **Sends go to the owner only, ever.** `MOCHI_TEST_EMAIL` is required
  (there is no default) and must match the authenticated Gmail profile's
  address — the run fails closed on mismatch or when the identity cannot
  be determined. The Messenger target is auto-discovered as a chat whose
  *only* participant is the owner, and an explicit
  `MOCHI_TEST_MESSENGER_CID` that does not resolve to such a chat fails
  closed. Never point these variables at someone else's address.
- **Payloads stay synthetic.** The same fixtures as the simulated suite —
  nothing real, same invariant as everything else in this repo.
- **Small subset.** One block-tier, one approval-tier (explicit
  `MOCHI_EGRESS_APPROVED=1`), and one clean send per channel — not the
  full suite, to avoid inbox spam. Drive share tests stay simulated: a
  live run must never grant real access to anyone. When stdin is a TTY,
  the run pauses 10 seconds before the first real send — Ctrl-C aborts.
- **Live-fire means the genuine binaries.** Any stale
  `MOCHI_REAL_*_CLI` override is unset with a warning in the live-fire
  branch — a run that claims `LIVE-FIRE` must exercise the real path, not
  fake delegates.
- **Block-tier assertions are unchanged:** exit 1, and the real binary is
  never invoked. If a block-tier test ever arrives in your inbox, that is
  a real finding — report it, do not re-run.
- **The mode is always labelled.** The audit header, summary, and HTML
  report show `SIMULATED` vs `LIVE-FIRE` so a reader never mistakes one
  for the other.

Live-fire is for the owner's own installation. Contributors validating a
fork should stay in simulated mode.

## Layout

- `SKILL.md` — skill definition (for the agent).
- `bin/leakage-audit` — the validation runner.
- `bin/adversarial-run` — detection-performance runner over the corpus.
- `bin/adversarial-corpus.txt` — synthetic payloads with expected verdicts.
- `bin/fixtures/` — synthetic payloads only.
- `bin/leakage-report` — HTML report generator.
- `references/attack-surface.md` — enumerated leakage paths and controls.
- `references/test-matrix.md` — what each check proves, plus the
  scenario coverage map: every attack-surface scenario must have a row
  (the audit fails if one is missing).
- `hidden_files/reports/` — saved validation reports (gitignored).

## Adding a new exfiltration path

1. Add a row to `references/attack-surface.md`.
2. Add the control (gate or policy).
3. Add the test to `bin/leakage-audit` and a row to the coverage map in
   `references/test-matrix.md` (section F) — the audit fails until the new
   scenario is mapped.
4. Illustrate the scenario in this README with a synthetic example.

A path with no scenario is an unexamined path — the failure mode this
skill exists to prevent.
