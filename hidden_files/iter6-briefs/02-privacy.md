# Iteration-6 review brief — Senior privacy engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: 5ff8950
"Iteration 5: honest green".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. Iteration 5 added: tri-state report verdicts (green/yellow/red
+ legend), approval-isolation tests, fixture-conformance language with a
3×3 confusion matrix and 95% CI bounds, stub input hardening, widened
fixture-purity SHAPES, MIT LICENSE, and report accessibility fixes.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-privacy-engineer perspective. No finding caps, no
timeboxes, no diff-only scope: read any file in the repo, follow any
thread, and report every issue you find. Produce a findings list (each:
severity, title, evidence path/line, recommendation, residual if not
fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- Report transcript redaction: bin/leakage-report scrubs secret-shaped
  tokens from captured transcripts (scrub()). Probe for shapes it misses
  (the new E3 identifier-shape cases, card-number shapes, credential
  assignment shapes) and any path where an unredacted transcript reaches
  the HTML.
- argv-hash evidence: is any secret-shaped token still echoed in report
  evidence sections?
- Synthetic-data discipline in CI artifacts: the uploaded report and
  step summary — any chance a real value (not synthetic) could appear
  there? (CI runs against the synthetic stub only.)
- The new E3 scenario (bare 9-digit SSN false-positive trade-off):
  assess whether the documentation states the false-positive cost
  honestly.
- Near-miss negative traps: could the harness add adversarial near-miss
  cases without changing the pinned 36-case corpus?

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
