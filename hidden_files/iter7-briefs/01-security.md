# Iteration-7 review brief — Senior security engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e20a819
"Iteration 6: CI fails honest".

What the repo is: a validation-only harness that audits an AI assistant's
private-memory leakage protection (egress gates, shims, brief gates) with
synthetic payloads and reports gaps. It never patches other systems, never
sends real data anywhere, and all fixtures are synthetic shapes belonging
to nobody. No live-fire in your review: run existing scripts in simulated
mode only; never set MOCHI_LIVE_FIRE=1; never touch local.env.

Iteration 6 added: honest CI failure behavior — skip pin recalibrated to
CI reality (4 honest skips), fail-at-the-end (every component step runs
even when red; exit codes captured to rc files; a final assert-green step
owns the job outcome), hermetic delegate provisioning ($RUNNER_TEMP via
$GITHUB_PATH, no sudo, no /usr/local/bin writes), `set -o pipefail` so a
red adversarial suite cannot report a green step, sentinel-based job
summary (anchored @@@ parsing instead of prose greps), `timeout -k` on all
gate invocations plus per-step timeout-minutes.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire mode with synthetic-data purge; live-fire
safety hardening (ownership checks, abort window, no-default email
target); report honesty (SIMULATED vs LIVE-FIRE labels); CI readiness +
synthetic stub skill; honest green (tri-state verdicts, confusion matrix,
fixture-pass-rate language with 95% CI, approval-isolation tests, stub
hardening, widened fixture-purity SHAPES, MIT LICENSE); CI fails honest
(above).

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-security-engineer perspective. No finding caps, no
timeboxes, no diff-only scope: read any file in the repo, follow any
thread, and report every issue you find. Write your findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/01-security.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- Stub contract conformance: the stub GWS shim does not gate the stdin
  form of raw MIME (references/gate-interface.md documents the stdin
  form; the audit tests only the argv form). Can a secret in raw MIME
  reach the stub un-gated?
- The stub's `die()` exits 2 (review-tier) where the contract expects 1.
  Trace the consequence through the audit's verdict logic.
- Delegate resolution self-exec loop: is delegate path resolution
  canonicalized with a self-guard, or can a delegate resolve to itself
  and loop?
- interface_version=1 is declared in references/gate-interface.md but
  never enforced anywhere. A v2 target would produce confusing per-check
  FAILs instead of one clean mismatch verdict.
- Iteration 6's fail-at-the-end: verify the assert-green step genuinely
  owns the job outcome on red. Any remaining silent `|| true` drops or
  unanchored prose greps in the workflow or summary step?
- Timeout rc=124 handling: is a timeout always treated as failure, never
  as pass? Probe suite B's fake-binary fidelity under forced timeouts.
- Out-of-band egress: curl/webhook/non-shimmed CLI paths — does the
  attack-surface catalog cover them, or does C5 overstate
  defense-in-depth?

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
