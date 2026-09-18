# Iteration-6 review brief — Open-source community maintainer

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
from the open-source-community-maintainer perspective. No finding caps,
no timeboxes, no diff-only scope: read any file in the repo, follow any
thread, and report every issue you find. Produce a findings list (each:
severity, title, evidence path/line, recommendation, residual if not
fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- Newcomer workflow: follow README/CONTRIBUTING's quickstart cold
  (stub-first). Where does it break, confuse, or assume unstated
  knowledge? (PATH-ordering notes were added in iteration 5 — are they
  sufficient?)
- Fork-PR contributor experience: the CI workflow runs on pull_request
  with contents: read. If a fork PR fails, can the contributor diagnose
  it from the summary and artifacts alone? (Note: if the audit step
  fails, later steps are skipped — only upload/summary run.)
- Docs accuracy: any place where docs describe behavior the code no
  longer has? (Known example: the CI summary greps 'block-tier
  recall' but bin/adversarial-run now prints "block-tier pass", so
  that summary line silently vanishes. Find others like it.)
- The remaining hardcoded "36/36" in SKILL.md:116 and references/
  files: acceptable (specific stub-consistency context) or should they
  say "every corpus case matched"?
- LICENSE/CONTRIBUTING/CODEOWNERS coherence for a first external
  contributor: is anything missing (e.g. how to run the suite without
  the owner's real installation)?

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
