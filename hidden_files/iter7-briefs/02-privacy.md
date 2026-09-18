# Iteration-7 review brief — Senior privacy engineer

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
$GITHUB_PATH, no sudo), `set -o pipefail`, sentinel-based job summary
(anchored @@@ parsing), `timeout -k` on all gate invocations plus
per-step timeout-minutes.

Already addressed in iterations 1–6 (context only — NOT a restriction on
your scope): opt-in live-fire mode with synthetic-data purge; live-fire
safety hardening; report honesty (SIMULATED vs LIVE-FIRE labels); CI
readiness + synthetic stub skill; honest green (tri-state verdicts,
confusion matrix, fixture-pass-rate language with 95% CI,
approval-isolation tests, stub hardening, widened fixture-purity SHAPES,
MIT LICENSE); CI fails honest (above).

Your task: perform a FULL-REPOSITORY, UNLIMITED-SCOPE, READ-ONLY review
from the senior-privacy-engineer perspective. No finding caps, no
timeboxes, no diff-only scope. Write your findings to
~/workspace/skills/muse-leakage-guard/hidden_files/iter7-reviews/02-privacy.md
(each finding: severity, title, evidence path/line, recommendation,
residual if not fixed).

Iteration-7 focus areas (leads, not limits — report anything you find):
- E3 trilemma: bare 9-digit SSN detection vs false-positive risk. Is the
  KNOWN-GAP marker honest, complete, and consistently worded wherever E3
  appears (catalog, report, README)?
- Report redaction: `scrub()` in bin/leakage-report is email-only.
  Secret-shaped tokens can reach the HTML via the fake Messenger
  delegate's stdin echo and the D-suite gate-log echo. Assess the real
  exposure and what a redaction pass reusing the audit's SHAPES set would
  cover.
- Fixture-purity SHAPES: iteration 5 widened it. Is it now a superset of
  the stub extractor's token classes, or are secret-shaped classes still
  invisible to the purity gate?
- Catalog corrections: C5 (defense-in-depth overstatement), A7, E3 rows —
  verify each row's claim matches what the suites actually enforce.
- Residual-gap documentation: compositional exfiltration and out-of-band
  egress — stated plainly as known gaps, or left unexamined?
- Synthetic fixture discipline: any fixture shape that could be mistaken
  for real PII by a reader or a scanner?

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
