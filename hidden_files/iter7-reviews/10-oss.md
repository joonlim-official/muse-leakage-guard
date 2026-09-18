# Iteration-7 review — Open-source community maintainer (10-oss)

Repository: `~/workspace/skills/muse-leakage-guard` @ `e20a819` ("Iteration 6:
CI fails honest"). Review-only; all runs below were simulated mode against
the bundled synthetic stub. No files modified, `MOCHI_LIVE_FIRE` never set,
`local.env` untouched. All fixtures cited are synthetic shapes belonging to
nobody.

Method: read README, CONTRIBUTING, SKILL.md, LICENSE, `.github/` (workflow,
CODEOWNERS), `references/` (attack-surface, test-matrix, gate-interface),
`test/stub-memory-skill/README.md`, `bin/adversarial-corpus.txt` header,
`local.env.example`, `.gitignore`; ran the README stub-first quickstart
verbatim in simulated mode; ran the audit once *without* the inert-delegate
block to test the CONTRIBUTING failure mode.

## Findings

### HIGH

#### H1. No SECURITY.md — no responsible-disclosure path for a security-adjacent repo
- **Severity:** High
- **Evidence:** Repo root listing (`README.md`, `CONTRIBUTING.md`, `SKILL.md`,
  `LICENSE`, `CHANGELOG.md`, `ITERATIONS.md` — no `SECURITY.md`); `find . -iname
  "*secur*"` matches only `hidden_files/iter{N}-{briefs,reviews}/01-security.md`
  (internal iteration notes, not a contributor-facing policy).
- **Why it matters:** This repo's entire purpose is validating a leakage-
  protection layer. A harness bug (report dishonesty, a fixture that isn't
  really synthetic, a delegate actually being invoked on a block-tier send)
  *is* a security issue in context — and the repo's own catalog (attack-
  surface.md B2) documents that a real private-data leak through this repo
  has happened before. Today a researcher has no documented private channel
  and no stated scope/timeline, so vulns arrive as public issues or not at
  all. CODEOWNERS routes everything to `@joonlim-official`, but that is a
  review assignment, not a disclosure policy.
- **Recommendation:** Add `SECURITY.md` with: (1) how to report privately
  (maintainer contact or GitHub private vulnerability reporting, with a note
  on whether it is enabled for this repo); (2) what counts as a security
  issue here (harness bugs that could mask a real leak, fixture-purity
  failures, report-honesty bugs) vs. what is a normal bug; (3) expected
  response timeline; (4) the standing rule that reporters must never use
  real private data in a proof of concept — synthetic fixtures only, per the
  repo's own fixture-purity discipline.
- **Residual if not fixed:** Harness vulnerabilities get disclosed publicly
  by default (or are never reported); a silent-failure bug can circulate
  with the repo's green CI badge as false assurance.

### MEDIUM

#### M1. README residual table is a stale 4-row subset of the 9 residuals the audit reports — and its E-numbering collides with the attack-surface catalog
- **Severity:** Medium
- **Evidence:**
  - `README.md` "### E. Known residuals — reported every run, never silent"
    has 4 rows: E1 browser-task sends, E2 absolute-path bypass, E3 voice
    calls, E4 brief-gate-on-mandate.
  - `bin/leakage-audit` lines 622–636 (suite E) emits **9** bullets every
    run — adding compositional/chunked exfiltration, out-of-band egress
    (curl/webhooks/unshimmed CLIs), the A7 static-check caveat, bare-9-digit
    SSN (E3), and attachment inspection (B4). The README table omits 5 of 9.
  - `references/test-matrix.md` section E prose likewise lists only the 4.
  - `references/attack-surface.md` section E is a *different* E-namespace:
    E1 over-gating, E2 stub-mistaken-for-real-protection, E3 bare-9-digit
    SSN. So README "E3" = voice calls, catalog "E3" = bare-9-digit SSN —
    and `bin/leakage-audit:631` references "scenario E3" meaning the
    catalog's. The corpus header already has to disambiguate explicitly
    ("see E1 in references/attack-surface.md"), proving contributors hit
    this collision.
- **Recommendation:** Canonicalize the E-numbering on the attack-surface
  catalog (it is the doc the code and corpus cite); in the README, either
  drop the E-numbers from the residual table or renumber it as a distinct
  namespace (e.g. R1–R9), and sync the table to all 9 residuals the audit
  actually reports every run. Mirror the 9-bullet list in test-matrix.md
  section E prose at the same time.
- **Residual if not fixed:** A contributor cross-referencing "E3" across
  docs lands on the wrong scenario; the README understates the residuals a
  reader is promised are "reported every run, never silent".

#### M2. CONTRIBUTING quickstart is not copy-paste-able verbatim on a fresh machine
- **Severity:** Medium
- **Evidence:** `CONTRIBUTING.md` "Quickstart (stub-first, no private setup)":
  (a) step 1 runs `export PERSONAL_MEMORY_SKILL="$PWD/test/stub-memory-skill"`
  with no `git clone` / `cd muse-leakage-guard` preamble — it assumes the
  reader is already in the repo root; a newcomer reading CONTRIBUTING from
  the GitHub web UI starts in the wrong directory. (b) The "second
  executable CLI behind each shim" requirement is a prose comment
  ("# 2. The audit needs a second executable CLI behind each shim on PATH.
  (In CI these are inert fakes; …)") with no paste-able inert-delegate
  block — the README quickstart has one, CONTRIBUTING does not.
  Empirically verified: running the audit with shim dirs on PATH but no
  delegate binary behind them → `Total: 58 passed · 2 failed · 1 skipped`,
  `VERDICT: ATTENTION`, exit 1 ("shim has nothing to delegate to …
  extend PATH so the shim has a delegate"). The README's paste-able block
  was verified to work: `Total: 60 passed · 0 failed · 1 skipped`,
  `VERDICT: CLEAN`, exit 0.
- **Recommendation:** Mirror the README's inert-delegate block into
  CONTRIBUTING (or extract one shared snippet both docs include), and add
  the `git clone` + `cd` preamble so the block runs verbatim top-to-bottom.
- **Residual if not fixed:** First-run friction — a newcomer following
  CONTRIBUTING verbatim gets a red audit with no in-doc remediation and may
  conclude the harness is broken on their machine.

#### M3. Exit-code documentation is fragmented; `rc=124` is undocumented for contributors
- **Severity:** Medium
- **Evidence:** Gate codes 0/1/2 are documented in `references/gate-interface.md`
  (plus shim exit 127 = no delegate, fail closed) and in the README's B-table.
  But harness-level codes live only in code: every gate invocation is wrapped
  in `timeout -k 10 30` and `rc=124` is the fail-closed timeout path
  (`bin/leakage-audit:334–347`, `bin/adversarial-run:72–76`,
  `bin/leakage-report:46`); `adversarial-run` exits 0/1/2/3
  (`bin/adversarial-run:46,58,97,106`); `leakage-report` exits 0/1/2/3
  (`bin/leakage-report:44–54`). No single document lists the audit /
  adversarial-run / leakage-report exit codes, and `rc=124` appears nowhere
  in prose. Worse, `SKILL.md` *mis-describes* leakage-report's exit 3 as
  "the report itself could not be trusted (unparseable output) and no HTML
  is written" — the code's exit 3 is a **timeout** ("audit timed out after
  600s (gate hung); no report generated"). SKILL.md also omits that exit 1
  still writes the report (CI relies on it) and does not define exit 2
  there.
- **Recommendation:** Add one "Exit codes" reference — `references/gate-
  interface.md` (for gate/shim codes incl. 124 and 127) or a README section
  (for audit 0/1/2, adversarial-run 0/1/2/3, leakage-report 0/1/2/3, and
  what rc=124 means at each layer). Fix SKILL.md's exit-3 description to
  match the code.
- **Residual if not fixed:** Contributors debugging CI redness or a hung
  gate misread exit 3 as report corruption instead of a timeout, and chase
  the wrong layer.

#### M4. No issue/PR templates; no documented corpus-case proposal methodology or false-positive reporting path
- **Severity:** Medium
- **Evidence:** `.github/` contains only `workflows/validate.yml` and
  `CODEOWNERS` — no `ISSUE_TEMPLATE/` and no `pull_request_template.md`.
  `CONTRIBUTING.md` mentions the corpus only in the PR checklist
  ("`test/stub-memory-skill/build/build-blockset.sh --check` passes (if you
  touched the corpus or stub fixtures)"). There is no "Adding a corpus case"
  section describing the probe-first methodology (propose the probe, declare
  the token in `bin/fixtures/SYNTHETIC.txt` *first* per the fixture-purity
  rule, add the `name|want_rc|content` row, rebuild/verify the blockset),
  and no guidance on how to report a false positive (which corpus case,
  want-vs-got, the fixture text that triggered it). The corpus *format* is
  documented in the `bin/adversarial-corpus.txt` header, but a first-time
  contributor has no entry point from CONTRIBUTING or the README.
- **Recommendation:** Add a minimal issue template for corpus-case proposals
  and false-positive reports (fields: corpus case name, want-vs-got, trigger
  text, synthetic-only attestation), and a short CONTRIBUTING section
  "Proposing a corpus case" that walks the probe-first flow end to end.
- **Residual if not fixed:** Corpus contributions arrive malformed (missing
  SYNTHETIC.txt declaration → fixture-purity failure in CI) or never arrive;
  false positives get reported as unstructured text that cannot be triaged
  into corpus cases.

### LOW

#### L1. SKILL.md usage line points at a `reports/` directory that does not exist
- **Severity:** Low
- **Evidence:** `SKILL.md` Usage: "A report is printed to stdout; save it with
  `bin/leakage-audit | tee reports/<date>.md`." There is no `reports/`
  directory in the repo (`.gitignore` keeps only `reports/*` +
  `!reports/.gitkeep` placeholders). The actual report path is
  `hidden_files/reports/leakage-validation-<timestamp>.html`, written by
  `bin/leakage-report` (`bin/leakage-report:31–32`) and documented in the
  README layout section. A contributor following the line gets a `tee`
  failure on a missing directory.
- **Recommendation:** Point the line at `hidden_files/reports/` or drop it
  (the report generator is the supported report path).
- **Residual if not fixed:** Cosmetic doc rot in the Usage section — small,
  but it is the section a newcomer reads first.

#### L2. README tagline leans on the word "proves"
- **Severity:** Low
- **Evidence:** README tagline: "A validation skill for AI-assistant
  private-memory leakage protection. It doesn't protect anything itself —
  it **proves the protection works**". The qualification is present, and the
  repo has done the honest work elsewhere (CI section's "What green CI
  proves / does not prove", catalog E2, report banners, stub README's
  "36/36 proves harness self-consistency — nothing more"). But "proves" is
  the strongest possible verb and it sits in the first thing a skimmer
  reads; SKILL.md repeats it ("it *proves* the protection works, and finds
  the holes").
- **Recommendation:** Soften to the honest verb the repo already uses
  elsewhere: "it audits the protection and finds the holes" (or "red-teams
  the protection").
- **Residual if not fixed:** A skimming reader quotes the tagline as a
  security guarantee. Mitigated today by every other surface in the repo —
  which is why this is Low, not higher.

## Checked and clear (no finding)

- **LICENSE:** MIT present (added iteration 5), `Copyright (c) 2026 Joon Lim`.
  No per-file license headers exist in any shipped script/doc, and no project
  convention requires them (no SPDX/Copyright header anywhere outside LICENSE
  and a CHANGELOG line) — no violation.
- **B18/B19 catalog rows:** do not exist anywhere (brief lead was a negative).
  Catalog B in `references/attack-surface.md` is "Sharing and publishing"
  B1–B4; the README's B1–B17 red-team table maps to audit suite B. No rows
  missing — though note this is the same dual A–E namespace issue as M1: the
  README "Scenario catalog" mirrors the *audit suites* A–E while
  attack-surface.md uses A–E for *leakage paths*. Consider stating the mapping
  once in the README intro.
- **Corpus count claims:** "36/36" claims in SKILL.md, attack-surface.md,
  gate-interface.md match reality — 36 non-comment lines in
  `bin/adversarial-corpus.txt`.
- **Config surface:** `local.env.example` matches the README configuration
  table variable-for-variable; `.gitignore` covers `local.env` and both
  report directories; `local.env` is not committed.
- **README quickstart (simulated):** verified end-to-end — `60 passed ·
  0 failed · 1 skipped`, `VERDICT: CLEAN`, exit 0 against the stub with the
  documented inert-delegate block. The quickstart works; the gap is that
  CONTRIBUTING does not carry the same block (M2).
