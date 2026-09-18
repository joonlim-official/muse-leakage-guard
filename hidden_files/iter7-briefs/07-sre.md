# Iteration-7 review brief — Senior SRE

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior — fail-at-the-end (if:
always() guarded by refuse-step outcomes; rc capture; assert-green owns
the job outcome), hermetic delegates ($RUNNER_TEMP, no sudo), pipefail,
sentinel-based summary, timeout -k on all gate invocations, per-step
timeout-minutes, skip pin at 4 honest skips.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire; live-fire safety hardening; report
honesty; CI readiness + synthetic stub skill; honest green; CI fails
honest (above).

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-SRE perspective, centered on operational reliability. No
finding caps, no timeboxes, no diff-only scope. Write your findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/07-sre.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- Fake-binary fidelity: do the fake binaries faithfully model the real
  gates' timing, exit codes, and failure modes? Any fidelity variant
  missing (slow gate, flaky gate, gate that hangs past timeout -k)?
- Pinned pass totals: does CI assert exact expected pass/skip counts so
  a silently dropped case fails the job instead of going green?
- Iteration-6 verification: re-verify the fail-at-the-end behavior end
  to end — force a red component and confirm the job still produces the
  report artifact and the summary, then fails via assert-green. Any
  remaining path where red reports green?
- Operational runbook: is there a documented "audit went red in CI,
  what now" path for the repo owner?
- local.env in CI: refused cleanly with a clear message? Any path where
  a contributor's local.env could leak into CI logs or artifacts?
- Nightly-evaluation wording: any remaining contradictions in scheduled
  wording or docs about what runs when?

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
