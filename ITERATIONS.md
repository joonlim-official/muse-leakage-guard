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

## Backlog (iterations 4–10)
- CI + checked-in synthetic stub skill
- Measurement rigor: confusion-matrix framing, KNOWN-GAP markers
- Suite-B fake-binary fidelity and timeout coverage
- SHAPES manifest expansion
- Adversarial encoding/Unicode/multiline/boundary expansion
- Accessibility and visual polish
- Residual-gap documentation
- Final integration verification (diff through memory-egress-check,
  push, fresh report)
