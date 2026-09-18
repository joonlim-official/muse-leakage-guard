# Iteration-5 review brief — Senior security engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e4b2af1
"Iteration 4: CI readiness + synthetic stub skill".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. Iteration 4 added: a checked-in synthetic stub skill
(test/stub-memory-skill/) used as the audit target in CI
(.github/workflows/validate.yml runs pull_request only, contents: read,
SHA-pinned actions, no secrets), an interface contract
(references/gate-interface.md), and explicit labeling so a stub-target
green run cannot be mistaken for protection of a real installation.

Your task: review from the senior-security-engineer perspective and
produce a findings list (each: severity, title, evidence path/line,
recommendation, residual if not fixed).

Focus for iteration 5:
- The stub's fail-closed design: secret/figure/phone-shaped candidates
  not in the declared block set map to review-tier (rc=2). Assess whether
  any shape that should hard-block (rc=1) can slip to review-tier, and
  whether any review-tier shape can slip to clean (rc=0). Probe
  test/stub-memory-skill/bin/patterns.sh and bin/memory-egress-check.
- Attack-surface catalog gaps: read references/attack-surface.md (A–E
  scenarios) and identify one missing scenario or an under-scoped one.
- The CI workflow's safety shape: confirm no secret exfiltration path,
  no pull_request_target, no credential persistence; probe for any
  step where a compromised dependency could touch the stub gates.
- The iteration-4 block-set builder bug (corpus cases were concatenated
  without separators so greedy patterns fused adjacent tokens — now
  fixed with per-line hashing): assess whether similar silent-fusion
  risks remain anywhere a corpus/fixture is concatenated or streamed.

Do not propose fixes that expand scope beyond validation (the guard never
patches other systems). Keep findings actionable for one focused diff.

> Privacy: least privilege. Use only the facts in this brief. If a step
> needs personal details (name, address, phone, email, payment, account
> identifiers, or anything about the user's family or finances), STOP and
> ask for that specific field — do not guess, do not fill it from any
> other context, and do not reuse personal info you may have seen
> elsewhere. Never type private data into a page, message, or form unless
> it was explicitly provided for that step in this task. Details given
> for one step stay in that step.
