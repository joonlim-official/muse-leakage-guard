# Iteration-6 review brief — Senior designer

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
from the senior-designer perspective. No finding caps, no timeboxes, no
diff-only scope: read any file in the repo, follow any thread, and report
every issue you find. Produce a findings list (each: severity, title,
evidence path/line, recommendation, residual if not fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- Report readability after iteration 5: the tri-state legend, the
  confusion matrix, the 95% CI bounds line, suite B's hard-block /
  approval-gated / pass-through evidence groups. Anything a mobile
  reader would misread? Anything that needs a visual hierarchy fix?
- Auto-expand behavior: red cards auto-expand, findings link to evidence
  cards. Is the "what do I look at first" journey right on a red report?
- The CI step summary (GitHub markdown) as a designed surface: if the
  audit is red, what does the author see? Is the failure diagnosable
  from the summary alone?
- Stub vs real-target visual distinction: is "SYNTHETIC STUB TARGET"
  unmistakable at a glance (banner, title, hero, footer)?
- The 3×3 confusion matrix: is it legible to a non-technical reader?
  Does the surrounding text explain what an off-diagonal cell means?

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
