# Iteration-6 review brief — Staff systems engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: 5ff8950
"Iteration 5: honest green".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. Iteration 5 added: tri-state report verdicts, approval-isolation
tests, fixture-conformance language with a 3×3 confusion matrix and 95%
CI bounds, stub input hardening, widened fixture-purity SHAPES, MIT
LICENSE, and report accessibility fixes.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the staff-systems-engineer perspective. No finding caps, no
timeboxes, no diff-only scope: read any file in the repo, follow any
thread, and report every issue you find. Produce a findings list (each:
severity, title, evidence path/line, recommendation, residual if not
fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- Interface contract conformance: references/gate-interface.md documents
  the gate/shim contract (interface_version=1, exit-code tiers). Does
  the audit verify the target honors the contract (e.g. read the
  .synthetic-stub marker's interface_version, reject mismatches)?
  Does the stub itself conform (check bin/shims/* against the contract)?
- Delegate resolution order: the audit requires a second distinct
  executable behind each shim on PATH. Trace MOCHI_REAL_HATCH_GWS_CLI /
  PATH resolution in both bin/leakage-audit and the stub shims. Any
  order where the shim resolves to itself?
- Machine sentinels: bin/leakage-audit emits @@@ sentinels under
  MOCHI_AUDIT_MACHINE=1. The CI summary instead greps human text
  ('block-tier recall' — which no longer exists). Assess sentinel
  coverage: which CI assertions could parse sentinels, and which
  sentinels are missing?
- The stub's raw-MIME fail-closed path (iteration 5): trace the code —
  is "refuse the send" actually reached when python3 is missing,
  or does the caller treat the refusal as clean?
- Atomic writes and unique filenames in bin/leakage-report: assess
  for TOCTOU or collision issues under concurrent runs.

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
