# Iteration 7 review — Senior designer

**Reviewer:** designer subagent (iteration 7)
**Repo HEAD:** e20a819 "Iteration 6: CI fails honest"
**Scope:** full-repository, read-only; centered on the generated HTML report
(`bin/leakage-report`) and docs/workflow presentation.
**Method:** generated three reports in SIMULATED mode (never `MOCHI_LIVE_FIRE=1`,
never touched `local.env`; all fixtures synthetic, belonging to nobody):
1. `/tmp/iter7-stub-report.html` — against `test/stub-memory-skill` (clean run)
2. `/tmp/iter7-red-report.html` — against `/tmp/redskill` (broken target: missing
   gates; 26 failed checks, adversarial runner failed)
3. `/tmp/iter7-mismatch-report.html` — against `/tmp/leakyskill` (copy of the stub
   with `memory-egress-check` forced to rc=0; 28/36 adversarial mismatches)

Screenshots taken with the local headless Chrome
(`~/workspace/.local/chrome/chrome-linux64/chrome --headless=new --disable-gpu --no-sandbox`):
desktop 1280px, mobile 390px (full-page), and a `--disable-javascript` pass.

**Finding counts:** HIGH ×3 · MEDIUM ×7 · LOW ×2 = **12 findings**.

---

## HIGH

### H1 — Findings titles duplicate the suite letter: "[B] [B] …"

- **Severity:** HIGH (every red report ships with visibly broken headings)
- **Evidence:** `/tmp/iter7-red-report.html` and `/tmp/iter7-mismatch-report.html`,
  Findings section — every entry reads e.g. "**[B] [B] egress gate: fake api key
  blocked**". Screenshot: `/tmp/shot-red-1280,1600.png` (Findings list).
  Root cause: `bin/leakage-report:332` builds the title as
  `f"[{s['letter']}] {scrub(c['text'])}"` but the audit already prefixes the
  check text — `bin/leakage-audit` emits `@@@ CHECK FAIL [B] egress gate: …`
  (verified via `MOCHI_AUDIT_MACHINE=1 bin/leakage-audit` against the red
  target). The card evidence itself shows the single `[B]` correctly, so only
  the Findings titles double it.
- **Recommendation:** strip an existing `^\[[A-Z]\]\s*` prefix from the check
  text before prepending the suite letter (or drop the prepend and trust the
  audit's prefix). Titles should read "[B] egress gate: fake api key blocked".
- **Residual if not fixed:** every failing report looks sloppy at the exact
  moment credibility matters most; the duplication also leaks into the CI
  summary and any downstream consumer of the Findings list.

### H2 — Tri-state evidence groups collapse on red runs: failed B checks all land in "Other evidence"

- **Severity:** HIGH (the tri-state design — the report's core honesty mechanism
  for suite B — silently stops working precisely when it is needed)
- **Evidence:** `/tmp/iter7-red-report.html`, card B detail. The 14 failed checks
  (e.g. `[B] egress gate: clean passes`, `want rc=0, got rc=127`) are all filed
  under the catch-all **"Other evidence"** heading; the Hard-block /
  Approval-gated / Pass-through groups contain only the passing checks.
  Screenshot band `/tmp/band1.png` (auto-expanded red card B).
  Root cause: `tri_state_groups` (`bin/leakage-report:351`) classifies on
  `re.search(r"rc=(\d)", c["text"])` — the *check text* — but failed checks
  carry `rc=` only in the *evidence* line (`want rc=0, got rc=127`), which the
  splitter never looks at. Second, when `rc=` does appear in text, the regex
  takes the *first* occurrence, which in `want rc=1, got rc=127` phrasings is
  the *expectation* (`want`), not the *outcome* (`got`) — a check that should
  have hard-blocked but passed through would be filed under "Hard-block
  evidence — refused outright (rc=1)" based on expectation alone.
- **Recommendation:** classify on the actual outcome: search `got rc=(\d)` in
  the check text first, then in the first evidence line; only then fall back to
  "Other". Better still, have the audit emit the tier/outcome as a machine
  sentinel so the report never parses prose for verdicts.
- **Residual if not fixed:** on red runs the reader cannot tell at a glance
  which protection tier failed (block vs approval-gated vs pass-through) — the
  tri-state promise is kept only on green runs.

### H3 — F card says "Detection performance" on stub runs with mismatches

- **Severity:** HIGH (re-opens the exact mislabeling the stub wording was built
  to prevent; inconsistent with the all-pass stub run)
- **Evidence:** `/tmp/iter7-mismatch-report.html`, card F header:
  "🔴 **Detection performance: 28 of 36 corpus cases mismatched.**" — on a run
  whose target-kind is SYNTHETIC STUB. Screenshot `/tmp/band2.png`; mobile
  `/tmp/mb0.png`. The card's own detail body correctly says "harness
  self-consistency check against the test double". Root cause:
  `callout()` (`bin/leakage-report:251`) only takes the stub branch
  (`"Stub consistency: …"`) when `mm == tt`; the mismatch branch is
  stub-unaware.
- **Recommendation:** branch on `stub` first in the F callout, independent of
  match outcome — e.g. "🔴 Stub consistency: 8/36 corpus cases matched expected
  verdicts — harness self-check, not detector validation." Reserve "Detection
  performance" for non-stub targets only.
- **Residual if not fixed:** a stub run with mismatches reads as a detector
  quality failure to anyone skimming headers — the precise confusion the
  purple stub card and stub bar were designed to eliminate.

---

## MEDIUM

### M1 — Badge is binary green/red: ATTENTION renders red, no amber state exists

- **Severity:** MEDIUM (design question from the brief; verdict vocabulary
  mismatch)
- **Evidence:** `bin/leakage-report:643` — `<span class="badge {"ok" if clean
  else "bad"}">`; CSS defines only `.badge.ok` (green #166534) and `.badge.bad`
  (red #991b1b). Both the red report and the mismatch report show a red
  **ATTENTION** badge (screenshots `/tmp/shot-red-1280,1600.png`,
  `/tmp/shot-mismatch-desktop.png`). `INCOMPLETE` also renders red.
  Meanwhile the legend defines a *yellow* state — "protected through approval" —
  that has no badge, card, or verdict counterpart anywhere in the UI.
- **Recommendation:** either (a) add an amber badge state: ATTENTION → amber
  ("needs review"), reserving red for demonstrated leak / BLOCKED; or (b) keep
  ATTENTION red and reword the legend so yellow is not read as a verdict level
  (it currently describes evidence tiers, not verdicts). Option (a) matches the
  tri-state language the legend already teaches.
- **Residual if not fixed:** a single missing fixture and a demonstrated
  secret-leak render identically; the legend's yellow entry teaches a state
  that never appears, training readers to ignore the legend.

### M2 — Confusion matrix: no off-diagonal emphasis, no explanation

- **Severity:** MEDIUM
- **Evidence:** `/tmp/iter7-mismatch-report.html`, card F detail — the 3×3
  "Expected vs actual exit code" table. The off-diagonal mismatch cells
  (block→rc=0: **19**, review→rc=0: **9**) render identically to every other
  cell. Screenshot `/tmp/band2.png` (desktop) and `/tmp/mb0.png` (mobile).
  There is no sentence explaining that diagonal = matched, off-diagonal =
  mismatched; the corner header "expected \ actual" is standard and fine, and
  the mobile layout fits without scrolling (acceptable), but the table fails
  its one job: making the failure pattern visible.
- **Recommendation:** shade off-diagonal cells (light red tint, dark-mode
  aware, e.g. `color-mix`), and add one line under the caption: "Diagonal =
  matched; off-diagonal = mismatched (the count that got the wrong exit code)."
- **Residual if not fixed:** the matrix is decoration — a reader must
  cross-reference the per-case table to find what the matrix was supposed to
  show.

### M3 — 95% CI bounds have no plain-language gloss

- **Severity:** MEDIUM
- **Evidence:** `/tmp/iter7-mismatch-report.html`, card F:
  "Exact 95% CI lower bounds (Clopper-Pearson): block-tier: interval not
  computed (0/19) · review-tier: interval not computed (0/9) · clean ≥ 0.63
  (8/8)." A first-time reader cannot tell *why* two tiers have no number, nor
  that "≥ 0.63" on a perfect 8/8 is expected small-n behavior rather than a
  failing grade. The reasoning exists only in a code comment
  (`bin/leakage-report:233`).
- **Recommendation:** add one plain-language sentence, e.g.: "Bounds are only
  shown for perfect tiers — with just 8 fixtures, even 8/8 only guarantees
  ≥63% at 95% confidence. These bound *fixture conformance*, not real-world
  detector quality."
- **Residual if not fixed:** readers either ignore the line (wasted rigor) or
  misread "0.63" as a poor score on a perfect tier.

### M4 — No-JS: card evidence is unreachable with JavaScript disabled

- **Severity:** MEDIUM (progressive-enhancement failure; contradicts the
  report's "evidence-first" posture)
- **Evidence:** every card detail is `<div class="detail" … hidden>` toggled
  only by the script at `bin/leakage-report:660-678`
  (`document.querySelectorAll('.card-head')…`). With JS disabled: (a) no card
  can be expanded — 6 hidden detail sections stay hidden; (b) the red-card
  auto-expand never runs, so the "reader sees the evidence without an extra
  tap" behavior fails exactly on red reports; (c) Findings "evidence →"
  anchors jump to collapsed cards. Screenshot `/tmp/shot-stub-nojs.png`
  (`--disable-javascript`; byte-identical to the JS render, confirming JS
  changes nothing for the worse — but also nothing for the better). Ironic
  contrast: the *raw transcripts* use native `<details>/<summary>` and work
  fine without JS — the least important content is the most accessible.
- **Recommendation:** drive expand/collapse with `<details>/<summary>` (style
  as today), or add a `<noscript><style>.detail{display:block}</style></noscript>`
  fallback. Keep the JS auto-expand as enhancement.
- **Residual if not fixed:** any reader with JS disabled (or a JS error —
  note the page has no error handling around the toggle script) gets a report
  whose entire evidence body is a set of dead buttons.

### M5 — Legend mixes verdict states, evidence tiers, and card variants in one unlabeled row

- **Severity:** MEDIUM
- **Evidence:** the legend strip in all three reports (screenshots
  `/tmp/shot-stub-1280,1600.png`, `/tmp/shot-stub-mobilefull.png`): five
  colored items in a single wrapping row with no visible heading (only
  `aria-label="Verdict legend"`). Green ("well protected") and red ("can
  leak") are verdict states; yellow ("protected through approval") is an
  *evidence tier* with no verdict counterpart (see M1); purple ("stub
  self-consistency") and white ("tracked residual") are *card variants*.
  A first-time reader scanning top-to-bottom meets "🟡 protected through
  approval" sitting between "well protected" and "can leak" and reasonably
  reads five verdict levels.
- **Recommendation:** split the legend into two labeled groups — "Verdict"
  (green/red) and "Card types" (yellow/purple/white) — with a visible
  "Legend" heading, and reword the yellow item to make clear it is not a
  report verdict (e.g. "review-tier evidence: refused without explicit
  approval (rc=2)").
- **Residual if not fixed:** first-time readers build the wrong mental model
  of the color system on their first 10 seconds with the report.

### M6 — F-card subtotal uses protection vocabulary on a self-consistency card; grand Total scope is unlabeled

- **Severity:** MEDIUM (vocabulary mismatch; two different "passed" counts on
  one page)
- **Evidence:** stub run, card F subtotal: "**36 passed · 0 failed · 0
  skipped**" (`/tmp/iter7-stub-report.html`, screenshot
  `/tmp/shot-stub-mobilefull.png`); mismatch run: "**8 passed · 28 failed · 0
  skipped**" (`/tmp/iter7-mismatch-report.html`, `/tmp/mb0.png`). The callout
  directly above already says "Stub consistency … harness self-check, not
  detector validation" — then the subtotal re-imports protection vocabulary
  ("passed"/"failed"). Meanwhile the grand Total ("Total: 40 passed · 19
  failed · 2 skipped") sums only suites A–E and excludes the F card's 36 cases,
  with the only scope hint being the sub-line "adversarial: 8/36 matched".
  A reader sees two "passed" counts measuring different units on the same page.
- **Recommendation:** on the F card render the subtotal as "36/36 matched" /
  "8/36 matched" (matching the callout's "matched expected verdicts"
  vocabulary); label the grand total's scope, e.g. "Audit total (suites A–E)",
  or include the adversarial cases as a separate labeled line rather than a
  same-word sub-line.
- **Residual if not fixed:** "36 passed" on a purple self-consistency card
  will be quoted as 36 protection passes; the Total's scope stays a puzzle.

### M7 — `.card.skip` has no CSS variant; all-skip subtotal still reads "0 passed"

- **Severity:** MEDIUM (the iteration-5 skip-card fix is half-done)
- **Evidence:** the skip class *is* emitted (residuals card E on the mismatch
  report: `class="card skip"` — confirmed via HTML inspection) but no
  `.card.skip` rule exists in the stylesheet (`bin/leakage-report:588-589`
  defines only `.card.ok`, `.card.red`, `.card.stub`); the card silently
  inherits the default gray `border-left`. It happens to match the legend's
  white "tracked residual" dot, but that is accidental, not intentional — a
  future default-color change silently re-themes skip cards. Second, the
  subtotal (`bin/leakage-report:388-389`) renders whenever `p+f+sk > 0`, so an
  all-skip suite still reads "**0 passed · 0 failed · N skipped**" — the
  "meaningless 0 passed" phrasing from iteration 5 survives for the all-skip
  case (the zero-content card was fixed by suppression, not this path).
- **Recommendation:** define `.card.skip` explicitly (even if it keeps the
  current gray, make the choice visible in code); for all-skip suites render
  the subtotal as "N skipped" only.
- **Residual if not fixed:** the skip variant is one refactor away from
  looking broken or misleading, and all-skip suites still lead with a
  zero that means nothing.

---

## LOW

### L1 — Copy: stub bar reads "A 36/36 here proves…"

- **Severity:** LOW
- **Evidence:** `bin/leakage-report:507` — the stub banner renders "A 36/36
  here proves harness self-consistency, not detector quality." (visible in
  `/tmp/shot-stub-1280,1600.png`); the mismatch run shows "A 8/36 here
  proves…", which is additionally ungrammatical ("A 8/36" → "An").
- **Recommendation:** drop the article: "36/36 here proves harness
  self-consistency, not detector quality."
- **Residual if not fixed:** minor copy blemish on the banner every stub run
  ships with.

### L2 — F-card subtotal wraps mid-phrase on narrow mobile

- **Severity:** LOW
- **Evidence:** `/tmp/mb0.png` (390px): "8 passed · 28 failed · 0 skipped"
  breaks with "failed" starting a new line, reading awkwardly. (Largely
  resolved by the M6 recommendation — "8/36 matched" is shorter and wraps
  cleanly.)
- **Recommendation:** use `white-space: nowrap` on the subtotal span, or adopt
  the shorter M6 vocabulary.
- **Residual if not fixed:** cosmetic only.

---

## Verified as fixed / not an issue (focus areas checked, no finding)

- **Stub card border:** the F card on the all-pass stub run wears the purple
  `.card.stub` border (`#7c3aed`, `#a78bfa` dark) — the iteration-5 "stub card
  wore the green verdict border" issue is fixed.
- **Zero-content subtotal:** the residuals card (0/0/0) correctly suppresses
  the subtotal — the "meaningless 0 passed" fix holds for this path (the
  all-skip path is M7).
- **Confusion-matrix mobile layout:** the 3×3 table fits at 390px via
  `.tablewrap{overflow-x:auto}`; headers wrap to two lines but stay readable
  (`/tmp/mb0.png`). No layout break.
- **Red-card auto-expand (with JS):** failing cards auto-expand on load and
  the chevron rotates (▸→▾); verified on card B and card F of the mismatch
  report (`/tmp/band1.png`, `/tmp/band2.png`).
- **Mode/stub honesty labeling:** hero title carries "CLEAN (synthetic stub)",
  SIMULATED modebar, SYNTHETIC STUB TARGET banner, and footer disclaimer are
  all present and consistent on stub runs.
- **Matrix corner header:** "expected \ actual" is standard and unambiguous;
  no change needed (the missing pieces are shading + explanation, M2).
- **Docs:** README/SKILL.md/ITERATIONS.md/CHANGELOG.md contain no stale claims
  about the report's badge, legend, or matrix behavior beyond what is
  implemented.

## Notes on method

- All runs in SIMULATED mode; `MOCHI_LIVE_FIRE` never set; `local.env`
  untouched. `/tmp/redskill` (empty skill dir) and `/tmp/leakyskill` (stub
  copy with `memory-egress-check` forced to `exit 0`) are throwaway synthetic
  targets in `/tmp`, not repo modifications — `git status` in the repo shows
  no content changes from this review.
- Shell convention followed: every shell context exported the shims PATH
  first.