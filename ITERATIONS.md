# Iteration log — muse-leakage-guard 10-iteration improvement loop

Each iteration: 10 persona reviews in parallel (security, privacy, PM,
designer, data scientist, AI researcher, SRE, systems, accessibility,
open-source maintainer) → synthesis → one focused diff → full validation
(`bash -n`, `bin/leakage-audit` CLEAN, `bin/adversarial-run` 36/36) →
one commit. Guard stays validation-only; synthetic fixtures only.

## Iteration 1 — Opt-in live-fire + synthetic-data purge
Commit `6815755` (+ supporting `8fc1f89`, `4ce7139`).
Added live-fire mode (real sends to the owner's own accounts) and the
fixture-purity manifest. Disclosure: ~6–8 synthetic emails reached the
owner's inbox during validation instead of the intended three; the
iteration-2 CHANGELOG corrects the record.

## Iteration 2 — Live-fire safety hardening
Commit `66ccac0`. Gmail ownership verified via read-only getProfile; no
default `MOCHI_TEST_EMAIL`; `MOCHI_LIVE_FIRE=1` must be inline per
invocation; noninteractive live-fire fails closed; genuine binaries
required; Messenger target must resolve to exactly one participant (the
owner); 10s TTY abort window; argument guards; mode-aware output.
Validation: audit 58 passed / 0 failed / 1 skipped — CLEAN;
adversarial 36/36. Disclosures: coordinator deleted and reconstructed
`local.env` (verified intact); pre-purge private values remain in public
history around `918e243` — no rewrite without the owner's decision;
iteration-1 CHANGELOG overstated email-ownership safety.

## Iteration 3 — Report honesty and parser hardening
Theme: the report can no longer say things the run did not prove.
- Audit emits machine-readable `@@@` sentinels under
  `MOCHI_AUDIT_MACHINE=1`; report parses sentinels first, hardened text
  scrape as fallback, refuses to write HTML on unparseable output
  (exit 3). Unknown mode → `UNKNOWN`, never SIMULATED.
- Adversarial results in the report: per-tier figures (block 19/19,
  review 9/9, clean 8/8) + per-case table; mismatches force ATTENTION.
- Hardcoded blurbs replaced by execution-derived descriptions.
- Report privacy: email redaction, argv-hash evidence, domain-only
  identity comparison.
- Red-team fidelity: invocation sentinel files, 30s timeouts, SHAPES
  gains `sk-…`/`AKIA…` (3 undeclared synthetic tokens reviewed+declared).
- Accessibility: native buttons, named regions, landmarks, reduced-motion.
- Operational: atomic writes, unique filenames, `-h|--help`, transcript
  `<details>`, correct report-dir gitignore.
Validation: audit 58 passed / 0 failed / 1 skipped — CLEAN;
adversarial 36/36; machine and legacy parsers agree on all 6 callouts;
doctored failure inputs verified (ATTENTION badge, Findings, exit 1).

## Iteration 4 — CI readiness + synthetic stub skill
Theme: the harness validates itself in public CI without any private
installation — and no one can mistake that self-check for protection.
- New `test/stub-memory-skill/`: a checked-in synthetic test double with
  the same gate/shim interface (documented contract
  `references/gate-interface.md`, `interface_version=1`). Its detector
  extracts public token shapes and classifies by lookup in a declared set
  of synthetic block-tier tokens (`bin/blockset.txt`, derived by
  `build/build-blockset.sh` from corpus want=1 cases + declared
  fixtures; `--check` proves the checked-in set is current). It is not a
  detector and not a protection layer — the README says so in so many
  words; never deploy it.
- The audit detects `.synthetic-stub`, prints/emits
  `target-kind: SYNTHETIC STUB` (`STUBKIND` sentinel), and refuses
  live-fire against stub targets (exit 2). Fixture-purity inspection now
  covers stub fixtures; the `gsk_` shape joined the pattern manifest.
- The report banners stub targets (banner + title + hero + footer), shows
  a "Stub consistency" callout instead of "Detection performance",
  qualifies stub results as harness self-consistency, and exposes a real
  accessible "match" table header plus visually hidden status text.
- New `.github/workflows/validate.yml` (`pull_request`, never
  `pull_request_target`; `contents: read`; SHA-pinned actions; shallow
  checkout; no secrets; live-fire variables refused; `local.env` refused;
  skip set pinned at exactly 2; report artifact 14 days; step summary).
  Plus `CODEOWNERS` and `CONTRIBUTING.md` (stub-first quickstart).
- Attack-surface catalog gains E2 (stub-validation mistaken for real
  protection → PROTECTED by labeling + refusal), mapped in the test
  matrix. Fixture swap: AWS-shaped `aws_key` → synthetic Groq
  `gsk_` case (prior AWS coverage documented in iteration 3 remains
  historically accurate).
Validation: audit 57 passed / 0 failed / 2 skipped — CLEAN (pinned skips:
memory-audit, gate-log); adversarial 36/36 vs stub (block 19/19, review
9/9, clean 8/8) and 36/36 vs the real local installation (regression);
real-target audit still 58/0/1 CLEAN. Bug found and fixed mid-iteration:
the block-set builder concatenated corpus cases without separators, so
greedy shape patterns fused adjacent tokens into hashes that never occur
at runtime (3 mismatches) — now hashed per line.

## Iteration 5 — Honest green
Theme: the report tells the truth about what green means — tri-state
verdicts, fixture-conformance language, and statistical humility.
- Tri-state semantics with an explicit legend: green = well protected
  (block-tier, rc=1), yellow = protected through approval (review-tier,
  rc=2), red = can leak. Tracked residuals are neutral white (never
  yellow); stub self-consistency is purple (never a green protection
  card); a suite that ran nothing renders severe red.
- "Recall"/"precision" replaced by block/review/clean *pass rates*; the
  corpus is stated to be author-designed regression fixtures, not a
  real-world sample; new 3×3 expected-vs-actual exit-code confusion
  matrix; exact 95% Clopper-Pearson lower bounds per tier (19/19 →
  ≥0.82, 9/9 → ≥0.66, 8/8 → ≥0.63).
- Suite B proves approval isolation: block-tier stays rc=1 even with
  `MOCHI_EGRESS_APPROVED=1` (gmail + messenger); suite B evidence is
  split into hard-block / approval-gated / pass-through groups.
- Stub hardening: newline separators when concatenating fixtures
  (`memory-egress-check`, `build-blockset.sh`); stub shim raw-MIME
  decode fails closed (refuses the send) when python3 is missing, JSON
  is malformed, or `raw` is undecodable.
- Fixture-purity SHAPES widened to the stub's candidate shapes (bare
  9-digit SSN, bare 16-digit card, 15-digit Amex, `api_key=`/`password=`/
  `passwd=` values; 8 new synthetic tokens declared).
- Known gaps: suite E tracks chunked/compositional exfiltration,
  out-of-band egress (curl/webhooks/unshimmed CLIs — only shimmed paths
  are gated), and B4 attachments; new scenario E3 (bare 9-digit SSN
  false-positive trade-off); A7 labeled syntactic/static.
- MIT LICENSE + README license section; attack-surface/test-matrix join
  CODEOWNERS; README quickstart gains copy-paste inert delegates with
  PATH-ordering notes; "36/36" → "every corpus case matched" in general
  docs; `MOCHI_TEST_EMAIL` clarified as live-fire-only.
- Report a11y: no heading-in-button, transcript h2/details hierarchy,
  table captions + expected/actual headers + row headers, aria-hidden
  glyphs, darker muted text, focus-visible summaries, footer outside
  `<main>`, empty evidence/all-zero subtotals suppressed, red cards
  auto-expanded, findings link to evidence cards. Bug found and fixed
  mid-iteration: the F card rendered red instead of purple on stub
  targets (synthetic suite has no checks/notes, tripping the new
  unknown-severe rule) — adv data now counts as card content; plus a
  red ATTENTION badge (not CLEAN) when the adversarial suite mismatches
  under a green audit.
Validation: audit 60 passed / 0 failed / 1 skipped — CLEAN (real target
and stub target; +2 approval-isolation tests); adversarial 36/36 on both
targets (block 19/19, review 9/9, clean 8/8); `build-blockset.sh
--check` current; `bash -n` on all touched scripts; forced-failure run
verified red report (exit 1, ATTENTION badge, findings with evidence
links, off-diagonal confusion matrix); desktop + mobile screenshot QA.

## Iteration 6 — CI fails honest
Theme: the CI workflow tells the truth in both colors — fail-at-the-end
with rc-file capture, hermetic delegates, sentinel-based summary, and a
corrected 4-skip pin (the old 2-skip pin meant CI could never be green).
- Fail-at-the-end: every component step `if: always()` (guarded by both
  refuse-step outcomes), rc files, final assert-green step owns the job
  outcome; red runs still produce logs, report, artifact, and a summary
  naming the red components.
- Hermetic delegates in `${{ runner.temp }}/delegates` (no sudo, no
  /usr/local/bin); PATH-lookup smoke test.
- Adversarial exit code preserved via `PIPESTATUS[0]`; new `@@@ ADV`
  machine sentinels (MATCHED / TIERS / MISMATCH) parsed by the summary
  and the report (sentinel-first, regex fallback).
- Summary rebuilt on anchored `@@@` sentinels: explicit Outcome word
  (CLEAN/ATTENTION/INCOMPLETE/BLOCKED), per-component table, missing
  sentinels render "unavailable". Dead `block-tier recall` grep removed.
- Timeout hardening: `timeout -k` on all gate invocations; report wraps
  subprocesses in `timeout -k 10 600`; per-step `timeout-minutes`.
  Fixed the report's `$?`-after-`if !` exit-code capture bug.
Validation: stub audit 60 passed / 0 failed / 1 skipped (local) and 57 /
0 / 4 (CI-equivalent fresh HOME); adversarial 36/36; forced-red audit
→ report rc=1 with file written; forced adversarial mismatch →
sentinel flows to report ATTENTION; summary ATTENTION on red logs.

## Iteration 7 — Contract conformance
Theme: the stub honors its contract; the audit enforces what the
contract claims; the catalog and matrix say only what the suites
enforce.
- Stub: GWS shim gates the stdin form of raw MIME (was ungated
  fail-open); stdin bytes replayed byte-identical on allow;
  `--draft`/`--dry-run` honored only as flags, never as flag values
  (token-confusion bypass closed); drive `permissions create` matched
  positionally (no anywhere-token false positives); canonicalized
  delegate resolution + self-identity refusal (fail closed);
  `+send` gates `to` as well as subject/body; `memory-egress-check`
  operational failures exit 1 (fail closed, never approvable).
- Audit: suite A enforces `interface_version` as the first check
  (mismatch → one FAIL, ATTENTION, exit 1); distinct-delegate assertion
  by canonical path identity; stub-only operational-failure approval
  isolation; suite B pins stdin-form blocked/clean, draft
  token-confusion, positional drive-match; live-fire sends wrapped in
  `timeout -k 10 30`.
- Docs: `gate-interface.md` gains machine-readable `contract_version:
  1`; `attack-surface.md` C5 qualified (shimmed paths only), A7 marked
  POLICY-ONLY, KNOWN GAP defined; `test-matrix.md` Covered-by
  corrections; README residual list all ten, matching suite E.
Validation: stub + real audit CLEAN; adversarial 36/36 both targets;
`build-blockset.sh --check` current; `bash -n` all touched scripts.

## Iteration 8 — Report integrity and readability
Theme: the report tells the truth in plain language and is readable by
everyone, including keyboard and screen-reader users.
- Badge integrity: CLEAN requires audit CLEAN + adversarial rc 0 +
  parseable figures; a runner exiting 0 without figures renders
  ATTENTION, not CLEAN.
- Card B (gate effectiveness): tri-state callout — N blocked outright ·
  N protected through approval · N allowed normally — so rc=2
  approval-gated checks are never reported as plain green; evidence
  grouped under 🟢/🟡/⚪ labels.
- Card D (gate audit-log review): gate-log context rendered as evidence,
  matching the card's promise.
- Card E (known gaps): each residual gets a plain-language gloss with the
  technical note retained; "N tracked · 0 hidden".
- Plain language: invoked=0/1 → "real tool never called"/"delivered
  normally"; CLEAN/ATTENTION/INCOMPLETE defined under the badge; local
  time with UTC original; known-gap jargon glossed.
- Adversarial card: runner-only mismatches as labeled drift rows; matrix
  corner "expected vs actual"; "Worst case consistent with these results
  (95% lower bound)" replaces the unexplained Clopper-Pearson label.
- Accessibility: skip link, h2-wrapped card headings, red cards
  pre-expanded server-side (no-JS fallback CSS), keyboard-focusable
  scroll regions and transcripts, unique finding link labels, focus
  styles, light/dark link colors, labeled "Overall result" total.
- Adversarial runner: timeout failures count in the expected tier's
  denominator (no disappearing from tier totals).
Validation: stub + real audit CLEAN; adversarial 36/36 both targets;
forced ATTENTION paths verified in the report renderer.

## Iteration 9 — Fail-closed gates + red-team coverage of critical send paths
Theme: every way a send could dodge the gate is now closed, tested, and
pinned — abnormal detector exits fail closed, and every critical send
path (reply-all, forward, `--`, drafts send, settings mutations,
messenger edit) is red-teamed with fake delegates.
- Protection layer (muse-memory, pushed separately): egress/brief gates
  fail closed on abnormal detector exits (rc outside {0,1,2} → rc=1,
  never 2); Gmail `+reply-all` gated; post-`--` positionals gated;
  `users drafts send` fetches the draft read-only, decodes its body,
  and gates it (unfetchable draft refuses closed); settings mutations
  (auto-forwarding, delegates, filters, send-as) approval-gated;
  undecodable raw MIME refuses closed; Messenger post-`--` gated.
- Audit: fail-closed probes (crashing rc=3 / killed rc=137 detectors) on
  both gates, every target; reply-all/forward/`--`/drafts-send/settings/
  messenger-edit probes; fake delegate supports read-only drafts-get with
  separate fetch/send sentinels; gate-decision logging mechanically
  asserted (suite B); memory-audit findings and suite-D contexts reduced
  to counts (evidence hygiene); empty gate log warns instead of passing
  silently; `WARNINGS` machine sentinel end-to-end.
- Stub: both gates now log every decision (contract requirement), so the
  logging assertion is testable against the stub too.
- Report: `[B] [B]` double-prefix fixed; ATTENTION-via-adversarial always
  ships a finding (no empty Findings section); skipped checks no longer
  double-counted as "other" in the gate-effectiveness callout; warnings
  shown in the hero; UTC parenthetical dropped when the reader is in UTC.
- CI: composition pinned — `@@@ TOTAL 83 0 4` and `@@@ ADV MATCHED 36/36`
  asserted, so deleting checks or corpus cases cannot stay green.
- Docs: gate-interface.md pins the new paths and fail-closed rule;
  attack-surface.md gains A9–A13 and names import/insert and
  chat/calendar as open gaps; test-matrix.md and README/suite-E
  residuals converged; ITERATIONS.md reordered (5 before 6) and gained
  the missing 7 and 8.
Validation: stub audit 86/0/1 CLEAN, real audit 82/0/5 CLEAN;
adversarial 36/36 both targets (block 19/19, review 9/9, clean 8/8);
`build-blockset.sh --check` current; `bash -n` all touched scripts;
report regenerated and screenshot-QA'd (desktop + mobile); real gate
log verified unpolluted by validation runs.

## Iteration 10 — Verify the write-time guard (memory-guard probes)
Theme: the write-time control behind the D1/D2 catalog claims is now
verified, not just catalogued — the least-examined, most-exercised
control (the daily refresh writes memory every morning) gets the same
fixture-conformance treatment iteration 9 gave the send plane.
- Audit: suite A asserts `bin/memory-guard` present/executable/parses;
  suite C (renamed "Attack-surface coverage (controls verified in
  place)") gains six behavioral probes via a `guard_expect` helper
  (`timeout -k`, rc comparison): synthetic secret → rc=1, figure → rc=2,
  phone → rc=2, clean → rc=0, allowlisted figure → rc=0, allowlisted secret
  → still rc=1. Probes pass explicit fixture paths and a controlled
  `/tmp` allowlist only — never the default tree or the real allowlist —
  and compare exit codes alone.
- Stub: new `bin/memory-guard` test double under the existing five-rule
  fidelity contract (same CLI, lookup-based verdicts, undeclared
  secret-shaped → rc=2 fail-closed, missing blockset → rc=1, labeled
  non-protection in header + stub README); deliberately differs from the
  real tool (pattern-based block) and says so.
- Contract: `references/gate-interface.md` gains an additive "Write-time
  interface (memory-guard)" section; `contract_version` stays 1.
- Report: suite-C `tested_blurb` derives static/probe counts from the
  run's check-name prefixes (never hardcoded).
- CI: composition pin `@@@ TOTAL 83 0 4` → `@@@ TOTAL 91 0 4` in the same
  commit; syntax-check list gains the new double.
- Docs: attack-surface D1/D2 and test-matrix D1/D2 now say "verified by
  red-team (suite C write-time probes)"; SKILL.md item 3 extended.
Validation: stub audit 94/0/1 CLEAN, real audit 90/0/5 CLEAN;
adversarial 36/36 both targets (block 19/19, review 9/9, clean 8/8);
CI-equivalent run confirms `@@@ TOTAL 91 0 4` with the 4 pinned skips;
`bash -n` on all touched scripts; report regenerated and screenshot-QA'd
(desktop + mobile); card-C blurb verified against the run.

## Backlog (iterations 6–10)
- ~~Measurement rigor: confusion-matrix framing, KNOWN-GAP markers~~ (done, iteration 5)
- Suite-B fake-binary fidelity and timeout coverage
- ~~SHAPES manifest expansion~~ (done, iteration 5)
- Adversarial encoding/Unicode/multiline/boundary expansion
- ~~Accessibility and visual polish~~ (substantially done, iteration 5; final polish remains)
- ~~Residual-gap documentation~~ (done, iteration 5)
- Interface-version enforcement and contract conformance
- Machine-readable residual/scenario source of truth
- Timeout and fake-delegate failure-mode tests
- Realistic MIME/multipart and subject-line coverage
- Report transcript secret-shaped-token redaction
- Independent extractor/blockset ground truth
- Near-miss negative traps (corpus stays pinned at 36 unless revised)
- CI status/total assertions and deterministic artifacts
- Final integration verification (diff through memory-egress-check, push, fresh report)

## Post-loop backlog (explicitly deferred from iteration 10 — not dropped)
- ~~memory-guard write-time probe + allowlist exercise~~ (done, iteration 10)
- Live-fire guard CI assertions: exit-2 on stub target, exit-2 when
  `MOCHI_LIVE_FIRE` comes only from `local.env`, non-TTY refusal — all
  CI-safe (no sends possible); test shapes recorded in the iter-10 SRE
  review (`hidden_files/iter10-reviews/07-sre.md`).
- Adversarial evasion depth: case/whitespace/punctuation variants,
  multi-tier payloads, near-miss negatives (corpus + blockset + CI pin in
  lockstep; corpus stays pinned at 36 unless revised).
- Machine-readable residual source of truth (suite E, attack-surface.md,
  and README enumerations asserted to agree).
- `.egress-allowlist` block-tier immunity probe (send plane).
- B2/B3 git-history scan (needs a redaction design before CI logs can
  carry it).
- SECURITY.md, issue/PR templates, CONTRIBUTING canonical quickstart,
  exit-code reference, TOC, fixture-recipient ground rules.
