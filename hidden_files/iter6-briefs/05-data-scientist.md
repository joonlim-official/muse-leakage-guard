# Iteration-6 review brief — Senior data scientist

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: 5ff8950
"Iteration 5: honest green".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. Iteration 5 added: tri-state report verdicts, approval-isolation
tests, fixture-conformance language (pass rates, not recall/precision)
with a 3×3 confusion matrix and exact 95% Clopper-Pearson lower bounds
(19/19 → ≥0.82, 9/9 → ≥0.66, 8/8 → ≥0.63), stub input hardening, widened
fixture-purity SHAPES, MIT LICENSE, and report accessibility fixes.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-data-scientist perspective. No finding caps, no
timeboxes, no diff-only scope: read any file in the repo, follow any
thread, and report every issue you find. Produce a findings list (each:
severity, title, evidence path/line, recommendation, residual if not
fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- Measurement honesty post-iteration-5: verify the Clopper-Pearson
  bounds are computed and described correctly; check the confusion
  matrix construction (expected vs actual exit codes); any remaining
  ML-metric language anywhere (grep recall/precision/F1/accuracy).
- The CI summary greps human text ('block-tier recall') that no longer
  exists — assess sentinel-based parsing: bin/leakage-audit emits
  @@@ machine sentinels under MOCHI_AUDIT_MACHINE=1. Should the CI
  summary parse sentinels instead of prose?
- Deterministic artifacts: is the generated report deterministic
  (timestamps aside)? Could two green runs be diffed meaningfully?
- Independent ground truth: the stub's blockset is derived from the
  same corpus the adversarial suite tests (build-blockset.sh hashes
  corpus want=1 cases). Assess the circularity and what an independent
  extractor would look like.
- Near-miss negative traps: ways to stress the harness without changing
  the pinned 36-case corpus.

Do not propose fixes that expand scope beyond validation (the guard never
patches other systems). Do not propose changing the pinned 36-case
adversarial corpus unless you can justify revising the parent
constraint. Keep findings actionable for one focused diff.

> Privacy: least privilege. Use only the facts in this brief. If a step
> needs personal details (name, address, phone, email, payment, account
> identifiers, or anything about the user's family or finances), STOP and
> ask for that specific field — do not guess, do not fill it from any
> other context, and do not reuse personal info you may have seen
> elsewhere. Never type private data into a page, message, or form unless
> it was explicitly provided for that step in this task. Details given
> for one step stay in that step.
