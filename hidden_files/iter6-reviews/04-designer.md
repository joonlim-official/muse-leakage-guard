# Iteration-6 review — Senior designer

Repo: `~/workspace/skills/muse-leakage-guard` @ 5ff8950 ("Iteration 5: honest green").
Read-only review; no repo files modified.

## Method
- Generated three fresh reports with HEAD code (all into `/tmp/iter6-review/`,
  none written into the repo):
  - `stub-report.html` — documented stub setup (`PERSONAL_MEMORY_SKILL=test/stub-memory-skill`,
    stub shims + inert delegate CLIs on PATH). Exit 0, CLEAN, 36/36.
  - `real-report.html` — real installation (`~/workspace/skills/personal-memory-system`),
    SIMULATED mode. Exit 0, CLEAN, 36/36.
  - `red-report.html` — a *scratch copy* of the repo in `/tmp/red-sim` whose
    stub `memory-egress-check` was forced to `exit 0`, run against the copied
    stub skill. Genuine ATTENTION report: badge ATTENTION, 47 findings,
    B card 19/31 failed, F card 28/36 mismatched.
- Screenshotted in headless Chrome (`~/workspace/.local/chrome/chrome-linux64/chrome`,
  `--headless=new --disable-gpu --no-sandbox`): desktop 1280px, mobile 390px,
  dark mode. Cropped the red report's B card (tri-state groups on the failure
  path) and F card (confusion matrix + CI line).
- Read `bin/leakage-report` end to end, the CI workflow's summary step, and
  diffed iter5's findings list against HEAD to verify which carried over.
- Privacy: no personal details involved; all payloads synthetic. Evidence
  review confirms **no secret-shaped payload contents appear anywhere in the
  report** — evidence shows only check labels, case names (`stripe_live`,
  `ssn_dash`, …), fixture filenames, and `rc=`/`want`/`got` codes.

## Positives (keep)
- **Stub vs real distinction is unmistakable**: purple "SYNTHETIC STUB TARGET"
  banner directly under the mode bar, `target-kind: SYNTHETIC STUB` in the
  hero meta, "(synthetic stub)" in the `<title>`, and a restating footer. The
  real-target report correctly shows none of these and renders the F card
  green instead of purple.
- **Auto-expand works**: on the red report the B and F cards render open on
  load (chevron rotated, `aria-expanded="true"`), findings link to
  `#card-B` / `#card-F`, and the Findings section sits first inside `<main>`.
  The "what do I look at first" journey lands correctly.
- **Legend is clear and honest**: tri-state (🟢 well protected / 🟡 protected
  through approval / 🔴 can leak) plus 🟣 stub self-consistency and ⚪ tracked
  residual, each with the rc code attached. Dark mode is coherent throughout.
- **CI bounds stated plainly**: "interval not computed (0/19)" rather than a
  made-up number — the honesty principle survives the edge case.
- **Fixture-conformance language holds**: "pass rates over author-designed
  regression fixtures — not a real-world sample, and not ML recall/precision"
  appears adjacent to the figures.

## Findings

### P1 — Tri-state evidence groups collapse on the red path: all failures land in "Other evidence"
**Severity:** P1
**Evidence:** `bin/leakage-report:328` (`tri_state_groups` keys off
`re.search(r"rc=(\d)", c["text"])` only). In the red report, failed B checks
read `[B] egress gate: fake api key blocked` (text) with `want rc=1, got rc=0`
in the *evidence* line — so all 19 failures fell into "Other evidence";
"Hard-block evidence" vanished entirely (verified: 0 occurrences in the red
report, present in the green one). The audit's `bad()` (`bin/leakage-audit:152`)
never puts rc in failed check text, so the grouping is guaranteed to fail on
exactly the runs where tier framing matters most. The red B card shows
"Approval-gated evidence (1 pass)", "Pass-through evidence (12 passes)",
"Other evidence (19 failures)" — the protection-tier story is inverted: the
failures look unclassified.
**Recommendation:** In `tri_state_groups`, fall back to the first evidence
line when the text has no `rc=` match (`re.search(r"rc=(\d)", c["text"] or "") or re.search(r"want rc=(\d)", c["ev"][0] if c["ev"] else "")`). One-line change, no scope expansion.
**Residual if not fixed:** On every red report the suite-B evidence reads as an
undifferentiated failure list; a reader cannot tell at a glance whether the
gate stopped blocking (rc=1 failures) or stopped gating on approval (rc=2
failures) — the two failure modes with completely different severity.

### P2 — Findings duplicate the suite letter: "[B] [B] egress gate: …"
**Severity:** P2
**Evidence:** Red report Findings section: every B finding renders
`[B] [B] egress gate: fake api key blocked`. Root cause: `bad()` in
`bin/leakage-audit:152` prefixes failed check text with `[$SUITE_LETTER]`,
and `bin/leakage-report:309` prepends `[B]` again
(`f"[{s['letter']}] {scrub(c['text'])}"`). Passes (single prefix, in-card) are
unaffected — this only shows on the failure path, i.e. exactly when the
Findings section is the reader's entry point.
**Recommendation:** Strip a leading `\[[A-Z]\] ` from `c["text"]` before
prepending the suite letter in the findings builder.
**Residual if not fixed:** The top-of-report entry point on every red report
reads as a rendering bug, undermining trust in the findings list.

### P2 — CI step summary is not failure-diagnosable, and silently drops the tier line
**Severity:** P2
**Evidence:** `.github/workflows/validate.yml:146-157`. (a) The summary greps
`'block-tier recall'` (line 156) but `bin/adversarial-run:86` prints
`block-tier pass 19/19 · …` — the pattern **never matches**, so the tier
breakdown is silently absent from every CI summary (`|| true` swallows it).
It also uses "recall" terminology the report deliberately disavows
("not ML recall/precision"). (b) On a red run the summary shows only
`- Audit: Total: …` and `- Adversarial: …` — no verdict word (the log has
`VERDICT: ATTENTION`), no failing check names, no `MISMATCH` lines. An author
cannot tell *what* failed without leaving the summary.
**Recommendation:** Fix the pattern to `'block-tier pass'` (and use "pass"
wording); add a `VERDICT:` grep line; append the first ~10 `MISMATCH` lines
and `@@@ CHECK FAIL` lines. All from existing log files — no new scope.
**Residual if not fixed:** The designed CI surface tells the author "something
failed" without saying what; the tier figures the project cares about never
appear in CI.

### P2 — Red CI runs never upload the HTML report (generate step lacks `if: always()`)
**Severity:** P2
**Evidence:** `.github/workflows/validate.yml`: "Run the leakage audit" fails
on findings (`set -o pipefail` + audit exit 1); "Generate the HTML validation
report" and everything between it and "Summarize" have the default
`if: success()`, so they are **skipped on red**. Only "Upload" and "Summarize"
carry `if: always()` — and Upload then finds no file. The readability-designed
artifact exists only when nothing is wrong. (`leakage-report` itself writes the
report on exit 1 — "report still written" per its usage text — the workflow
just never lets it run.)
**Recommendation:** Add `if: always()` to the generate-report and
adversarial-run steps (the audit log already exists; `leakage-report` exits 1
but writes the file — gate the step on the file's existence or allow the
exit-1 via `|| true` after confirming the report was written).
**Residual if not fixed:** On a failing PR the author gets no artifact and a
summary with no failing names (see previous finding) — the failure must be
diagnosed from the raw step log.

### P2 — Confusion matrix: off-diagonal cells are visually identical to the diagonal, and nothing adjacent explains what off-diagonal means
**Severity:** P2
**Evidence:** Red report F card, "Expected vs actual exit code (3×3)": cells
`19` (block→got rc=0) and `9` (review→got rc=0) render in the same plain
style as the diagonal `8`. The only explanatory text nearby is the
fixture-conformance note; nothing says "numbers outside the top-left →
bottom-right diagonal are cases where the gate behaved unexpectedly."
The top legend defines rc codes but is far above the card. On a green report
the matrix is diagonal-only so this is invisible — it only bites on red.
**Recommendation:** Shade off-diagonal cells (light red tint + bold, reusing
`--bad`), and add one sentence above the table: "Counts on the diagonal are
cases that behaved as expected; anything off the diagonal is an unexpected
gate verdict."
**Residual if not fixed:** A non-technical reader sees a grid of numbers with
no way to tell which cells are bad — the matrix fails its one job on a red
report.

### P2 — CI bounds line has no plain-language gloss ("clean ≥ 0.63 (8/8)" reads as a contradiction)
**Severity:** P2
**Evidence:** Green stub report F detail:
"Exact 95% CI lower bounds (Clopper-Pearson): block-tier ≥ 0.82 (19/19) ·
review-tier ≥ 0.66 (9/9) · clean ≥ 0.63 (8/8)." A non-technical reader's first
question is "8/8 passed but the number is 0.63 — is something wrong?" Nothing
adjacent answers it. The code comment explains the small-n rationale, but the
rendered page does not.
**Recommendation:** Append one clause: "…i.e. with 8/8 passing we are 95%
confident the true conformance rate is at least 0.63 — small fixture sets
give wide intervals even at full pass rates."
**Residual if not fixed:** Readers either misread the bound as a failure or
ignore the line entirely; the careful statistics work doesn't land.

### P2 — F-card subtotal double-framing persists (iter5 P3 carryover)
**Severity:** P2
**Evidence:** Stub report: F card subtotal "36 passed · 0 failed · 0 skipped";
Total card "60 passed · 0 failed · 1 skipped" plus "adversarial: 36/36
matched". A reader adding cards gets 96; a reader trusting the total wonders
where the 36 went. Iter5 recommended "36 matched · 0 mismatched · 0 skipped";
`bin/leakage-report` still renders `fsub` through the passed/failed subtotal
template.
**Recommendation:** For the F card, render the subtotal in matched/mismatched
vocabulary (and "runner failed — see transcript" when `adv is None`, which the
zeros-suppression already approximates).
**Residual if not fixed:** The adversarial count keeps living in two framings
on the same page; totals look internally inconsistent.

### P2 — Copy bug persists: lowercase "harness…" after a period in the F stub blurb (iter5 P2 carryover)
**Severity:** P2
**Evidence:** `bin/leakage-report:296`: `blurb.replace("Detector check",
"harness self-consistency check against the test double")` renders
"…not ML recall/precision. harness self-consistency check against the test
double — no sends in either mode." Capitalization was flagged in iter5 and
only the A-card instance was fixed.
**Recommendation:** Capitalize to "Harness self-consistency check…".
**Residual if not fixed:** Minor, but it's in the most-read paragraph of the
F card — the flagship honesty copy.

### P2 — F-card failure callout says "Detection performance" on stub runs
**Severity:** P2
**Evidence:** Red stub report F card: "🔴 Detection performance: 28 of 36
corpus cases mismatched." The green stub path special-cases the callout to
"Stub consistency: … — harness self-check, not detector validation", but the
mismatch branch (`bin/leakage-report`, `callout()`, F-letter branch) always
says "Detection performance" — detector-quality language on a harness
self-consistency failure, exactly the overclaim the stub vocabulary was built
to prevent.
**Recommendation:** Stub-branch the mismatch callout: "Stub consistency:
28 of 36 corpus cases mismatched — harness self-check failed."
**Residual if not fixed:** On a broken-harness run the headline reintroduces
the detector-quality framing the stub banner works to dispel.

### P3 — Hero subtitle still wraps mid-token on mobile (iter5 P3 carryover)
**Severity:** P3
**Evidence:** 390px screenshot: "muse-leakage-guard · bin/leakage-audit +
bin/adversarial-" / "run". `bin/leakage-report:619` renders the two script
names as plain text with no break control.
**Recommendation:** Wrap each script name in `<span style="white-space:nowrap">`
or insert `<wbr>` after the `+`.
**Residual if not fixed:** Cosmetic; the hero is the first thing seen on the
device class the layout targets.

### P3 — Legend shows the stub entry on real-target reports; gray skip border is undefined
**Severity:** P3
**Evidence:** Real-target report legend includes "🟣 stub self-consistency —
harness check against the synthetic test double" though no purple card exists
in that report. Separately, `.card.skip` has no CSS rule (only `.ok`/`.red`/`.stub`
are defined), so the E card falls back to the gray `--mut` border — a visual
state the legend never defines.
**Recommendation:** Render the stub legend row only when `stub` is true;
add an explicit (gray, neutral) treatment for `skip` and a matching legend
row, or reuse the ⚪ "tracked residual" row for all non-verdict states.
**Residual if not fixed:** Minor noise on real reports; an undefined border
color readers must interpret on their own.

### P3 — Findings list is an undifferentiated wall on large reds
**Severity:** P3
**Evidence:** Red report: "Findings (47)" as one flat `<ul>` — 19 B-check
failures then 28 F mismatches with no grouping, though each entry already
carries its suite letter and links to `#card-B` / `#card-F`.
**Recommendation:** Group under suite sub-heads with counts
("Gate effectiveness — 19", "Detection performance — 28"); the anchors and
auto-expand already do the rest.
**Residual if not fixed:** On a badly red report the entry-point section is a
long scan; grouping is cheap orientation.

### P3 — Empty transcript edge still renders a bare empty box (iter5 P3 carryover)
**Severity:** P3
**Evidence:** `transcript_html` renders `<pre>{scrubbed}</pre>` unconditionally;
if the audit produced no output the reader gets an empty bordered box with no
explanation.
**Recommendation:** If the scrubbed transcript is empty, render "No transcript
captured — see the run that produced this report." inside the `<pre>`.
**Residual if not fixed:** Rare edge (crashed run), reads as unfinished.

### P3 — E card: zeros suppressed but no note-aware replacement; `.card.skip` rule missing
**Severity:** P3
**Evidence:** Iter5's fix suppressed the "0 passed · 0 failed · 0 skipped"
anti-pattern (the subtotal template now renders nothing when all zeros), but
the recommended replacement — e.g. "9 known paths tracked openly" — was not
added; the card head jumps from callout to chevron with a visual gap. The
`skip` class still has no CSS rule (see P3 legend finding).
**Recommendation:** Render a notes-aware subtotal for note-only suites
(`f"{len(s['notes'])} known paths tracked openly"`); add the `.card.skip` rule.
**Residual if not fixed:** The residuals card reads slightly unfinished; the
missing rule is latent fragility.

## Artifacts
- `stub-desktop.png`, `stub-mobile.png`, `stub-mobile-dark.png` — green stub report
- `real-desktop.png` — green real-installation report (no stub chrome)
- `red-desktop.png`, `red-mobile.png`, `red-fcard.png`, `red-matrix.png` — red report
  (ATTENTION, 47 findings), including crops of the B card tri-state groups and
  the F card confusion matrix
- Source HTML for all three reports regenerated into `/tmp/iter6-review/`
  (ephemeral); screenshots copied alongside this review.
