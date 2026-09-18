# Iteration-7 review brief — Senior AI researcher

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior. Iteration 5 added the
KNOWN-GAP catalog, approval-isolation conformance (block-tier stays rc=1
even with MOCHI_EGRESS_APPROVED=1), confusion matrix, fixture-pass-rate
language.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire; live-fire safety hardening; report
honesty; CI readiness + synthetic stub skill; honest green; CI fails
honest.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-AI-researcher perspective, centered on the threat model.
No finding caps, no timeboxes, no diff-only scope. Write your findings
to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/06-airesearcher.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- Compositional exfiltration: chunked sends across sessions, subject/body
  field-splitting, encoding beyond single base64, spelled-out digits.
  The gate is stateless per call. Is the KNOWN-GAP catalog entry honest
  and complete, or does it understate the exposure?
- Suite/catalog residual divergence: do the attack-surface catalog rows
  match what the suites actually cover, case by case? Flag any row whose
  claim exceeds its enforcement.
- Approval-isolation conformance: iteration 5 added a block-tier +
  MOCHI_EGRESS_APPROVED=1 case expecting rc=1. Verify it is real and
  cannot be weakened by approval in any code path.
- Threat-model completeness: is there an exfiltration vector family
  entirely absent from the catalog (e.g., exfiltration via error
  messages, timing side channels, multi-turn accumulation)?
- Out-of-band egress: curl/webhook/non-shimmed CLI paths — cataloged as
  a scenario with honest residual, or missing?
- Corpus expansion methodology: any new corpus case must be
  probe-first (probe against the real gate; mismatches become KNOWN-GAP
  entries, never failing corpus cases). Is this methodology documented?

Do not propose fixes that expand scope beyond validation (the guard never
patches other systems). Keep findings actionable for one focused diff.

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
