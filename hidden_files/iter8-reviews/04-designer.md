# Iteration-8 review — Senior designer (design-quality workstream lead)

Reviewer: designer subagent (session b7bdbaec-c3d0-4445-bddc-9450bfa90283)
Date: 2026-09-17 (PDT) · Repo HEAD 2243723, branch main
Scope: the GENERATED HTML report as a designed artifact (bin/leakage-report output).

## Method

- Ran `bin/leakage-report --out /tmp/iter8-designer/report.html` unmodified in
  simulated mode (exit 0: CLEAN, 63 passed · 0 failed · 5 skipped, adversarial
  36/36). Report NOT committed; lives only in /tmp.
- Rendered with the local headless Chrome
  (~/workspace/.local/chrome/chrome-linux64/chrome, --headless=new) at
  390px (mobile), 1280px (desktop), and 390px with --force-dark-mode.
  Read every render as images.
- To critique states the clean run cannot produce, I extracted the report's
  Python generator verbatim to /tmp and fed it synthetic mutated transcripts
  (machine-sentinel audit + adversarial logs): a FAIL variant (1 failed check
  in suite B, verdict ATTENTION, 1 adversarial mismatch), a SYNTHETIC STUB
  variant (STUBKIND sentinel), and a LIVE-FIRE variant. No repo file was
  modified; no live sends; all payloads synthetic. One synthetic artifact to
  note: my FAIL mutation changed a suite-A check's mark but only suite-B's
  ENDSUITE totals, so finding #2 below was verified against the F-card path
  (which is self-contained) and the suite-card color logic was read from code.

## What works (keep)

- 10-second verdict: the hero badge (CLEAN/ATTENTION) + modebar gives the
  verdict instantly on mobile. This is the report's strongest design decision.
- Red cards auto-expand; the Findings section sits above the cards and links
  back to `#card-X` evidence. Good failure UX.
- Suite B's tri-state evidence split (hard-block rc=1 / approval-gated rc=2 /
  pass-through rc=0) is exactly the right information architecture — the two
  protection tiers are never mixed.
- Tables have `<caption>`, `scope` attributes, and `overflow-x:auto` wrappers;
  no horizontal page overflow at 390px.
- Status marks carry visually-hidden screen-reader words ("Pass: "/"Fail: ") —
  not color-only. Dark mode is genuinely well-executed (readable, distinct
  card treatments, no washed-out text).
- Honest microcopy throughout ("harness self-check, not detector validation",
  "not a real-world sample", exact 95% CI lower bounds). The design never
  oversells.
- Atomic write (tmp + os.replace) — invisible to the reader, correct.

## Findings

### P1

**D1. The legend documents a yellow state that the report can never render.**
The tri-state legend lists 🟡 "protected through approval — review-tier:
refused without explicit approval (rc=2)", but `render_card()` only ever
emits `red`, `stub`, `ok`, or `skip` classes, and `callout()` only ever emits
🔴 / ⚪ / 🟢 / 🟣. Verified: 🟡 appears exactly once in every generated
report — in the legend itself. A legend entry for an unreachable state
teaches the reader to scan for a treatment that cannot appear, which erodes
trust in the other four entries. Implementable fix (pick one):
  a. Remove the 🟡 entry from the legend; the B card's in-card tri-state
     labels ("Approval-gated evidence — refused without explicit approval
     (rc=2)") already carry that semantic, or
  b. add a real yellow card treatment (e.g. a suite whose evidence is entirely
     approval-gated renders yellow). Recommendation: (a) — simpler, and the
     in-card labels are the better home for the concept.

**D2. The F card can contradict itself when a runner-reported mismatch is not
in the corpus file.** The per-case table and the 3×3 confusion matrix are
built by iterating `adversarial-corpus.txt` lines; `@@@ ADV MISMATCH` rows
whose case name is absent from the corpus file (rename/drift) are silently
dropped from both. Result: the card callout says "1 of 36 corpus cases
mismatched", the Findings section lists the mismatch, but the card's own
table shows 36/36 ✓ and the matrix stays perfectly diagonal. The reader sees
two irreconcilable stories inside one card. Implementable fix: after building
rows from the corpus file, append any `mismatches` entries whose name did not
match a corpus line as extra table rows (marked e.g. "not in corpus file —
possible runner/corpus drift") and fold them into the matrix's non-standard
bucket; the card must never show a clean table under a mismatch callout.

### P2

**D3. Tier figures printed twice in a row in the F card.** `tested_blurb(F)`
ends with "(block-tier pass 18/19, review-tier pass 9/9, clean pass 8/8)" and
the immediately following `<p class="tiers">` repeats the identical numbers
("block-tier pass 18/19 · review-tier pass 9/9 · clean pass 8/8"). Delete one
— keep the blurb's inline version and drop the standalone line (or merge the
CI line into a single "tiers + CI" paragraph).

**D4. The legend costs ~200px of above-the-fold space on phones.** On a 390px
viewport the five legend rows sit between the modebar and the first card,
pushing all content below the fold on real phone viewports (the test renders
were 1400px tall; on a 390×844 phone the reader scrolls past the legend
before seeing a single card). The hero badge already delivers the verdict, so
the legend is reference material, not primary content. Implementable fix:
render the legend as a `<details>` (closed by default on narrow screens), or
move it below the cards; keep it fully expanded on desktop.

**D5. Red-card auto-expand depends on JavaScript.** The generator emits
red-card details with the `hidden` attribute and relies on the inline script
to open them. With JS disabled (some webviews, saved-file viewers), the
reader sees the red callout and the Findings "evidence →" links jump to a
card whose detail stays collapsed. Implementable fix: emit red-card details
pre-expanded in the HTML (no `hidden`), and let the script handle only the
toggle interaction. This also removes the post-load layout shift on every
ATTENTION report.

**D6. "evidence →" links use the browser default blue.** The `.flink` color is
unstyled, so Findings links (and any CI-run link) render in default link
blue — a color that appears nowhere else in the palette and is low-contrast
against dark-mode cards. Implementable fix: define explicit link colors for
both schemes, e.g. `.findings .flink, footer a { color: var(--bad); }` is
wrong semantically; better a dedicated accent such as
`a { color:#1d4ed8 } @media dark { a { color:#93c5fd } }`, or inherit the
enclosing card's verdict color.

**D7. A mismatched row does not pop in the 36-row per-case table.** The only
failure signal is a red ✗ in the "match" column (`.cbad` colors the mark, not
the row); finding the one bad row requires scanning all 36. Implementable
fix: tint mismatched rows, e.g.
`tr.mismatch { background:#fef2f2 } @media(prefers-color-scheme:dark){
tr.mismatch { background:#3b1212 } }`, keeping the ✗ mark as the text signal.

**D8. Card headers state the same numbers twice.** E.g. callout "Installation
integrity: 20 of 23 green, 3 skipped." followed immediately by the subtotal
"20 passed · 0 failed · 3 skipped" — identical information in two lines on
every card. Implementable fix: drop the `.subtotal` span on green/purple
cards (the callout already encodes pass/fail/skip); keep it only where it
adds information, or merge into a single callout line.

### P3

**D9. Confusion-matrix corner cell reads "expected \ actual".** The backslash
looks like an escaping artifact. Replace with "expected ↓ · actual →" or
"expected (rows) / actual (cols)".

**D10. Fail callout copy is meta-commentary.** "Gate effectiveness: 1 of 35
failed — red, needs attention." The word "red" describes the UI, not the
result. Rephrase: "Gate effectiveness: 1 of 35 checks failed — needs
attention."

**D11. Hero whitespace and awkward meta wrap.** On desktop the navy hero is
full-bleed while content occupies only the left 640px column (right ~60% is
empty gradient). On mobile, `.meta` wraps mid-path ("target:
~/workspace/skills/personal-memory-system" breaks after the label).
Implementable fixes: cut hero padding on ≤480px; put `target:` on its own
line with `overflow-wrap:anywhere`; on ≥1024px widen `.wrap` to ~720px
and/or add a right-aligned summary stat (e.g. large "63/68" pass count) to
fill the hero.

**D12. Transcript `<summary>` tap targets are single-line text.** Add vertical
padding so each summary is a ≥44px tap target on touch devices.

**D13. Stub-mode F-card callout is three lines on mobile.** "Stub consistency:
36/36 corpus cases matched expected verdicts against the synthetic test
double — harness self-check, not detector validation." Shorten to "Stub
consistency: 36/36 matched — harness self-check, not detector validation."

## Follow-ups (could not evaluate without a browser/device)

- Real-device check on iOS Safari / Android Chrome at 390×844 (the renders
  here are desktop Chromium emulating the width; safe-area, dynamic toolbar,
  and actual tap-target feel need a phone).
- A screen-reader pass (VoiceOver/TalkBack) over the card `<button>` +
  `role="heading"` nesting and the auto-expand behavior.
- A genuine LIVE-FIRE report from a real run (my LIVE-FIRE variant used a
  synthetic transcript; the modebar styling itself was verified, light and
  dark).
- The `adv is None` (runner-failed) F-card state renders from code only; not
  visually verified.

## Files produced

- Review: this file
  (`~/workspace/skills/muse-leakage-guard/hidden_files/iter8-reviews/04-designer.md`).
- Scratch only (in /tmp/iter8-designer/, never committed): `report.html`
  (clean run), `fail.html`, `stub.html`, `live.html`, mutated transcripts,
  `gen_report.py` (verbatim extractor copy), and PNG renders.

## Git hygiene

No tracked file was modified; the only new file in the repo is this review
under `hidden_files/iter8-reviews/` (untracked, as with prior iterations'
review outputs). `git status` shows no modifications to tracked files.
