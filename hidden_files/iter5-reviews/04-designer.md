# Iteration-5 review — Senior designer

Repo: `~/workspace/skills/muse-leakage-guard` @ e4b2af1. Read-only review; no files modified.

## Method
- Generated a stub-target report with the documented setup
  (`bin/leakage-report --out …/iter5-reviews/iter5-stub-report.html`,
  `PERSONAL_MEMORY_SKILL=test/stub-memory-skill`,
  `MOCHI_AGENTS_FILE=test/stub-memory-skill/AGENTS.md`,
  stub shims first on PATH, inert delegate CLIs behind the shims). Exit 0, CLEAN, 36/36.
- Screenshotted in headless Chrome (`~/workspace/.local/chrome/chrome-linux64/chrome`,
  `--headless=new --disable-gpu --no-sandbox`):
  `iter5-desktop.png` (1280px), `iter5-mobile.png` (390px),
  `iter5-mobile-dark.png` (390px, `--force-dark-mode`),
  `iter5-desktop-expanded.png` (1280px, all card details expanded — review artifact).
- Reviewed the report generator source (`bin/leakage-report`) for edge states
  (adversarial runner failure, skipped suite, empty evidence, failure path).
- Privacy: no personal details involved; all payloads are synthetic stub fixtures.
  Evidence review confirms **no secret-shaped payload contents appear anywhere
  in the report** — evidence shows only check labels, case names
  (`stripe_live`, `ssn_dash`, …), fixture filenames, and `rc=` codes. Good.

## Positives (keep)
- The stub banner reads as a *context qualifier*, not an error: purple
  (`#ede9fe`) qualifier bar, plain-language "harness self-test … not a
  validation of any real installation", repeated in title, meta, and footer.
- Dark mode is coherent (modebars, cards, table all adapt; contrast fine).
- Findings section renders first inside `<main>` when failures exist — the
  right placement for the 60-second test.
- Per-check marks carry visually-hidden "Pass:/Fail:/Skipped:" text; table
  headers use `scope="col"`.

## Findings

### P1 — Stub-consistency card wears the green verdict treatment
**Priority:** P1
**Evidence:** Desktop/mobile screenshots: the "Stub consistency" card has a
green left border (`card ok`) identical to every verdict card, while its
callout dot is 🔵 and its copy says "harness self-check, not detector
validation." At a glance the border is the strongest signal — a reader
scanning left borders sees five green cards and one amber/gray card and
concludes "five passed verdicts." The blue dot is 16px next to 3 lines of
text; it loses.
**Recommendation:** Add a `.card.stub` variant keyed off the stub flag: left
border and a soft card tint in the same purple as the stub banner
(`#c4b5fd` border / faint `#ede9fe` wash), keeping the 🔵 dot. The card must
read as "context about the run" rather than a verdict on the verdict scale.
Same treatment should apply to its subtotal line ("36 matched" per P3 below).

### P1 — Known-residuals card: yellow dot, gray border, meaningless subtotal
**Priority:** P1
**Evidence:** `render_card` assigns class `skip` when a suite has 0 passed / 0
failed, but the stylesheet defines only `.card.ok` and `.card.red` — there
is no `.card.skip` rule, so the card falls back to the gray `--mut` border.
Screenshot (zoomed crop) confirms: 🟡 dot + gray left border. Worse, the
subtotal renders "0 passed · 0 failed · 0 skipped" directly under the callout
"4 known paths reported and tracked — none silent." A reader sees zeros and
assumes nothing happened.
**Recommendation:** Add `--warn` (amber, dark-mode variant) and
`.card.skip{border-left-color:var(--warn)}`. For the residuals suite, replace
the passed/failed/skipped subtotal with a notes-aware line, e.g.
"4 known paths tracked openly", since its sub count is (0,0,0) while its
content is 4 notes. More generally: never render an all-zeros subtotal.

### P2 — "Full evidence (0 items)" empty heading on the detection-performance card
**Priority:** P2
**Evidence:** Expanded desktop screenshot: the Stub consistency detail shows
the match table, then the heading "Full evidence (0 items)" followed by an
empty `<ul class="evidence"></ul>`. This is the edge state where a card has
`extra` content (the table) but zero check items; it reads as unfinished.
**Recommendation:** When `n_items == 0`, suppress the "Full evidence"
heading and empty list entirely (the match table above is the evidence).
Alternatively render "Full evidence: the match table above." Either way,
never show "(0 items)" with an empty list.

### P2 — Adversarial table has no rc legend
**Priority:** P2
**Evidence:** The match table columns are `case / want / got / match` with
values like `rc=1`, `rc=2`, `rc=0`. What those codes mean (blocked / refused
without approval / allowed) is explained only inside the *Gate effectiveness*
card's detail ("Block-tier payloads must be refused with rc=1…"), not in the
detection-performance card where the codes appear 36 times. A reader landing
on this card alone cannot decode it.
**Recommendation:** Add one line above the table in the F detail, e.g.
"rc=1 blocked · rc=2 refused without approval · rc=0 allowed", plus the
existing tier fractions. Consider also that the tier line
("block-tier recall 19/19 · review-tier recall 9/9 · clean precision 8/8")
never defines "tier" — the legend line covers both.

### P2 — A single failing check is hard to locate: failing cards start collapsed, no anchor jump
**Priority:** P2
**Evidence:** Code inspection: every card renders with `hidden` detail and
`aria-expanded="false"`, including cards with failures. The Findings section
(at top, good) names the check as `[B] <check text>` with no link; the failed
row inside the (29-item) evidence list has a red ✗ but no `id`. In the 60-
second test, the reader must expand the right card (letter shown — helpful)
and visually scan up to 29 rows.
**Recommendation:** (1) Auto-expand (remove `hidden`, add `.card.open`) any
card containing a failure or mismatch on page load, so the red card is
already open. (2) Give each evidence `<li>` an `id` (`ev-B-12` style) and
render Findings entries as anchor links to them. Both are cheap in the
existing generator and keep the collapsed default for clean reports.

### P2 — Copy bugs: lowercase "harness…" mid-sentence; lowercase table headers
**Priority:** P2
**Evidence:** Stub F detail blurb: "Stub target — 36/36 corpus cases matched
expected verdicts (…). harness self-consistency check against the test double
— no sends in either mode." (`bin/leakage-report`, `tested_blurb`, F/stub
branch). Table headers are lowercase "case / want / got / match" while all
section headings are sentence case ("Full evidence (N items)").
**Recommendation:** Capitalize to "Harness self-consistency check…". Make
table headers "Case / Want / Got / Match" (or keep lowercase as a deliberate
table style, but then apply it consistently — currently mixed).

### P3 — F-card subtotal "36 passed" vs Total "58 passed": the adversarial count is double-framed
**Priority:** P3
**Evidence:** The Stub consistency card subtotal reads "36 passed · 0 failed ·
0 skipped", but the Total card says "58 passed · 0 failed · 1 skipped" (20 +
29 + 8 + 1), with adversarial counted separately as "adversarial: 36/36
matched". A reader adding cards gets 94; a reader trusting the total wonders
where the 36 went.
**Recommendation:** Relabel the F-card subtotal to "36 matched · 0 mismatched ·
0 skipped" — the "matched" vocabulary already used in the callout and total
line. Keep "passed/failed" for audit suites A–E.

### P3 — Mobile hero subtitle wraps mid-token
**Priority:** P3
**Evidence:** `iter5-mobile.png`: "muse-leakage-guard · bin/leakage-audit +
bin/adversarial-run" breaks as "…bin/adversarial-\nrun".
**Recommendation:** Wrap the two script names in non-breaking spans
(`<span style="white-space:nowrap">`) or insert a `<wbr>` after the `+`.
Minor, but the hero is the first thing seen.

### P3 — `<h2>` inside `<button>` is invalid HTML
**Priority:** P3
**Evidence:** Each card head renders
`<button class="card-head">…<h2 class="callout">…</h2>…</button>`. The
`<button>` content model is phrasing content; `<h2>` is not valid inside it
(browsers tolerate it, but validators and some assistive tech do not).
**Recommendation:** Swap nesting: `<h2 class="callout"><button
class="card-head" aria-expanded…>…</button></h2>` (or make the heading a
styled `<span>`). Keep `aria-labelledby` wiring.

### P3 — Empty transcript edge state renders a bare empty box
**Priority:** P3
**Evidence:** Code: `<h3>bin/leakage-audit</h3><pre>{scrub_transcript(text)}</pre>`
renders unconditionally. If the audit produced no output (crashed before
machine sentinels, or a transcript file went missing), the reader gets an
empty bordered box with no explanation.
**Recommendation:** If the transcript body is empty after scrubbing, render
"No transcript captured — see the run that produced this report." inside the
`<pre>` instead of nothing.

### P3 — Adversarial-runner-failed state: red card with an all-zeros subtotal
**Priority:** P3
**Evidence:** Code path `adv is None`: F card gets `class="red"` with callout
"🔴 Detection performance: adversarial runner failed — see transcript." but
`sub=(0,0,0)` → subtotal "0 passed · 0 failed · 0 skipped" — the same P1
anti-pattern as residuals: a red card claiming zero failures.
**Recommendation:** Same fix as P1: for the F card, render the subtotal in
matched/mismatched vocabulary, and when `adv is None` render "runner failed —
see transcript" instead of zeros.

## Artifacts
- `iter5-stub-report.html` — generated stub-target report (this review's source)
- `iter5-stub-report-expanded.html` — same report with all details expanded (review aid)
- `iter5-desktop.png` / `iter5-mobile.png` / `iter5-mobile-dark.png` /
  `iter5-desktop-expanded.png` — headless-Chrome screenshots
