# Iteration 8 synthesis — Report integrity + readability

All 10 iteration-8 reviews read in full. Findings deduped below by theme;
each item maps to exactly one iteration (8 = this diff, 9/10 = deferred).

## Theme chosen for iteration 8
**Report integrity + readability** — the report is the product surface every
persona flagged (design quality, readability, and honesty are explicitly
in scope per the user's direction). One coherent diff to
`bin/leakage-report` (+ one line in `bin/adversarial-run`, CHANGELOG,
README/SKILL.md wording).

## What iteration 8 implements (all in the report track)
1. **Tri-state honesty (PM P1-1, Designer D1):** Card B callout now splits
   into "N blocked outright · M protected through approval · K allowed
   normally" with a 🟢🟡 marker instead of counting rc=2 as plain green;
   approval-gated evidence group carries 🟡; legend keeps 🟡 (reworded, ~10
   words) and gains an rc-code line (PM P2-3a: rc=1 blocked · rc=2 needs
   approval · rc=0 allowed).
2. **Card D evidence (PM P1-2):** the blurb promises blocked attempts and
   approval overrides in the evidence — the gate-log context lines are now
   rendered as the card's evidence list instead of being suppressed.
3. **Known gaps in plain language (PM P1-3):** card E renders a plain-
   language sentence first for each residual (10 glosses, keyed on
   distinctive substrings of the audit text) with the technical note as a
   secondary muted line; callout "⚪ Known gaps: N things this check can't
   cover — listed openly, none hidden"; subtotal "N tracked · 0 hidden"
   (PM P2-1); blurb replaced with a one-liner (PM P2-2).
4. **Corpus-drift rows (Designer D2):** runner-only mismatches (not in the
   corpus file) now appear as labeled table rows and enter the confusion
   matrix instead of being omitted while a contradiction callout shows.
5. **Badge integrity (Security P2):** CLEAN badge now requires parsed
   adversarial figures, not just adv_rc==0 — a runner that exits 0 while
   emitting nothing parseable yields ATTENTION, never CLEAN.
6. **Readability:** CLEAN/ATTENTION/INCOMPLETE defined in one plain line
   under the hero (PM P2-5); hero subtitle "Automated privacy-protection
   check" + smaller technical line (PM P3-2); timestamp in local time plus
   UTC (PM P3-3); "invoked=0/1" rendered as "real tool never called"/
   "delivered normally" (PM P2-3b); skip definition line when skips exist
   (PM P2-4); F card blurbs consolidated — tier numbers appear once, the
   triple caveat collapsed into the blurb, "Clopper-Pearson" dropped in
   favor of "Worst case consistent with these results (95% lower bound)"
   (PM P2-6, Designer D3); "corpus"→"test cases" in the F callout
   (PM P3-9); stub F callout shortened (Designer D13); fail callouts say
   "needs attention", not "red" (Designer D10); redundant subtotals
   dropped on ok/stub cards where the callout already encodes the numbers
   (Designer D8); total box clarifies "N audit checks passed · M failed ·
   K skipped — plus X/Y attack tests matched" (PM P3-6); explicit
   `.card.skip` CSS rule (PM P3-7).
7. **Accessibility:** red cards pre-expanded server-side (no `hidden`,
   aria-expanded=true, class open) + noscript unhide-all, so evidence is
   reachable without JavaScript (a11y HIGH #1, Designer D5); scrollable
   table wrappers and the transcript `<pre>` are keyboard-focusable
   regions with labels (a11y HIGH #2); headings wrap the card buttons
   instead of living inside them (a11y #3); skip link + `<main id="main">`
   (a11y #5); findings links get unique aria-labels (a11y #7); `.vh` uses
   clip-path (a11y #8); "Overall result" heading on the total (a11y #9);
   :focus-visible on findings links and scroll regions (a11y #10);
   transcript summary and findings links padded to touch targets
   (a11y #4, Designer D12); matrix corner "expected vs actual" (a11y #6,
   PM P3-8, Designer D9); explicit link colors for both color schemes
   (Designer D6); mismatch rows tinted (Designer D7); legend is now
   dynamic (only treatments present in this report) and compact, addressing
   mobile above-the-fold noise (PM P3-5, Designer D4); hero padding cut
   ≤480px, target on its own line with overflow-wrap, 720px wrap ≥1024px
   (Designer D11).
8. **Evidence completeness (SRE P3):** findings and card evidence render
   ALL evidence lines, not just the first (suggestions after ev[0] were
   being dropped).
9. **Tier denominators partition (Data-science P2):** `bin/adversarial-run`
   now attributes TIMEOUT failures to their expected tier's fail counter,
   so a hung gate can't render block-tier 0/0 while the headline counts
   failures.
10. **Docs:** CHANGELOG gains the missing Iteration 7 entry (PM P2-7);
    README/SKILL.md "green/red callout" → "plain-language callout" (PM P3-1).

## Deferred to iteration 9 (explicit)
- **P0 stub-shim bypasses** (AI researcher, empirically confirmed):
  `gmail +reply-all`, `gmail users drafts send` (ungated draft→send),
  `gmail users settings updateAutoForwarding`, plus Chat sends, calendar
  inserts, Messenger marketplace text → stub shim hardening + audit
  coverage.
- **Gates fail OPEN on detector crash** (Security P1, Systems HIGH): stub
  egress-gate/brief-gate return rc=0/ALLOW when the detector exits
  abnormally (incl. rc=137); same fail-open shape observed in the real
  installation (out of scope to patch here — validation-only).
- **rc=137 handling** in audit/adversarial-run (SRE P1): classify as
  runner/gate fault, not a pass.
- **Pinned totals in CI** (SRE P1, Security P2): TOTAL + ADV MATCHED
  sentinels so a gutted corpus can't stay green; ITERATIONS.md staleness.
- **Memory-audit literal republication** (Privacy P1): MOCHI_MEMORY_AUDIT
  evidence must be summarized/hashed, never copied verbatim.
- **Fixture-purity classes** (Privacy P3): phone/figure declarations.
- **Probe-first / KNOWN-GAP methodology** (Data-science P1): corpus labels
  treated as unquestionable ground truth.
- **Messenger stdin-echo hashing** (Systems), delegate self-identity false
  FAIL (Systems), CI fault-injection variants for hung/flaky gates (SRE),
  `[B][B]` duplication + timeout-budget mismatch (SRE P3 — checked in
  iter 8 red-path test; if reproduced, fix in 9).
- **OSS hygiene:** SECURITY.md, issue/PR templates, FP/FN reporting flow,
  CONTRIBUTING quickstart verbatim-runnable (OSS maintainer).

## Deferred to iteration 10
- Threat-model extensions: compositional/chunked exfiltration scenarios,
  shapeless leakage, out-of-band catalog scenarios (AI researcher,
  Privacy) — new corpus cases + attack-surface entries.
- contract_version parsed by code (currently documentation-only).

## Conflicts resolved
- **Yellow unreachable (PM P1-1 vs Designer D1):** kept 🟡 in the legend
  (reworded) AND made it render — in B callouts and the approval-gated
  evidence group — rather than deleting it. The tri-state semantics stay
  complete; nothing is invented.
- **Subtotal redundancy (PM P2-1 vs Designer D8):** kept subtotals on
  red/skip/residual cards (where they add info), dropped them on ok/stub
  cards where the callout already encodes the numbers.
- **Gate fixes (Security P1, AI-researcher P0):** intentionally NOT in
  this diff — this iteration owns the report; the validation layer and
  stub shims are iteration 9's focused diff. The report now *shows* these
  gaps honestly instead of masking them.
