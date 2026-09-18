# Iteration-6 review brief — Senior security engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: 5ff8950
"Iteration 5: honest green".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. Iteration 5 added: tri-state report verdicts (green/yellow/red
+ legend), approval-isolation tests (block-tier stays rc=1 even with
MOCHI_EGRESS_APPROVED=1), fixture-conformance language with a 3×3
confusion matrix and 95% CI bounds, stub input hardening (newline
separators, raw-MIME fail-closed), widened fixture-purity SHAPES, MIT
LICENSE, and report accessibility fixes.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-security-engineer perspective. No finding caps, no
timeboxes, no diff-only scope: read any file in the repo, follow any
thread, and report every issue you find. Produce a findings list (each:
severity, title, evidence path/line, recommendation, residual if not
fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- CI workflow (.github/workflows/validate.yml) safety: fork-PR shape
  (pull_request vs pull_request_target, permissions, SHA-pinned actions,
  shallow checkout, no secrets, local.env refusal, live-fire refusal).
  Any step where a compromised dependency could touch the stub gates?
- The "Provision inert delegate CLIs" step uses sudo to write to
  /usr/local/bin. Assess the risk and whether hermetic workspace-local
  delegates would be safer.
- Timeout failure modes: gates run under timeout 30s (rc=124). Is a
  timeout always treated as failure, never as pass? Probe suite B's
  fake-binary fidelity.
- The CI job-summary step greps human text ('block-tier recall'); the
  adversarial script now prints "block-tier pass", so that line silently
  vanishes (|| true). Assess how many other silent-failure greps exist.
- Interface-version enforcement: references/gate-interface.md documents
  interface_version=1. Does anything in the audit or CI verify the target
  honors the contract version it claims?

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
