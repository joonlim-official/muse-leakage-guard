# Iteration-6 review — Senior data scientist (05-data-scientist)

Repository: `~/workspace/skills/muse-leakage-guard` @ `5ff8950` "Iteration 5: honest green".
Review mode: READ-ONLY, full-repository, unlimited scope. No repo files were modified.
Method: read every script/doc in the harness path (`bin/*`, `test/stub-memory-skill/bin/*`,
`test/stub-memory-skill/build/*`, `.github/workflows/validate.yml`, corpus, fixtures,
`references/*`); reproduced the Clopper-Pearson bounds independently in Python;
executed `bin/leakage-audit` and `bin/adversarial-run` against the synthetic stub
under CI-equivalent conditions (no `local.env`, isolated `PERSONAL_MEMORY_ROOT`,
empty `MOCHI_CRON_PROMPT_DIRS`); diffed two audit runs for determinism.

## Verification summary (focus areas, answered)

- **Clopper-Pearson bounds: math is correct.** `ci_lower_95` in `bin/leakage-report`
  computes `0.025 ** (1.0 / n)` — the exact lower bound of the two-sided 95%
  Clopper-Pearson interval for the perfect `k == n` case. Reproduced independently:
  19/19 → 0.8235 (report shows ≥0.82), 9/9 → 0.6637 (≥0.66), 8/8 → 0.6306 (≥0.63).
  All match the claims in the brief. One labeling nit is filed below (P3).
- **Confusion matrix: construction verified.** Built from corpus `want` + parsed
  `MISMATCH` lines; non-standard verdicts (e.g. TIMEOUT) are listed separately,
  not forced into cells. The block-tier diagonal is tautological (the stub's
  blockset is derived from the want=1 cases) — honestly labeled as stub
  self-consistency in the report. No correction needed.
- **ML-metric language: fully cleaned.** Remaining hits are historical
  (`CHANGELOG.md`, `ITERATIONS.md` describing the iteration-5 removal) and
  explicit "not ML recall/precision" framing comments in code. The one live
  artifact is the CI summary's dead grep (P1).
- **CI summary should parse sentinels, not prose — yes.** The audit already emits
  `@@@ TOTAL` / `@@@ VERDICT` / `@@@ MODE` sentinels in the CI run, and the summary
  step already greps human text that one rename already broke (P1). Adding one
  machine line to `adversarial-run` and switching the summary to sentinels removes
  the entire class of prose-format drift.
- **Determinism: verified.** Two green audit runs in the same minute are
  byte-identical (`diff` empty). Report content varies only in the timestamp
  lines (header date, `TS` sentinel, report meta) and the output filename. Two
  green runs can be diffed meaningfully; the atomic `os.replace` write avoids
  half-written reports.
- **Circularity: real, by design, honestly labeled — but can be reduced.**
  See P3 below for an independent-extractor sketch that stays inside the
  pinned 36-case corpus.

---

### P0 — CI skip-set assertion fails under CI conditions (4 skips, expects 2)

**Evidence.** `.github/workflows/validate.yml:140-150` asserts
`[ "${#skip_lines[@]}" -eq 2 ]` with greps for `memory-audit run` and
`gate log not found`. But under true CI conditions (no `local.env`, empty
`MOCHI_CRON_PROMPT_DIRS`, no denylist on the runner) the audit deterministically
emits 4 skips — reproduced locally with CI-equivalent env:

```
@@@ CHECK SKIP cron prompt dirs not configured [set MOCHI_CRON_PROMPT_DIRS]
@@@ CHECK SKIP memory-audit run [set MOCHI_MEMORY_AUDIT=1 to include]
@@@ CHECK SKIP no egress denylist [/tmp/.../memory/.egress-denylist missing or empty]
@@@ CHECK SKIP gate log not found [/tmp/.../egress-gate.log (no sends attempted yet)]
@@@ TOTAL 57 0 4
```

The `[ 4 -eq 2 ]` test fails → the step exits 1 → the workflow fails. The
"honest green" HEAD was evidently validated on a machine where `local.env`
supplied cron dirs and a real `$HOME` supplied a denylist (my first local run
showed exactly 2 skips for that reason) — the CI path the repo advertises was
never exercised against this code.

**Recommendation.** Pin the full expected skip set (4, with a reason-name grep
per skip, preserving the "no silent new skips" intent), or configure the CI
environment with a synthetic denylist and a cron-prompt fixture dir so those two
checks run instead of skip. One focused diff either way.

**Residual if not fixed.** CI is red at HEAD on every run regardless of code
health; the "green CI proves harness self-consistency" claim has no working
gate behind it, and the assertion designed to catch silent skips is itself
silently untested in the environment that matters.

### P1 — CI summary greps dead human text (`block-tier recall`); silently a no-op

**Evidence.** `.github/workflows/validate.yml:156`:
`grep -aE 'block-tier recall' "${{ runner.temp }}/adversarial.log" | sed 's/^/- /' || true`.
Iteration 5 renamed the output; `bin/adversarial-run:86` now prints
`adversarial-run: block-tier pass 19/19 · review-tier pass 9/9 · clean pass 8/8`.
The grep matches nothing and `|| true` swallows the miss, so the per-tier line
silently disappears from the GitHub step summary — the exact prose-format-drift
failure mode iteration 5 was supposed to eliminate.

**Recommendation.** Switch the summary step to the `@@@` machine sentinels the
audit already emits in CI (`^@@@ TOTAL`, `^@@@ VERDICT`, `^@@@ MODE`), and add one
machine line to `adversarial-run` (e.g.
`adversarial-run: @@@ TIERS block 19 19 review 9 9 clean 8 8`) so no summary
content depends on human prose at all. This answers the brief's sentinel
question: yes — parse sentinels; the audit half already provides them.

**Residual if not fixed.** The next copy change in `adversarial-run` silently
drops summary content again, with no failure anywhere to notice.

### P2 — Gate timeout budgets differ between the two validation halves (30s vs 10s)

**Evidence.** `bin/leakage-audit:351,359` use `timeout 30` (`gate_expect`,
`send_expect`); `bin/adversarial-run:62` uses `timeout 10`. A detector that
answers in 11–29s passes every B-suite red-team check yet registers TIMEOUT in
the adversarial run — and the report then files it as a "non-standard verdict"
(`bin/leakage-report:366-370`), excluded from the 3×3 cell counts, rather than
as a mismatch.

**Recommendation.** One named timeout (e.g. `MOCHI_GATE_TIMEOUT`, single default)
used by both scripts; document the choice in the header comments.

**Residual if not fixed.** A slow gate can pass the plumbing half and fail the
conformance half, and the F card will under-report the severity (listed aside,
not counted as a miss).

### P3 — Malformed corpus lines are invisible in the HTML report's findings

**Evidence.** `bin/adversarial-run:56-59` prints `  MALFORMED %s: want=%s …` and
fails the run (exit 1), but `bin/leakage-report:251` only regex-matches
`MISMATCH` lines, and the per-case table builder (`bin/leakage-report:336-342`)
silently `continue`s on unparseable lines. A corrupted corpus yields an
ATTENTION badge with no itemized finding — only the raw transcript names the
line.

**Recommendation.** Extend the report's mismatch parsing to capture `MALFORMED`
lines as findings (counted in the mismatch column), in the same focused diff as
any report change.

**Residual if not fixed.** Corpus rot — the one failure mode that most needs an
itemized finding — is the one the report cannot itemize.

### P3 — Clopper-Pearson label should say "two-sided"

**Evidence.** `bin/leakage-report:297-304` (`ci_lower_95`) is mathematically the
lower bound of the exact **two-sided** 95% interval (verified by independent
reproduction: 0.8235 / 0.6637 / 0.6306). The rendered label
(`bin/leakage-report:350`) reads "Exact 95% CI lower bounds (Clopper-Pearson)"
without stating sidedness; a reader may reasonably read it as 95% one-sided
confidence, which would be `0.05 ** (1/n)` — slightly higher (0.854/0.717/0.688).

**Recommendation.** Label it "Exact two-sided 95% CI lower bounds
(Clopper-Pearson)". The `:.2f` display rounding (≥0.82 / ≥0.66 / ≥0.63) is fine
as-is.

**Residual if not fixed.** Minor over-read risk: a reader takes the printed
lower bound as stronger (one-sided 95%) than it is.

### P3 — Circularity: blockset is derived from the corpus it is tested against; an independent-extractor sketch

**Evidence.** `test/stub-memory-skill/build/build-blockset.sh:38-53` extracts
tokens from the corpus's want=1 cases (plus fixtures) with `patterns.sh` — the
same pattern file the stub's `memory-egress-check` uses at runtime
(`test/stub-memory-skill/bin/memory-egress-check:32-33`, and the build script's
own comment: "the SAME patterns the runtime detector uses, so the build and the
verdict can never disagree"). A bug in `patterns.sh` (a shape it silently fails
to extract) is invisible to the whole suite: build and runtime agree by
construction. This is legitimate for a self-consistency double and is labeled
honestly ("Stub consistency", never a protection claim) — but the circularity
is not anchored anywhere outside itself.

**Recommendation (stays inside the pinned 36-case corpus; no scope expansion).**
Anchor the blockset to the human-authored declaration instead of to pattern
extraction: in CI, assert that the sha256 set in `blockset.txt` equals exactly
the set of block-tier tokens declared in `bin/fixtures/SYNTHETIC.txt`
(requires marking which declared values are block-tier — e.g. a `BLOCK:`
prefix convention or a second manifest). A `patterns.sh` regression that
silently drops a token then surfaces as a hash-set mismatch instead of passing
`--check` silently. The corpus itself is untouched.

**Residual if not fixed.** `build-blockset.sh --check` proves self-consistency
only; a single shared-pattern failure mode can never be caught by this CI.

### P4 (info) — Near-miss negative traps that stress the harness without changing the pinned corpus

All verified by code reading; each is a concrete way the harness could be
exercised harder with zero corpus changes:

1. **Duplicate case names.** `bin/leakage-report:341` uses
   `next((m for m in mismatches if m[0] == name))` — only the first match wins;
   the per-case table would misattribute a second case of the same name.
   `adversarial-run` has no duplicate-name guard. Trap: add nothing — just
   note the harness should `exit 3` on duplicate case names (corpus integrity
   check, like the existing empty-corpus guard).
2. **`|` or newline inside a case name/content.** Both `adversarial-run:54`
   and `build-blockset.sh:40` split on `IFS='|'`; content containing `|`
   truncates at the split and a name containing `|` corrupts the build.
   Trap: reject such lines at parse time (exit 3, same as the malformed-want
   path).
3. **The 11–29s gate** (P2 above) — the two halves disagree on what "hung" means.
4. **MALFORMED corpus lines** (P3 above) — fail the run but are unitemized in
   the report.
5. **Interface-version drift.** `test/stub-memory-skill/.synthetic-stub`
   declares `interface_version=1` and `references/gate-interface.md` pins the
   contract, but `bin/leakage-audit` never asserts the declared version. A stub
   at interface version 2 (changed exit-code contract) would be tested as if it
   were v1. Trap: assert the declared version equals the version the audit
   implements; refuse on mismatch.

### P4 (info) — Determinism and report integrity: verified, no action

- Two green `leakage-audit` runs in the same minute are byte-identical
  (`diff` produced no output) under CI-equivalent conditions; suite order,
  check order, corpus order, and matrix construction are all fixed-order.
- The only run-varying content in the HTML report is timestamp lines (header
  date, `TS` sentinel, report meta) and the output filename — no PIDs, no
  ordering nondeterminism in findings or transcripts.
- Atomic report write via `os.replace` (`bin/leakage-report:659-661`) is good
  practice; kept.
- Sentinel forgery resistance (`msent` rewrites newlines and `@@@` in check
  text) is sound; check names originate from audit code, not external input.

## Priorities for one focused diff

1. Fix the CI skip-set assertion (P0) — the gate is red at HEAD.
2. Sentinel-based CI summary + one machine line from `adversarial-run` (P1) —
   fixes the dead grep and the whole prose-drift class.
3. Single shared gate timeout (P2); MALFORMED itemization (P3); two-sided CI
   label (P3); SYNTHETIC-anchored blockset check (P3); corpus duplicate-name /
   `|` guards and interface-version assertion (P4 traps) — all small,
   validation-only, no corpus changes.
