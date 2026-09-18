# Iteration-6 review brief — Senior site reliability engineer

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
from the senior-SRE perspective. No finding caps, no timeboxes, no
diff-only scope: read any file in the repo, follow any thread, and report
every issue you find. Produce a findings list (each: severity, title,
evidence path/line, recommendation, residual if not fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- CI fail-at-the-end: in .github/workflows/validate.yml, if the audit
  step fails, the skip-assertion, adversarial, and report steps are
  skipped (only upload/summary have `if: always()`). Design the
  fail-at-the-end shape: every component runs even when red, component
  outcomes are captured, and a final step asserts green. What should the
  job summary show when each component is red?
- Hermetic delegates: the "Provision inert delegate CLIs" step uses
  sudo to write /usr/local/bin/hatch_gws_cli and
  /usr/local/bin/hatch_messenger_cli. Assess and propose the hermetic
  alternative (workspace-local or runner-temp binaries on PATH).
- Timeout and fake-delegate failure-mode tests: suite B uses fake
  binaries and 30s timeouts (rc=124). Are timeout outcomes asserted as
  failures, never passes? Is there a test where the fake delegate
  itself fails?
- The pinned skip set (exactly 2 skips asserted in CI): assess whether
  pinning is brittle or valuable; what happens when a legitimate third
  skip appears?
- The 20-minute job timeout vs actual runtimes: any step that could
  hang past it (the audit's own timeouts, the report's Python)?

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
