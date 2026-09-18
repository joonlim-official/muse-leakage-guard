# Iteration-6 review brief — Senior AI researcher

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
from the senior-AI-researcher perspective. No finding caps, no timeboxes,
no diff-only scope: read any file in the repo, follow any thread, and
report every issue you find. Produce a findings list (each: severity,
title, evidence path/line, recommendation, residual if not fixed).

Iteration-6 focus areas (leads, not limits — report anything you find):
- Adversarial corpus design: read bin/adversarial-corpus.txt and
  bin/adversarial-run. What attack classes are missing (encoding,
  Unicode, multiline, boundary cases, subject-line shapes, realistic
  MIME/multipart)? Note the corpus is pinned at 36 cases by the owner's
  constraint — frame findings as additions the harness should support
  or as documented limitations, not as corpus edits.
- The stub detector classifies by lookup in a declared block set
  derived from the same corpus it is tested against. Assess what this
  self-consistency loop can and cannot catch, and whether the
  documentation states the limitation precisely.
- Compositional/chunked exfiltration across calls is a tracked residual
  (suite E): is the residual description technically precise about why
  per-call gates cannot see it?
- The E3 scenario (bare 9-digit SSN false positives): assess the
  precision/recall trade-off framing.
- Independent extractor/blockset ground truth: what would an
  independent second implementation of the shape extractor buy, and
  what would it cost?

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
