# Iteration-7 review brief — Senior data scientist

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior (fail-at-the-end, rc
capture, assert-green owns outcome, hermetic delegates, sentinel-based
summary, timeout -k). Iteration 5 added fixture-conformance language with
a 3x3 confusion matrix and 95% CI bounds (fixture CI, not population
recall).

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire; live-fire safety hardening; report
honesty; CI readiness + synthetic stub skill; honest green; CI fails
honest.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-data-scientist perspective, centered on measurement
integrity. No finding caps, no timeboxes, no diff-only scope. Write your
findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/05-datascientist.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- Corpus-integrity guards: are duplicate case names detected? Is `|` in
  case content (the field separator) rejected or escaped? What happens
  to a MALFORMED corpus line — is it itemized or silently dropped?
- Blockset anchoring: is the block-set builder anchored to SYNTHETIC.txt
  declarations (only hashing declared synthetic shapes), or can it hash
  arbitrary adjacent tokens?
- Near-miss corpus input: supplemental near-miss cases that probe the
  boundary between block-tier and review-tier. Methodology must be
  probe-first: each candidate probed against the real gate; mismatches
  become KNOWN-GAP entries, not failing corpus cases.
- CI labeling: is the 95% CI presented as two-sided and labeled as a
  fixture CI (author-designed 36-case set, not a sample), never as
  population recall/precision?
- Confusion matrix: is the expected-x-got framing complete (block /
  review / clean on both axes), with off-diagonal cells explained?
- Pinned pass totals in CI: does CI assert exact expected pass/skip
  counts so a silently dropped case would fail the job?

Do not propose fixes that expand scope beyond validation (the guard never
patches other systems). Do not propose changing the pinned 36-case
adversarial corpus unless you can justify revising the parent
constraint. Keep findings actionable for one focused diff.

Shell convention: start every shell context with
export PATH="$HOME/workspace/skills/personal-memory-system/bin/shims:$PATH".

> Privacy: least privilege. Use only the facts in this brief. If a step
> needs personal details (name, address, phone, email, payment, account
> identifiers, or anything about the user's family or finances), STOP and
> ask for that specific field — do not guess, do not fill it from any
> other context, and do not reuse personal info you may have seen
> elsewhere. Never type private data into a page, message, or form unless
> it was explicitly provided for that step in this task. Details given
> for one step stay in that step.
