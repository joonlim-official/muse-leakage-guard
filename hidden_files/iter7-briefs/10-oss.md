# Iteration-7 review brief — Open-source community maintainer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior (fail-at-the-end, hermetic
delegates, sentinel-based summary). Iteration 4 added CODEOWNERS,
CONTRIBUTING.md, and the synthetic stub skill; iteration 5 added the MIT
LICENSE.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire; live-fire safety hardening; report
honesty; CI readiness + synthetic stub skill; honest green; CI fails
honest.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the open-source-community-maintainer perspective, centered on the
newcomer and contributor experience. No finding caps, no timeboxes, no
diff-only scope. Write your findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/10-oss.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- CONTRIBUTING quickstart: can a newcomer run the suite verbatim on a
  fresh machine with copy-paste commands, or does it fail without
  undocumented setup (the "second executable CLI behind each shim"
  problem)? Is there an inert-delegate block contributors can paste?
- SECURITY.md: does it exist? Is there a responsible-disclosure path?
- README sync: residual table (9 rows, E-numbering) vs the catalog;
  README tagline — is it qualified so it cannot be read as a security
  guarantee? B18/B19 catalog rows present?
- LICENSE: MIT present (added iteration 5) — headers and attribution
  correct? Any file missing a license header that the project convention
  requires?
- Exit-code documentation for contributors: are rc=0/1/2/124 meanings
  documented?
- Issue/PR templates: would a first-time contributor know how to file
  a corpus case proposal (probe-first methodology) or report a
  false-positive?

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
