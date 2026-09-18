# Iteration-8 review — Senior data scientist (measurement integrity)

Reviewer lens: do the numbers mean what they say? Recomputed every key
figure empirically (stub target, simulated mode, synthetic payloads only).
No files modified; all perturbation tests ran against /tmp copies.

**Method.** Read `bin/adversarial-run`, `bin/leakage-audit`,
`bin/leakage-report`, `test/stub-memory-skill/bin/{memory-egress-check,patterns.sh,egress-gate}`,
`test/stub-memory-skill/build/build-blockset.sh`,
`.github/workflows/validate.yml`, `references/{gate-interface,test-matrix,attack-surface}.md`,
`ITERATIONS.md`, `CHANGELOG.md`. Ran the audit + adversarial suite + report
against the synthetic stub and recomputed: corpus composition (19 block /
9 review / 8 clean = 36), suite totals, per-suite subtotals, Clopper-Pearson
lower bounds, confusion matrix, SHAPES↔stub-pattern alignment. Perturbation
tests (duplicate names, timeouts, malformed wants, tier-less corpora) ran on
/tmp copies of the runner — repo untouched.

## Verified correct (recomputed, not trusted)

- **Corpus composition:** 36 cases, no duplicate names; tiers 19/9/8.
  Adversarial run: `36/36 matched`, `block 19/19 · review 9/9 · clean 8/8`.
- **Audit totals (stub, simulated):** A=23/0/0, B=35/0/0, C=8/0/1, D=1/0/0,
  E=0/0/0, TOTAL=67/0/1. Subtotals sum exactly (23+35+8+1+0=67;
  skips 0+0+1+0+0=1). Suite A count hand-verified (1 version + 3 gates +
  5 bash-n + 4 shim checks + 7 fixtures + 1 corpus + 1 op-failure +
  1 blockset = 23). Suite B hand-verified (14 gate_expect + 20 send_expect
  + 1 stdin-replay = 35).
- **Clopper-Pearson lower bounds** in the report are exactly right:
  0.025^(1/19)=0.8235 → "≥ 0.82", 0.025^(1/9)=0.6637 → "≥ 0.66",
  0.025^(1/8)=0.6306 → "≥ 0.63". Rounding *down* a lower bound preserves
  validity — the displayed claim is always true. The two-sided-α/2 choice
  matches the "95% CI lower bound" label.
- **Confusion matrix:** clean diagonal 19/9/8; caption, row/column headers
  correct; 3×3 is contract-grounded (gate-interface.md pins 0/1/2).
- **SHAPES ↔ stub-pattern alignment claim holds.** Compared
  `leakage-audit` SHAPES against `STUB_SECRET_CAND` alternative by
  alternative: identical except the audit uses the narrower forms
  `\b[0-9]{16}\b` and `\b3[47][0-9]{13}\b` where the stub uses the
  separator-tolerant `\b[0-9]{4}([- ]?[0-9]{4}){3}\b` and
  `\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b`. Audit ⊆ stub, as
  `patterns.sh` claims ("superset of the shapes the audit's fixture-purity
  check looks for"). No drift.
- **Fixture purity:** suite C green; every secret-shaped token extracted
  by SHAPES is declared in `SYNTHETIC.txt` (verified by reading both).
- **Fail-closed on weird exits:** rc=124 (timeout) and rc=137 (SIGKILL)
  never become a pass in `gate_expect`, `send_expect`, or
  `adversarial-run` — all produce findings/mismatches, never green.
- **Sentinel forgery guard (primary path):** sound. The runner prints all
  `@@@ ADV` lines itself; corpus names are line-based (no newlines
  possible), and `msent` neutralizes `@@@` in audit content. The report's
  primary regexes are line-anchored.
- **Badge logic:** green audit + adversarial mismatch → ATTENTION
  (verified in code path); stub F card renders purple, never green.

## P0

None. The currently-published figures all recompute exactly; no silent
pass found in the live code paths.

## P1 — structural: a headline number can stay green while the measurement degrades

### P1-1. No corpus-composition or total assertions anywhere; corpus shrink or tier reclassification stays green end-to-end
The report's deliberate design is "every number derived from the actual
run — nothing is hardcoded." The consequence: the corpus is its own
ground truth and there is no tripwire on what it contains.

- `leakage-audit` suite A asserts only `corpus_cases ≥ 1`.
- `adversarial-run` fails closed only on `total == 0`.
- CI (`validate.yml`) asserts `adversarial rc == 0` — it does **not** pin
  `36/36` or the 19/9/8 tier split (contrast: CI *does* pin the skip set
  to exactly 4 with named reasons).
- So: deleting 20 hard block-tier cases from the corpus, or reclassifying
  a block case to review-tier and rebuilding the blockset, yields a green
  run, green CI, and a CLEAN report whose headline quietly moves from
  "36/36" to "16/16". The CI lower-bound line would widen (honest), but
  nothing *fails*. The deferred iter-7 thread ("exact pass-total /
  adversarial-total assertions") and the ITERATIONS.md backlog
  ("corpus stays pinned at 36 unless revised"; "CI status/total
  assertions") both name this; it is still open.

Recommended: pin a corpus manifest in CI — expected total (36) *and*
per-tier counts (19/9/8), asserted from the `@@@ ADV MATCHED` /
`@@@ ADV TIERS` sentinels (not prose). Pinning totals alone is not enough:
a 36-case corpus with 0 block cases is a different measurement than
19/9/8. The manifest should live next to the corpus (e.g. a checked-in
`adversarial-corpus.manifest` or assertions in the workflow), so a
corpus edit without a manifest update fails loudly instead of silently
re-baselining the headline.

### P1-2. No probe-first / KNOWN-GAP methodology; a mismatch conflates "detector regressed" with "corpus label was wrong"
Every corpus `want` is an author assertion, and `adversarial-run` treats
any deviation as a failure (exit 1, ATTENTION badge). The failure message
does acknowledge the corpus can be wrong — "tighten the missing pattern
in $GATE **(or fix the corpus expectation)**" — but the *verdict* cannot
distinguish the two cases, and there is no KNOWN-GAP state anywhere in
the repo (grep: zero hits). The brief's deferred design — probe corpus
candidates against the real gate during expansion; record gate/author
disagreements as KNOWN-GAP rather than failing cases — does not exist.

This matters most for the real-target run, where it is genuinely
ambiguous whether a mismatch is a detector gap or a wrong `want`
(e.g. `clean_price`→2 and `phone_bare10`→0 are *policy* expectations,
not detection facts; a real gate with a public-figures allowlist would
"mismatch" `clean_price` and be marked as failing). Recommended: a
per-case marker (e.g. a 4th corpus field or a sidecar list) for
policy/residual expectations, surfaced in the report as tracked
KNOWN-GAP rows that do not flip the badge, plus a documented
probe-first workflow for adding cases (run candidate against the gate,
record verdict, set `want` from observed behavior or file a KNOWN-GAP).

### P1-3. The stub's 19/19 block figure is reconstruction, not validation — the corpus is both the training set and the test set
`build-blockset.sh` source (1) is "every adversarial-corpus case with
want=1": the block-tier tokens the stub detects are extracted from the
very corpus the runner tests. The 19/19 is therefore guaranteed by
construction; the only tripwire is staleness (`build-blockset.sh
--check` in suite A / CI), which catches "corpus changed, blockset not
rebuilt" but **not** "corpus and blockset changed together" (e.g. a hard
case quietly reclassified want=1→2 with a rebuilt blockset stays green).
The ITERATIONS.md backlog already lists "Independent extractor/blockset
ground truth" as pending — confirming this review's read. The report's
stub banner ("proves harness self-consistency, not detector quality")
is honest about the ceiling, but nothing measures *corpus label
correctness* itself. The P1-1 manifest plus the P1-2 probe-first workflow
are the mitigations; until then, treat the F-card figure as a
self-consistency checksum with an explicit label-validity caveat.

## P2 — arithmetic/display: the numbers shown don't always partition the numbers counted

### P2-1. Per-tier denominators don't sum to the headline total on timeouts or malformed lines (empirically confirmed)
In `adversarial-run`, the TIMEOUT branch and the MALFORMED branch do
`fail++` but never touch `f1/f2/f0`. Reproduced on /tmp copies:

- 2-case corpus, gate hangs on both → headline `0/2 cases matched`, but
  tiers read `block-tier pass 0/0 · review-tier pass 0/0 · clean pass 0/0`
  (denominators sum to 0, not 2 — the failed cases vanish from the tier
  breakdown).
- 3-case corpus with one `want=7` line → `2/3 cases matched`, tiers
  `1/1 · 0/0 · 1/1` (sum to 2, not 3).

The exit code is still fail-closed (1), but the tier lines — the figures
the report renders and CIs — silently drop cases. Fix: count
timeout/malformed cases in their tier's denominator (they are known from
`want`), or add an explicit "unverdictable" tier so the columns sum to
the total.

### P2-2. Vacuous tier green: a tier with zero cases reports "0/0" under a green headline (empirically confirmed)
Corpus with all 8 clean cases removed (28 cases remain): runner prints
`28/28 cases matched … clean pass 0/0`, exit 0, report CLEAN. The only
caveat is the small-print "clean: interval not computed (0/0)". Suite A
guards total ≥ 1, not per-tier ≥ 1 — so the false-positive-trap tier
(the corpus's entire defense against over-gating claims) can be emptied
without failing anything. The exit-3 guard in the runner checks
`total == 0` only. Fix: require every tier to be non-empty (fail closed
on any 0-denominator tier), consistent with the existing "0/0 is
vacuous" philosophy already applied to the empty corpus.

### P2-3. No duplicate corpus-name detection (empirically confirmed)
Appending a copy of the `stripe_live` line to a /tmp corpus copy yields
`37/37 cases matched … block-tier pass 20/20` — green, n silently
inflated. A duplicated hard case inflates its tier's n (and tightens the
displayed CI lower bound: 0.025^(1/20) > 0.025^(1/19) — the interval
*improves* from duplication). The report's per-case table would show two
identical rows; nothing flags it. Fix: assert unique case names in the
runner (fail closed on duplicates) — cheap, and it also protects the
report's `next((m for m in mismatches if m[0] == name))` attribution,
which is first-match-wins.

### P2-4. Corpus readers silently drop a final unterminated line; suite A's counter doesn't
Both `adversarial-run` and `build-blockset.sh` use
`while IFS='|' read …; do … done < "$CORPUS"`, which skips a last line
lacking a trailing newline. Suite A's counter (`grep -vcE
'^[[:space:]]*(#|$)`) counts it. The corpus currently ends with `\n`
(verified), so this is latent — but if an editor strips it, the audit
would claim N cases while the runner tests N−1 (and the blockset would
miss a want=1 token from the same line), all green. Fix: `while
IFS='|' read -r name want content || [ -n "$name" ]` in both readers, or
assert the trailing newline in suite A.

## P3 — nits and hardening

- **P3-1. Tri-state grouping mislabels non-standard exit codes.** The
  report's `tri_state_groups` uses `re.search(r"rc=(\d)", text)`, which
  matches the *first* `rc=` — the *want*, not the *got*. A gate killed by
  OOM (`want rc=1, got rc=137`) is filed under "Hard-block evidence —
  refused outright (rc=1)". Verified empirically. Fix: match the `got`
  code (`rc=(\d+)\D*$` or parse the parenthesized form).
- **P3-2. Per-case table shows malformed rows as ✓.** For a corpus line
  with `want=7`, the report's case loop sets `got = want` when no
  MISMATCH sentinel exists (malformed lines emit none), rendering a green
  checkmark for a case the runner counted as failed. The F-card callout
  still goes red via `adv` counts, but the row lies. Fix: mark rows whose
  `want` is outside {0,1,2} as errors.
- **P3-3. `ci_lower_95` comment misstates the statistics.** "Tiers that
  are imperfect or empty get no number — a made-up interval is worse than
  none." The exact Clopper-Pearson interval is well-defined for any k
  (via beta quantiles); it is not "made up". Omitting it is a defensible
  conservative choice, but the stated rationale is wrong — fix the
  comment, not the behavior.
- **P3-4. "Actual exit code" column shows `rc=TIMEOUT`.** TIMEOUT is not
  an exit code; the matrix correctly quarantines it as non-standard, but
  the per-case table prefixes it with `rc=`. Cosmetic; use a distinct
  marker.
- **P3-5. Timeout-budget asymmetry.** Audit gates get 30s
  (`gate_expect`/`send_expect`); corpus cases get 10s. A gate taking
  11–30s passes the audit but TIMEOUTs in `adversarial-run`, producing
  contradictory verdicts between the two halves of the report. Align the
  budgets or document the intended difference.
- **P3-6. Legacy fallback parser is forgable via corpus names.**
  `re.search(r"adversarial-run: (\d+)/(\d+) cases matched", …)` (and the
  tier regex) can match a crafted *case name* containing that literal
  substring. The primary sentinel path is immune (line-anchored,
  runner-printed prefix). Only the no-sentinel fallback is affected, and
  corpus names are version-controlled — but "case names are never
  trusted" is the stated invariant; the fallback breaks it.
- **P3-7. Report `scrub()` redacts only emails; failure evidence can
  carry fixture content.** `send_expect`'s failure evidence includes the
  fake binary's stdout; on the "should-have-been-blocked but the real
  binary was invoked" path, the `real-msg` fake echoes stdin between
  markers — i.e. fixture content lands in evidence, transcripts, and the
  HTML. All synthetic today, but the redaction story ("HTML redaction
  beyond email addresses", backlog) is incomplete. The messenger
  stdin-echo hashing deferred thread is the same gap.
- **P3-8. `wdetail` CTX routing is fragile.** Any evidence line starting
  with `"- "` is rerouted from check-evidence to suite-notes by
  `parse_machine`. Only suite E relies on this today; a future evidence
  line starting with `"- "` in another suite would be silently
  misattributed. Consider an explicit marker instead of a prefix sniff.
- **P3-9. Stale-number risk in prose.** `references/gate-interface.md`
  ("A 36/36 adversarial figure…") hardcodes the corpus size that the
  codebase deliberately refuses to hardcode; it will rot when the corpus
  changes. Same class as the P1-1 concern, doc-level.
- **P3-10. Suite-A comment-style divergence.** Suite A counts
  `^[[:space:]]*(#|$)` as comments, but the runner and `build-blockset.sh`
  only skip `#*`/`''` — an indented comment line would be counted by the
  audit and MALFORMED-fail the runner. Latent (no such lines today).

## Deferred-thread dispositions (iter-7 list)

| Thread | Status in this review |
|---|---|
| exact pass-total / adversarial-total assertions | **P1-1** — still open, confirmed absent in audit, runner, CI |
| duplicate corpus-name detection | **P2-3** — still open, confirmed exploitable |
| rc=137 handling | fail-closed everywhere (findings, never green); only the **P3-1** report label is wrong |
| slow/hanging/flaky stub fault variants | runner treats 124 as fail++; report quarantines as non-standard. No fault-injection fixtures exist; behavior is defined and fail-closed — coverage gap only, no finding |
| timeout-budget asymmetry | **P3-5** |
| SHAPES manifest / fixture-purity cross-check | design verified sound; alignment claim holds; no finding |
| near-miss / probe-first methodology | **P1-2** — still open, no KNOWN-GAP anywhere |
| report tri-state fallback | works; **P3-1** mislabel is the only defect |
| messenger stdin-echo hashing | **P3-7** — evidence/transcript path can carry fixture content; redaction is email-only |
| HTML redaction beyond email addresses | **P3-7** — same gap, backlog agrees |
| yellow-semantics consistency | out of measurement lens; no numeric claim found to dispute |

## Bottom line

The figures the project publishes today are honest and recompute exactly
— confusion matrix, CIs, suite totals, sentinel plumbing, fail-closed
timeouts. The integrity risk is not in the arithmetic but in the *frame*:
the corpus is its own ground truth with no composition tripwire (P1-1),
no way to separate "detector wrong" from "label wrong" (P1-2), and a
block-tier figure that is guaranteed by construction on the stub (P1-3).
The P2s are concrete arithmetic bugs (tier denominators, vacuous 0/0
tiers, duplicate names) with empirical reproductions above; all have
small, fail-closed fixes.
