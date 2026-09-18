# Iteration-7 review — Senior data scientist (05-datascientist)

Repository: `~/workspace/skills/muse-leakage-guard` @ `e20a819` "Iteration 6: CI fails honest".
Review mode: READ-ONLY, full-repository, unlimited scope. No repo files were modified.
Nothing was run in live-fire mode (`MOCHI_LIVE_FIRE` never set); `local.env` untouched.
All payloads referenced are the repo's own synthetic fixtures, belonging to nobody.

Method: read every script/doc in the harness path (`bin/*`,
`test/stub-memory-skill/bin/*`, `test/stub-memory-skill/build/*`,
`.github/workflows/validate.yml`, corpus, fixtures, `references/*`); ran
`bin/adversarial-run` against the synthetic stub in simulated mode; reproduced
corpus-integrity edge cases (duplicate names, `|` in content, malformed lines,
dropped cases) against a throwaway copy of the runner in `/tmp` (repo untouched);
independently reproduced the Clopper-Pearson bounds in Python; diffed the
blockset hash set against the `SYNTHETIC.txt` declaration set; probed the two
shape-pattern definitions for drift with a synthetic spaced-Amex token.

## Verification summary (the six focus areas, answered)

- **Corpus-integrity guards: PARTIAL.** Malformed `want` values fail loudly
  (exit 1, `MALFORMED` to stderr) — but duplicate case names pass **silently**
  (verified: a duplicated `stripe_live` yields `37/37`, block tier inflates to
  `20/20`, exit 0), and malformed lines are **unitemized** in the report
  (see P1/P3 below). `|` inside case *content* is safe everywhere
  (bash `read` assigns the remainder to the last variable; the report uses
  `split("|", 2)`) — verified empirically with a piped block-tier token:
  `37/37` green. The iteration-6 concern about `|` in content was a false
  alarm for content; the real `|` hazard (name/want position) fails loudly
  as MALFORMED.
- **Blockset anchoring: holds by convention, fragile by construction.** All 21
  blockset hashes correspond to tokens declared in `bin/fixtures/SYNTHETIC.txt`
  (verified by hash-set diff), and newline guards prevent cross-case token
  fusion. But the build hashes **pattern-extracted** tokens (`patterns.sh`),
  not the declaration list, and the enforcement that "everything extracted is
  declared" is the audit's suite-C purity check — which uses a **second,
  manually-aligned** shape regex (`SHAPES` in `bin/leakage-audit`). Those two
  definitions already drift: a synthetic spaced-Amex token
  (`3782 822463 10005`-shaped) is extracted by `patterns.sh` but invisible to
  the audit's `SHAPES` (proven by direct test). See P2.
- **Near-miss corpus input: ABSENT.** No supplemental probe file, no
  probe-first workflow, no KNOWN-GAP entry path exists. The corpus tests only
  clear-cut class interiors; decision-boundary behavior (values at pattern
  thresholds) is unmeasured. See P3. (Also on the maintainer backlog:
  `ITERATIONS.md` "Near-miss negative traps (corpus stays pinned at 36
  unless revised)".)
- **CI labeling: mostly honest, one label wrong.** ML-metric language is fully
  cleaned ("not ML recall/precision" disclaimers only); the fixture framing
  ("36 author-designed regression fixtures — not a real-world sample") is
  present in adjacent prose. But the rendered bound label reads
  "Exact 95% CI lower bounds (Clopper-Pearson)" — **neither "two-sided" nor
  "fixture"** appears in the label itself (only in a code comment,
  `bin/leakage-report:234`). See P3.
- **Confusion matrix: complete axes, unexplained off-diagonals.** The 3×3
  (block/review/clean × rc 1/2/0) is built from corpus `want` + parsed
  mismatches; TIMEOUT verdicts are listed as non-standard text rather than
  forced into cells (good). But nonzero off-diagonal cells render as bare
  counts with **no interpretation guide**, axis labels are asymmetric
  (rows tier-named, columns code-only), and malformed lines are silently
  skipped from the table. See P3.
- **Pinned pass totals in CI: NO.** CI pins the skip set (exactly 4, with
  reason greps) but asserts **no** pass total: not the audit's `@@@ TOTAL`
  pass count, not the adversarial `36`, not the tier denominators `19/9/8`.
  Verified: dropping one review-tier case yields `35/35`, exit 0 — CI would
  be green. (Dropping a block-tier case is caught *indirectly* via
  `build-blockset.sh --check` staleness; review/clean drops are caught by
  nothing.) See P1.

---

### P1 — Duplicate corpus case names silently inflate tier denominators

**Evidence.** `bin/adversarial-run` has no duplicate-name guard (contrast the
explicit empty-corpus exit-3 guard at lines 93–97). Appending a second
`stripe_live|1|…` line to a scratch copy of the corpus and running against
the stub: `adversarial-run: 37/37 cases matched`, `block-tier pass 20/20`,
exit 0 — no warning. Downstream, `bin/leakage-report:440` resolves
per-case results with `next((m for m in mismatches if m[0] == name))`:
first match wins, so a mismatching duplicate is misattributed to the wrong
row (or masked entirely if the first occurrence matched).

**Recommendation.** Corpus-integrity check in the runner: track seen names,
`exit 3` (runner-failed, "unknown" — same severity class as the empty-corpus
guard) on the first duplicate, with a distinct stderr line and a machine
sentinel (e.g. `@@@ ADV DUPLICATE <name>`) so the report can itemize it.
Validation-only; corpus untouched.

**Residual if not fixed.** A copy-paste duplication inflates a tier's
denominator and its pass count together — the suite reports a stronger
result (20/20 instead of 19/19) while measuring less, and a genuine
mismatch on a duplicated name can be attributed to the wrong row.

### P1 — CI asserts the skip set but no pass total: silently dropped cases pass green

**Evidence.** `.github/workflows/validate.yml:165-197` pins exactly 4 skips
with reason greps — but nothing asserts the audit's `@@@ TOTAL` pass count,
the adversarial `36`, or the tier denominators (`19/9/8`). Demonstrated:
removing the `amex_15` line from a scratch corpus gives
`@@@ ADV MATCHED 35/35`, `block 18/18` (sic — here a block case was dropped;
for a review/clean drop the same holds with no other tripwire), runner
exit 0. The CI summary step (`validate.yml:280-292`) parses and *displays*
the sentinels but asserts nothing about them. The only indirect tripwire is
`build-blockset.sh --check` staleness, which fires solely for dropped
**block-tier** cases.

**Recommendation.** Extend the skip-set assertion step (or add a sibling)
to pin exact expected totals from the machine sentinels: audit
`@@@ TOTAL <p> <f> <s>` pass count, `@@@ ADV MATCHED 36/36`, and the tier
line `block 19/19 review 9/9 clean 8/8`. Any drift fails the job — the same
"no silent drops" intent that already motivates the pinned skips. (Also
closes the maintainer-backlog item "CI status/total assertions".)

**Residual if not fixed.** A deleted check in `leakage-audit` or a dropped
review/clean corpus case reduces coverage while CI stays green; the summary
would even print the reduced fraction (`35/35`) as if it were the full
suite.

### P2 — Timeout budgets still diverge between the two validation halves (30s vs 10s)

**Evidence.** `bin/leakage-audit:339,341,363` use `timeout -k 10 30`;
`bin/adversarial-run:72-74` uses `timeout -k 5 10`. A gate answering in
11–29s passes every suite-B red-team check yet registers TIMEOUT in the
adversarial run. TIMEOUT verdicts are then filed as "Non-standard verdicts"
text (`bin/leakage-report:485-486`), **excluded from the 3×3 cell counts** —
a slow gate's misses are listed aside, not counted as misses. (Iteration-6
P2, re-filed: iteration 6 added `timeout -k` but did not unify the
budgets.)

**Recommendation.** One named timeout (e.g. `MOCHI_GATE_TIMEOUT`, single
default, documented in both header comments) used by both scripts; TIMEOUT
verdicts already surface as `@@@ ADV MISMATCH … got=TIMEOUT` and land in
the findings list — keep that, and additionally count non-standard
verdicts in the mismatch column so the F-card totals reconcile with the
per-case table.

**Residual if not fixed.** The plumbing half and the conformance half
disagree on what "hung" means; the F card under-reports the severity of a
slow gate (narrated aside instead of counted).

### P2 — Blockset is pattern-extracted, not declaration-anchored; the two shape definitions drift

**Evidence.** `test/stub-memory-skill/build/build-blockset.sh` hashes tokens
extracted by `patterns.sh` from corpus want=1 cases + fixtures — it never
reads `bin/fixtures/SYNTHETIC.txt`. The only enforcement that extracted
tokens are declared-synthetic is the audit's suite-C purity check, which
uses its own `SHAPES` regex (`bin/leakage-audit`, fixture-purity section).
These are two manually-aligned definitions, and they already disagree:
a synthetic spaced-Amex-shaped token is extracted by `patterns.sh`
(`\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b`) but matches nothing in
the audit's `SHAPES` (`\b3[47][0-9]{13}\b` — no separators). Proven by
direct test on both patterns. Today the sets coincide (all 21 blockset
hashes are declared — verified by hash-set diff), so this is a latent
fragility, not an active leak; but a future fixture in a shape one
definition sees and the other doesn't would enter `blockset.txt` while
suite C stays green. (Iteration-6 P3, re-filed with an empirical drift
proof; also the maintainer-backlog item "Independent extractor/blockset
ground truth".)

**Recommendation (validation-only, corpus untouched).** Add a CI check that
the two extractors agree on every fixture/corpus token — e.g. run
`patterns.sh` extraction and the audit `SHAPES` extraction over the same
inputs and fail on symmetric difference — or anchor the build to the
declaration list (hash exactly the block-tier-marked entries of
`SYNTHETIC.txt`, requiring a tier marker convention). Either is one
focused diff.

**Residual if not fixed.** `build-blockset.sh --check` proves
self-consistency only; a shape the shared pipeline mis-handles is invisible
to the whole suite by construction, and the "all fixture values are
declared synthetic" audit claim rests on whichever of the two pattern sets
happens to be narrower.

### P3 — MALFORMED corpus lines fail the run but are unitemized and corrupt the sentinel's units

**Evidence.** `bin/adversarial-run:66-70` prints `MALFORMED …` to stderr and
increments `fail` (exit 1 — good), but emits **no** `@@@ ADV MISMATCH`
sentinel for them, so `bin/leakage-report` cannot itemize them as findings.
Worse, malformed lines are counted in `total` but in no tier denominator:
`@@@ ADV MATCHED 36/38` (demonstrated with two malformed lines appended)
mixes "valid cases matched" with "lines seen including unevaluated ones"
in one fraction. And the report's per-case table builder
(`bin/leakage-report:436-438`) silently `continue`s on unparseable lines,
so the table and confusion matrix sum to 36 while the sentinel says /38 —
three numbers that don't reconcile. (Iteration-6 P3, re-filed; persists
at HEAD.)

**Recommendation.** Emit a distinct sentinel for malformed lines
(e.g. `@@@ ADV MALFORMED <name> want=<w>`), keep them out of the
`MATCHED <p>/<t>` denominator, and render them as findings entries in the
report — corpus rot is the failure mode that most needs itemization.

**Residual if not fixed.** A corrupted corpus yields an ATTENTION badge
with no itemized finding; only the raw transcript names the line, and the
headline fraction is unit-confused.

### P3 — The 95% CI label says neither "two-sided" nor "fixture"

**Evidence.** `bin/leakage-report:463` renders
"Exact 95% CI lower bounds (Clopper-Pearson)". The math is correct —
independently reproduced: the perfect-case lower bound `0.025 ** (1/n)`
is the exact **two-sided** 95% Clopper-Pearson bound
(19/19 → 0.8235, 9/9 → 0.6637, 8/8 → 0.6306; the `:.2f` display is fine).
But "two-sided" appears only in the code comment (`:234`), and the word
"fixture" appears nowhere in the label — the fixture framing
("author-designed regression fixtures — not a real-world sample") lives in
adjacent prose. A reader may reasonably read the bound as one-sided 95%
(`0.05 ** (1/n)` — slightly higher: 0.854/0.717/0.688) or as a population
claim. (Iteration-6 P3, re-filed; persists at HEAD.)

**Recommendation.** Label it "Exact two-sided 95% fixture-CI lower bounds
(Clopper-Pearson)". One string change.

**Residual if not fixed.** Minor over-read risk in both directions:
stronger confidence (one-sided) or broader generality (population recall)
than the number warrants.

### P3 — Confusion matrix has complete axes but unexplained off-diagonal cells

**Evidence.** `bin/leakage-report:472-483` builds the 3×3 from corpus `want`
+ parsed mismatches; non-standard verdicts are listed as text (good).
But a nonzero off-diagonal cell — the exact evidence of a protection
failure — renders as a bare count with no interpretation: nothing tells
the reader that expected-block/got-review means under-blocking, or
expected-clean/got-block means a false positive. Axis labels are also
asymmetric (rows "block-tier (want rc=1)", columns bare "got rc=1").

**Recommendation.** Add a one-line legend under the matrix mapping each
off-diagonal cell to its plain-language meaning
(e.g. "expected block, got review → detector under-blocked; expected
clean, got block → false positive"), and use symmetric tier names on both
axes. Validation-only, report-side.

**Residual if not fixed.** In a red run — the moment the matrix matters
most — the reader gets counts without a guide to what each failure cell
means.

### P3 — Declared interface version is never asserted

**Evidence.** `test/stub-memory-skill/.synthetic-stub` declares
`interface_version=1`; `references/gate-interface.md:6` documents the
contract. `bin/leakage-audit` never reads or asserts it. A stub at a
future interface version (changed exit-code contract) would be tested as
if it were v1, and every verdict comparison could be silently wrong.
(Iteration-6 P4 trap 5, re-filed; persists at HEAD.)

**Recommendation.** In suite A, read the declared `interface_version` and
refuse (`bad`, fail-closed) on mismatch with the version the audit
implements. One focused diff, validation-only.

**Residual if not fixed.** A contract-drifted test double produces
verdicts the harness misreads as v1 semantics — silent mismeasurement.

### P3 — No near-miss / boundary-probing harness (methodology gap)

**Evidence.** No supplemental probe file, probe runner, or KNOWN-GAP entry
path exists anywhere in the repo (searched `bin/`, `references/`,
`.github/`). The 36-case corpus covers only clear-cut class interiors:
values comfortably above pattern thresholds (block), obvious figures/
phones (review), benign text (clean). Decision-boundary behavior — a
15-char vs 16-char `api_key` value, `$9` vs `$10`, a 9-digit vs 10-digit
number, a key prefix with a truncated body — is where real-world false
positives and false negatives actually live, and it is unmeasured.

**Recommendation (probe-first, corpus stays pinned at 36).** Add a
supplemental near-miss probe list (separate file, explicitly *not* part of
the pinned corpus) plus a probe runner: each candidate is run against the
real gate, and any expectation mismatch becomes a **KNOWN-GAP entry**
(surfaced in suite E / the report as a tracked residual), never a failing
corpus case. This matches the brief's required methodology and the
maintainer-backlog item "Near-miss negative traps (corpus stays pinned at
36 unless revised)". Do not gate CI on probe outcomes until the gap log
has stabilized.

**Residual if not fixed.** The suite measures the interior of each class
but never the boundary between block-tier and review-tier — the exact
region where detector tuning errors (over/under-blocking) manifest.

---

## Verified sound — no action (P4 info)

- **Clopper-Pearson math correct.** `0.025 ** (1/n)` is the exact two-sided
  95% lower bound for the perfect `k == n` case; independently reproduced
  0.8235 / 0.6637 / 0.6306. Tiers that are imperfect or empty get no
  number — the honest choice.
- **`|` in case content is safe.** Bash `read` remainder semantics and the
  report's `split("|", 2)` handle pipes in content identically; verified
  empirically (`37/37` with a piped block-tier token). The iteration-6
  worry about content pipes was a false alarm; the real `|` hazard
  (name/want position) fails loudly as MALFORMED.
- **ML-metric language fully cleaned.** Remaining hits are the explicit
  "not ML recall/precision" disclaimers and historical CHANGELOG/
  ITERATIONS.md entries describing the iteration-5 removal.
- **Blockset ⊆ declarations holds today.** Hash-set diff: all 21 blockset
  entries are declared in `SYNTHETIC.txt`. (Two declared tokens are
  correctly absent from the blockset: the 10-digit confirmation number from
  the clean `order_num` case, and the bare `sk-test…` form that only ever
  appears with its `api_key:` prefix in fixtures — the extractor hashes the
  prefixed form. Both are by-design, not findings.)
- **Newline/fusion guards are real.** Corpus cases are hashed one line at a
  time; fixture concatenation forces trailing newlines in both the build
  script and the stub's multi-file input path.
- **Sentinel forgery resistance** (`msent` newline/`@@@` rewriting) and the
  **timeout `-k`** hardening from iteration 6 are sound as implemented.

## Priorities for one focused diff

1. Pin pass totals in CI alongside the pinned skips (P1) — the cheapest
   close of the largest silent-green hole.
2. Duplicate-name corpus guard with exit 3 + sentinel (P1).
3. Unify the gate timeout; count non-standard verdicts as misses (P2).
4. Cross-check the two shape extractors (or anchor the blockset to
   declarations) (P2).
5. Itemize MALFORMED lines with their own sentinel (P3); fix the CI label
   to "two-sided fixture-CI" (P3); off-diagonal matrix legend (P3);
   interface-version assertion (P3).
6. Probe-first near-miss harness feeding KNOWN-GAP entries, corpus
   untouched at 36 (P3 methodology).
