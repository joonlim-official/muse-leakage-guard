# Iteration-8 review brief — Senior designer

Shell convention: start every shell context with:
export PATH="$HOME/workspace/skills/personal-memory-system/bin/shims:$PATH"

REVIEW-ONLY TASK: read files and run existing scripts in simulated mode only.
Do not modify any file in the repo. Never set MOCHI_LIVE_FIRE=1. All test
payloads must remain synthetic — never use real personal data. Do not touch
~/workspace/your_files/ or any memory files. Never delete or overwrite local.env.

Repo: ~/workspace/skills/muse-leakage-guard, HEAD 2243723
("Iteration 7: contract conformance"), branch main. Public repo:
github.com/joonlim-official/muse-leakage-guard.

Context — what iterations 1–7 already handled (do not re-report as new findings
unless you found a regression):
1. Opt-in live-fire mode + synthetic-data purge
2. Live-fire safety hardening
3. Report honesty (SIMULATED vs LIVE-FIRE labels)
4. CI readiness + synthetic stub skill
5. Honest green (confusion matrix, fixture pass rates with 95% CI, fail-closed fixes)
6. CI fails honest (fail-at-the-end, pipefail, pinned totals)
7. Contract conformance (stdin MIME gating, draft token-confusion, delegate
   canonicalization, exit-code discipline, interface_version enforcement)

Iteration-8 direction from the project owner: the remaining iterations must
cover REPORT DESIGN QUALITY and READABILITY (visual polish, mobile UX, scannable
structure, plain language) alongside measurement integrity and red-path polish.
You LEAD the design-quality workstream this round.

Iteration-7 deferred threads (pick up if in your lens): exact pass-total /
adversarial-total assertions; duplicate corpus-name detection; rc=137 handling;
slow/hanging/flaky stub fault variants; timeout-budget asymmetry; SHAPES
manifest or fixture-purity cross-check; near-miss/probe-first methodology;
report tri-state fallback; messenger stdin-echo hashing; HTML redaction beyond
email addresses; yellow-semantics consistency.

YOUR LENS — senior designer. THOROUGH, FULL-SCOPE review: no scope limits, no
finding caps, no timebox. Focus: the GENERATED HTML REPORT as a designed
artifact. Generate it with bin/leakage-report (output to /tmp, never commit
it) and critique: visual polish (typography, spacing, color, hierarchy);
mobile UX (render at 390px width — check overflow, tap targets, readability);
scannable structure (can a reader get the verdict in 10 seconds? in 60?);
card design (headers, expandable evidence, status treatments incl. stub/skip
cards); information density vs whitespace; consistency of verdict treatments.
Findings must be concrete and implementable (e.g. "hero section needs X",
not "make it prettier"). Note anything you cannot evaluate without a browser
as a follow-up rather than a finding.

> Privacy: least privilege. Use only the facts in this brief. If a step
> needs personal details (name, address, phone, email, payment, account
> identifiers, or anything about the user's family or finances), STOP and
> ask for that specific field — do not guess, do not fill it from any
> other context, and do not reuse personal info you may have seen
> elsewhere. Never type private data into a page, message, or form unless
> it was explicitly provided for that step in this task. Details given
> for one step stay in that step.

Write your findings to:
~/workspace/skills/muse-leakage-guard/hidden_files/iter8-reviews/04-designer.md
Rank by severity (P0/P1/P2/P3). Verify `git status` is clean of your changes
at the end.
