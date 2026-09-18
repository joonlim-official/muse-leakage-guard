# Iteration-8 review brief — Senior data scientist

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

Iteration-7 deferred threads (pick up if in your lens): exact pass-total /
adversarial-total assertions; duplicate corpus-name detection; rc=137 handling;
slow/hanging/flaky stub fault variants; timeout-budget asymmetry; SHAPES
manifest or fixture-purity cross-check; near-miss/probe-first methodology;
report tri-state fallback; messenger stdin-echo hashing; HTML redaction beyond
email addresses; yellow-semantics consistency.

YOUR LENS — senior data scientist. THOROUGH, FULL-SCOPE review: no scope
limits, no finding caps, no timebox. Focus: MEASUREMENT INTEGRITY. Do the
numbers mean what they say? Exact pass-total and adversarial-total assertions
(hardcode expected counts?); duplicate corpus-name detection; confusion-matrix
correctness (expected x got); fixture pass-rate language and CI caveats (95%
exact CIs); near-miss / probe-first methodology for corpus expansion (probe
candidates against the real gate; mismatches become KNOWN-GAP, not failing
cases); SHAPES manifest or fixture-purity cross-check design; "detection
performance" labeling. Recompute the key figures yourself — do not trust the
script's arithmetic.

> Privacy: least privilege. Use only the facts in this brief. If a step
> needs personal details (name, address, phone, email, payment, account
> identifiers, or anything about the user's family or finances), STOP and
> ask for that specific field — do not guess, do not fill it from any
> other context, and do not reuse personal info you may have seen
> elsewhere. Never type private data into a page, message, or form unless
> it was explicitly provided for that step in this task. Details given
> for one step stay in that step.

Write your findings to:
~/workspace/skills/muse-leakage-guard/hidden_files/iter8-reviews/05-datascientist.md
Rank by severity (P0/P1/P2/P3). Verify `git status` is clean of your changes
at the end.
