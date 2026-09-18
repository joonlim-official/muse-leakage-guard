# Iteration-7 review brief — Senior designer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior (fail-at-the-end, rc
capture, assert-green owns outcome, hermetic delegates, sentinel-based
summary, timeout -k). Iteration 5 added tri-state report verdicts
(green/yellow/red + legend), confusion matrix, stub/skip card styles.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire; live-fire safety hardening; report honesty
(SIMULATED vs LIVE-FIRE labels); CI readiness + synthetic stub skill;
honest green; CI fails honest.

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-designer perspective, centered on the generated HTML
report (bin/leakage-report) and the docs/workflow presentation. No
finding caps, no timeboxes, no diff-only scope. Generate the report in
simulated mode and inspect it (desktop + narrow mobile widths). Write
your findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/04-designer.md
(each finding: severity, title, evidence path/line or screenshot
description, recommendation, residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- Red-path report bugs: do tri-state groups collapse correctly on red
  runs (rc= only in evidence)? Any "[B] [B]" duplication? Does the
  F-card say "Detection performance" on stub runs where it means fixture
  conformance? Confusion-matrix off-diagonal shading + explanation;
  plain-language gloss for the CI bounds; F-card subtotal framing.
- Card styles: the stub card wore the green verdict border; the skip
  card had no skip style and a meaningless "0 passed" subtotal. Verify
  the current .card.stub / .card.skip variants and matched/mismatched
  vocabulary.
- Confusion matrix readability: corner header wording, mobile layout,
  off-diagonal emphasis.
- Badge: tri-state collapsed into red — should yellow show amber
  ATTENTION?
- No-JS progressive enhancement: is the report fully readable with
  JavaScript disabled?
- Legend: is the green/yellow/red meaning unmistakable at a glance for
  a first-time reader?

Do not propose fixes that expand scope beyond validation. Keep findings
actionable for one focused diff.

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
