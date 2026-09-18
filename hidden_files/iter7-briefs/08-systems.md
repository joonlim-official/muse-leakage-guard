# Iteration-7 review brief — Staff systems engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior. The stub skill
(test/stub-memory-skill/, interface_version=1) and references/gate-interface.md
define the contract the audit validates against.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire; live-fire safety hardening; report
honesty; CI readiness + synthetic stub skill; honest green; CI fails
honest.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the staff-systems-engineer perspective, centered on contract
conformance between the audit and the gate interface. No finding caps, no
timeboxes, no diff-only scope. Write your findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/08-systems.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- interface_version is declared (=1) in references/gate-interface.md but
  enforced nowhere. Design the enforcement point: where should a
  suite-A version check live, and what should the mismatch verdict look
  like (one clean verdict, not N confusing per-check FAILs)?
- Stub contract conformance gaps: the stub GWS shim does not gate the
  stdin form of raw MIME (contract documents it; audit tests only the
  argv form); the stub's die() exits 2 (review-tier) where the contract
  expects 1. Trace each through the audit's verdict logic.
- Delegate resolution self-exec loop: is the delegate path canonicalized
  with a self-guard, or can a delegate resolve to itself and loop?
- SHAPES manifest: the fixture-purity SHAPES set grew in iteration 5.
  Should it be a manifest YAML (declared classes, each with rationale
  and coverage) rather than an inline regex? Assess schema and coverage.
- Stub vs real target parity: run both audits; where do stub and
  real-target results diverge, and is each divergence intentional and
  documented?
- Catalog numbering: B18/B19 rows, E-numbering consistency across
  catalog, report, and README.

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
