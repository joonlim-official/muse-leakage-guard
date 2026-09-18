# Iteration-9 review — Senior designer (report-design workstream)

Reviewer: designer subagent (session e47b3e6d-7f94-4fd8-bc37-ea7ff0331bad)
Date: 2026-09-17 (PDT) · Repo HEAD e35c1bc, branch main
Scope: the GENERATED HTML report as a designed artifact (bin/leakage-report output).

READ-ONLY review: no tracked file was modified; no commits, pushes, or sends.
All test artifacts live in /tmp/iter9-designer/ (never committed).

## Method

- Ran `bin/leakage-report --out /tmp/iter9-designer/report.html` unmodified in
  SIMULATED mode against the real installation (exit 0: CLEAN, 63 passed ·
  0 failed · 5 skipped, adversarial 36/36). Report NOT committed.
- Rendered with the local headless Chrome
  (~/workspace/.local/chrome/chrome-linux64/chrome, --headless=new) at
  320px, 390px (mobile), 1280px (desktop), and 390px with --force-dark-mode.
  Read every render as images; built an all-cards-expanded QA copy to audit
  evidence density.
- To critique states a clean run cannot produce, I extracted the report's
  Python generator verbatim to /tmp and fed it synthetic mutated transcripts
  (machine-sentinel audit + adversarial logs), all payloads synthetic:
  - FAIL: 1 failed check in suite B + 1 adversarial mismatch → ATTENTION
  - BLOCKFAIL: a hard-block check failing inside the green-titled group
  - STUB: STUBKIND synthetic-stub sentinel
  - LIVE: MODE LIVE-FIRE sentinel
  - DEAD: adversarial runner produced no parseable figures at all (adv=None)
  - DRIFT: runner-reported mismatch whose case name is absent from the corpus
  No repo file was modified; no live sends.
- Computed WCAG contrast ratios for every palette pair in the stylesheet
  (light + dark), both text treatments and modebar/badge treatments.

## What works (keep)

- 10-second verdict: hero badge (CLEAN/ATTENTION) + modebar delivers the
  verdict instantly on mobile. Still the report's strongest design decision.
- Findings section above the cards with `evidence →` anchor links; red cards
  pre-expand server-side (verified with JS effectively absent) — D5 from
  iter8 is genuinely fixed, confirmed by execution in the FAIL variant.
- Suite B's tri-state evidence split remains the right information
  architecture; the tri-state callout ("16 blocked outright · 6 protected
  through approval · 11 allowed normally") never reports rc=2 as plain green.
- Honest microcopy throughout: "harness self-check, not detector validation",
  "not a real-world sample, and not ML recall/precision", exact 95%
  lower-bound wording, "0 hidden" on the residual card, stub scoping in the
  title/hero/modebar/legend/footer. The design never oversells.
- Dark mode is genuinely well-executed; contrast audit: every measured pair
  passes WCAG AA 4.5:1 in both schemes (weakest: light-mode `--ok` on white
  at 5.02, dark-mode `--ok` on card at 10.21).
- 320px viewport: no horizontal page overflow; tables degrade to their
  `overflow-x:auto` wrappers as designed.
- Non-color status cues are thorough: ✓/✗/– marks, visually-hidden
  screen-reader words, text labels, card edge colors, emoji callouts, focus
  styles, skip link. Not color-only anywhere I could find.
- Residual card (E): plain-language gloss as the primary line with the
  technical note retained underneath in muted type — the right two-layer
  presentation for mixed audiences.
- Explicit link colors for both schemes (D6 fixed); mismatch rows tinted in
  the per-case table (D7 fixed); matrix corner cell reads "expected vs
  actual" (D9 fixed); subtotal dropped on ok/stub cards (D8 fixed); stub
  callout shortened (D13 fixed); `overflow-wrap:anywhere` on the target path.
- Atomic write (tmp + os.replace) — invisible to the reader, correct.

## Findings

Findings marked **[EXEC]** were confirmed by execution (generated report
rendered in headless Chrome); **[STATIC]** are code-read findings.

### P1

**DG1. [EXEC] ATTENTION badge with no Findings section when the adversarial
runner yields no parseable figures.**
Where: bin/leakage-report, badge-flip logic (~line 228) vs findings
construction (~lines 380–388, 599–612).
What: if the audit is CLEAN but `adv is None` (adversarial output unparseable
— crashed runner, empty log), the badge correctly flips to ATTENTION
(verified in the DEAD variant render: red ATTENTION badge, red F card
"Detection performance: adversarial runner failed — see transcript").
But `findings` is empty (no failed checks, no mismatches), so no Findings
section renders — while the hero's verdict definition for ATTENTION says
"ATTENTION means something failed or couldn't be verified — see Findings at
the top." The reader follows the instruction and finds nothing at the top.
The same hole exists for `adv_rc != 0` with zero mismatch rows (defensive
case: the real runner emits MISMATCH rows on failure, but the report's
contract shouldn't depend on that).
Why it matters: this is the report's one moment of maximum distrust — a red
badge — and the single sentence that should explain it points at a section
that doesn't exist. For a trust artifact, an unexplained ATTENTION is a
credibility failure.
Remediation: after building `findings`, if the badge was flipped to
ATTENTION by the adversarial path yet `findings` is empty, synthesize one
finding entry, e.g. `("[F] adversarial suite did not verify — see
transcript", "", "F")`, so the Findings section always exists exactly when
the hero promises it. One-line-adjacent fix; no new plumbing.

### P2

**DG2. [EXEC] A failed check renders under a green-dot group heading.**
Where: bin/leakage-report, `tri_state_groups` labels (lines 422–425),
rendered as `.ev-label` headings in card B.
What: the tri-state group headings are prefixed with verdict-colored dots —
"🟢 Hard-block evidence — refused outright (rc=1)" and "🟡 Approval-gated
evidence — refused without explicit approval (rc=2)". In the BLOCKFAIL
variant (a hard-block check flipped to ✗), the failed check sits directly
under the 🟢-prefixed heading (verified in the render crop: green dot
heading, then "✗ egress gate: fake api key blocked (rc=1)"). The dot reads
as a verdict certifying the group ("this group is well protected") while the
group contains a failure. A quick scanner reads the heading and moves on.
Why it matters: it conflates *tier* (a category) with *verdict* (an
outcome). The CHANGELOG for iteration 8 even documents "Evidence grouped
under 🟢/🟡/⚪ labels" as a feature — the feature is the bug: category
labels must not wear verdict colors.
Remediation: drop the 🟢/🟡 prefixes from the tri-state group labels (the
words "Hard-block" / "Approval-gated" / "Pass-through" already carry the
tier distinction) and let the per-item ✓/✗ marks be the only verdict
signal in the evidence list. Alternative: hoist failed checks above their
group under a "Failed in this tier" subheading. The first is simpler and
more robust.

**DG3. [EXEC] Legend still costs ~250–300px of above-the-fold space on
phones (iter8 D4, unaddressed).**
Where: bin/leakage-report, `legend_html` (~lines 615–632) rendered as a
static full-width section between the modebar and the first card.
What: on a 390px viewport the legend (5 rows + "rc=1 blocked outright · …"
codes line + the "Skipped = …" line) pushes the first card to ~y=800 —
below the fold on a 390×844 phone (measured in mobile.png and
mobile320.png). The hero badge already delivers the verdict, so the legend
is reference material occupying primary-content position. Iteration 8
trimmed it to "only the treatments present" but didn't change its placement.
Why it matters: mobile is the stated primary surface ("mobile-friendly HTML
report"); the most expensive above-the-fold real estate after the verdict
goes to a key the reader may never need.
Remediation: render the legend as a `<details>` (closed by default at
≤480px via a second `<details open>` for desktop, or simply always
collapsible with the summary "What the colors mean"), or move it below the
cards. Keep the full static treatment on desktop.

### P3

**DG4. [EXEC] Runner-only drift mismatches inflate confusion-matrix tier
cells, breaking cross-checkability.**
Where: bin/leakage-report, F-card matrix construction (~lines 561–568);
regression against the iter8 D2 design spec.
What: the iter8 D2 fix (and the iteration-8 CHANGELOG entry: "runner-only
mismatches added as labeled drift rows") specified that runner-reported
mismatches absent from the corpus file be appended as labeled table rows
*and folded into the matrix's non-standard bucket*. The table half was
implemented (the drift row renders labeled "not in corpus file — possible
runner/corpus drift" — verified). The matrix half was not: drift cases with
standard rc values are folded into the regular (want, got) cells
(`matrix[(w, g)] += 1` at line 565). In the DRIFT variant the block-tier
matrix row sums to 20 (19 got rc=1 + 1 got rc=0) while the tiers line
directly above it says "block-tier 18/19". Two adjacent figures disagree by
one with no visual cue why.
Why it matters: the matrix exists so a careful reader can cross-check the
tiers line; silently inflating a tier cell teaches the reader the numbers
don't reconcile, which erodes trust in the honest figures elsewhere.
Remediation: implement the original spec — route runner-only (not-in-corpus)
cases to the existing "Non-standard verdicts" bucket/line instead of the
standard cells, so matrix row sums always equal corpus tier totals.

**DG5. [EXEC] Confusion-matrix off-diagonal failure cells don't pop.**
Where: bin/leakage-report, F-card matrix (`matrix_html`, ~lines 562–570).
What: in the FAIL variant the matrix correctly shows the failure
(block-tier row: 18 got rc=1, **1** got rc=0) but the off-diagonal "1" is
plain body text — the failure is only visually discoverable in the per-case
table below (which does tint the row, D7). A reader scanning the matrix
sees a wall of numbers.
Why it matters: the matrix is the at-a-glance summary of *where* detection
failed; its most important cell is its least emphasized.
Remediation: tint non-zero off-diagonal cells with the same treatment as
`tr.mismatch` (`#fef2f2` / dark `#3b1212`), keeping the number as the text
signal. Small CSS addition.

**DG6. [EXEC] Timestamp duplicates itself on UTC machines — including every
CI artifact.**
Where: bin/leakage-report, `fmt_ts` (~lines 241–251).
What: the hero meta renders local time plus the UTC original:
"2026-09-18 12:21 AM UTC (2026-09-18 00:21 UTC)". When the local timezone
*is* UTC the parenthetical is pure redundancy, and it reads as a glitch
("why does it say UTC twice?"). CI runners are UTC, so every
CI-uploaded `leakage-validation.html` artifact shows this form.
Why it matters: low individual cost, but it appears in the most-read line
of the report (hero meta) and in every public CI artifact.
Remediation: in `fmt_ts`, compare the converted local time against the UTC
original and omit the parenthetical when they are identical.

**DG7. [EXEC] Transcript `<summary>` tap target is ~40px, under the 44px
touch minimum (iter8 D12, partially addressed).**
Where: bin/leakage-report stylesheet, line 754:
`.transcript summary{cursor:pointer;font-weight:600;padding:10px 0}`.
What: 10px vertical padding + ~20px line ≈ 40px tall. Close, but under the
44px minimum the iter8 review asked for.
Why it matters: the transcripts are the report's auditability backstop;
on touch devices their toggles are the smallest tap targets on the page.
Remediation: bump to `padding:12px 0` (≈44px).

**DG8. [STATIC] README promises "a concrete suggested remediation" for
every failure; the report buries suggestions in muted evidence type.**
Where: README.md (~lines 98–103) promise vs bin/leakage-report Findings
rendering (~lines 599–612, `.fev` style).
What: the audit's `bad()` does emit "Suggestion: …" lines and the report's
Findings section includes them (verified with a synthetic suggestion in the
FAILSUG variant) — the promise is *technically* kept. But they render in
`.fev` — the same muted 0.8rem gray as raw evidence — so the one piece of
content the README advertises as the payoff of a failure is visually
indistinguishable from log noise.
Why it matters: docs/report consistency is a trust issue; a reader who
was promised remediation and can't spot it will conclude the report
doesn't deliver it.
Remediation: detect evidence lines starting with "Suggestion:" and render
them as a distinct block — e.g. `<span class="fix"><strong>Recommended
fix:</strong> …</span>` with its own (non-muted) styling — in both the
Findings section and the card evidence list.

**DG9. [STATIC] No print stylesheet.**
Where: bin/leakage-report `<style>` block (no `@media print`).
What: printing or saving to PDF (a likely fate for an audit artifact)
keeps the dark navy hero gradient with background graphics, collapses
non-red cards per JS state at print time, and may render in dark mode
depending on the browser — backgrounds often dropped by default print
settings, leaving white-on-transparent text unreadable in places.
Why it matters: audit reports get filed; the artifact should survive the
most boring distribution channel intact.
Remediation: add a small `@media print` block — force the light scheme,
expand all `.detail` sections, hide the chevrons, drop the hero gradient
for a flat border.

**DG10. [STATIC] Residual card states the same numbers twice.**
Where: bin/leakage-report, card E rendering (~line 448) vs `callout()`
residual branch.
What: the callout already says "Known gaps: 10 things this check can't
cover — listed openly, none hidden." and the subtotal immediately repeats
"10 tracked · 0 hidden". Both encode the same two facts ("10", "none/0
hidden").
Why it matters: minor — but the callout/subtotal dedup pass in iteration 8
(D8) explicitly kept the subtotal only "where it adds information"; on the
residual card it doesn't.
Remediation: drop the subtotal span on the residual card (keep "Known gaps
(10)" as the `.ev-label`, which already carries the count).

**DG11. [STATIC] Stub-mode hero badge reads CLEAN with the unscoped CLEAN
definition.**
Where: bin/leakage-report, `verdict_def` + stub rendering.
What: in stub mode the badge says CLEAN and the definition underneath says
"CLEAN means every check passed — nothing that should have been stopped got
through." That sentence, read alone (or in a cropped screenshot), claims a
protection result; only the surrounding stubbar/title/footer scope it to
"harness self-consistency". The scoping is present and honest — this is
about the one sentence a crop would preserve.
Why it matters: low probability, but stub reports are the ones most likely
to be screenshotted into CI summaries and chat threads.
Remediation: in stub mode, append a scoping clause to the verdict
definition, e.g. "CLEAN means every check passed — of the harness
self-test against the synthetic stub."

## Coverage notes for the other workstreams (designer lens only)

- **(1) Trustworthiness/misleading:** the report refuses to write HTML from
  unparseable/incomplete runs (verified in code: format drift, missing
  subtotals, unexpected suite sequence all `die()` before writing) — the
  strongest integrity property in the artifact. The findings above are the
  remaining honesty gaps; none of them fabricate a passing verdict.
- **(2) Gate/shim bypasses:** out of designer scope beyond presentation —
  the residual card lists the known bypass-shaped gaps (absolute-path shim
  bypass, browser-task VM, out-of-band egress) in plain language with the
  technical note retained. Presentation is honest; the security review owns
  the bypass analysis.
- **(3) Audit/adversarial suite gaps:** the F card's "not a real-world
  sample, and not ML recall/precision" plus the 95% lower-bound line are
  exemplary uncertainty communication. DG4 is the one place the adversarial
  presentation breaks its own cross-checkability.
- **(5) Docs/CI/maintainability:** README's report section is accurate
  except DG8's buried-remediation gap; SKILL.md's exit-code contract
  (0/1/2/3) matches the generator's behavior as tested. CI asserts the
  report exists and carries the stub banner, and uploads it as an artifact
  — good. Two CI-artifact-visible nits: DG6 (UTC timestamp duplication on
  UTC runners) and the absence of any visual regression check on the HTML
  (no screenshot step in validate.yml; a future iteration could render the
  artifact headless and fail on unexpected layout drift — suggestion only).

## Verified fixed since the iter8 designer review (no action needed)

- D2 (table half): runner-only drift mismatches render as labeled rows in
  the per-case table — the matrix half regressed as DG4.
- D3: tier figures no longer printed twice (second instance is now the
  CI lower-bound line, which adds information).
- D5: red cards pre-expand server-side; no-JS readers get the evidence.
- D6: explicit link colors in both schemes.
- D7: mismatched per-case rows tinted.
- D8: subtotal dropped on ok/stub cards.
- D9: matrix corner cell "expected vs actual".
- D10: fail callout copy no longer meta-commentary.
- D11: hero meta wraps cleanly; `.wrap` widened to 720px on desktop.
- D13: stub callout shortened.
- D1: yellow legend entry now renders only when rc=2 evidence exists, and
  the yellow treatment does appear in the report (callout + group heading)
  — considered resolved.

## Follow-ups (could not evaluate in this environment)

- Real-device check on iOS Safari / Android Chrome at 390×844 (renders here
  are desktop Chromium at width; safe-area, dynamic toolbar, and actual
  tap-target feel need a phone).
- A screen-reader pass (VoiceOver/TalkBack) over the card `<button>` +
  heading nesting and the auto-expand behavior.
- A genuine LIVE-FIRE report from a real run (the LIVE variant here used a
  synthetic transcript; the modebar styling itself was verified, light and
  dark).
- The `adv is None` F-card state is now visually verified (DEAD variant);
  the `mode UNKNOWN` bar remains code-read only.

## Files produced

- Review: this file
  (`~/workspace/skills/muse-leakage-guard/hidden_files/iter9-reviews/designer.md`).
- Scratch only (in /tmp/iter9-designer/, never committed): `report.html`
  (clean run), `fail.html`, `blockfail.html`, `failsug.html`, `stub.html`,
  `live.html`, `dead.html`, `drift.html`, `expanded.html`, mutated
  transcripts, `gen.py` (verbatim extractor copy), and PNG renders at
  320/390/1280px + dark mode.

## Git hygiene

No tracked file was modified; the only new file in the repo tree is this
review under `hidden_files/iter9-reviews/` (untracked, as with prior
iterations' review outputs).
