# Iteration-6 security review — muse-leakage-guard (HEAD 5ff8950)

Reviewer: senior security engineer (subagent). Scope: full-repo, read-only,
unlimited. All probes used synthetic fixtures only; nothing was modified.

Baseline established before probing (local run against
`test/stub-memory-skill`): `bin/adversarial-run` 36/36 green (block-tier
19/19, review-tier 9/9, clean 8/8); `bin/leakage-audit` 59 passed, 0
failed, 2 skipped, CLEAN; `build-blockset.sh --check` current. Findings
below are gaps *inside* that green run.

Iteration-5 follow-up status: the multi-file newline-fusion fix and the
raw-MIME fail-closed fix are verified present in code. The CI summary-grep
issues (dead `block-tier recall` pattern, unanchored greps), the C5
out-of-band qualification, the A7 verdict, and the gate-interface
body/to wording were NOT addressed — they reappear below, some with new
evidence.

Verified correct (no finding): approval isolation holds in both stub gates
(block-tier rc=1 exits before any approval check); `timeout 30` rc=124 is
treated as failure (never pass) in `gate_expect`, `send_expect`, and
`adversarial-run`; live-fire is refused against stub targets and in
non-interactive contexts; local.env can never arm live-fire; the skip-set
assertion fails closed on count/reason drift; fixture-purity and
denylist scans are sound; actions are SHA-pinned; `contents: read` +
`persist-credentials: false`; no secrets in CI.

---

## P1 — CI "Run the adversarial suite" step cannot fail: missing `set -o pipefail`

**Evidence:** `.github/workflows/validate.yml:128` —
`run: bin/adversarial-run | tee "${{ runner.temp }}/adversarial.log"`.
The sibling audit step (`:108`) sets `set -o pipefail`; this step does
not. Demonstrated semantics in isolation: `failing-cmd | tee log; echo
$?` → `0` without pipefail, `1` with it. If `adversarial-run` exits 1
(mismatches) or 3 (runner failed — gate missing, empty corpus), the step
still reports green. The failure would only surface later, confusingly,
in the "Generate the HTML validation report" step (which re-runs the
suite and exits 1) — the per-step check list lies about which suite broke.

**Recommendation:** add `set -o pipefail` (or `set -eo pipefail`) to the
adversarial step, matching the audit step.

**Residual if not fixed:** a red adversarial suite renders as a green CI
step; reviewers reading the checks list see the wrong failure attribution.

## P1 — `timeout` without `-k`: a gate that ignores SIGTERM hangs the harness until the CI job timeout

**Evidence:** `bin/leakage-audit:336,338,360` (`timeout 30 ...`) and
`bin/adversarial-run:62` (`timeout 10 ...`). GNU `timeout` sends TERM and
then waits for the process to die; without `-k/--kill-after` a process
that traps or ignores SIGTERM hangs the caller indefinitely. The harness
then hangs until the workflow's 20-minute `timeout-minutes` kills the
job — CI reports "stuck", not "gate hung", and `leakage-report` likewise
hangs for interactive users. The rc=124 fail-closed handling is correct
but unreachable in this failure mode.

**Recommendation:** `timeout -k 5 30` (and `-k 5 10` in adversarial-run)
so a TERM-immune gate is SIGKILLed and the existing rc=124 → FAIL path
engages.

**Residual if not fixed:** a hung or TERM-trapping gate turns a fast,
diagnosable failure into a 20-minute CI hang with no actionable signal.

---

## P2 — CI job-summary grep for 'block-tier recall' is dead (prints "block-tier pass")

**Evidence:** `.github/workflows/validate.yml:157`
(`grep -aE 'block-tier recall' ... || true`); `bin/adversarial-run:86`
prints `adversarial-run: block-tier pass 19/19 · ...`. Verified
empirically against the local logs: the pattern matches nothing, and
`|| true` swallows the miss, so the per-tier line silently vanishes from
every CI summary. (Iteration-5 already flagged this; the script's wording
changed since, making the staleness total.)

**Recommendation:** grep the actual line (`^adversarial-run: block-tier
pass`), anchored (see next finding), and fail the step if no line
matches instead of `|| true`.

**Residual if not fixed:** the summary permanently omits the tier
breakdown — the one figure a reviewer needs to distinguish block-tier
from review-tier regressions.

## P2 — Job-summary greps are unanchored and fail-open: attacker-controlled corpus names can inject summary lines

**Evidence:** `.github/workflows/validate.yml:153-157`. All three greps
use unanchored `-aE` patterns with `|| true`. Corpus case names are fully
attacker-controlled on a fork PR, and `adversarial-run` prints
`  MISMATCH <name> ...` verbatim. A case named e.g.
`adversarial-run: 99/99 cases matched` produces a log line matching
`grep -aE 'adversarial-run: [0-9]+/[0-9]+ cases matched'`, which is then
copied into `$GITHUB_STEP_SUMMARY` as if it were the runner's own output
— faking green counts on a failing run. Additionally, if the log files
are missing entirely (earlier step skipped), the `|| true` swallows the
grep errors and the summary posts silently incomplete. (Iteration-5 P2
persists unchanged.)

**Recommendation:** anchor to the runner's own summary lines
(`^adversarial-run: `, `^  Total: `) so `  MISMATCH` lines can never
match, and drop the `|| true` in favor of an explicit "expected line
missing → fail" assertion.

**Residual if not fixed:** the PR summary — the reviewer's trust surface —
can carry injected green counts; a missing-logs failure mode posts a
summary that looks like a thin-but-green run.

## P2 — `interface_version` is declared but never enforced

**Evidence:** `test/stub-memory-skill/.synthetic-stub` declares
`interface_version=1` and `references/gate-interface.md` is titled
"Gate/shim interface contract — version 1". Nothing in `bin/` or
`.github/` reads that field: `bin/leakage-audit` only tests file
existence (`[ -f "$MEM_SKILL/.synthetic-stub" ]` → STUBKIND); CI never
checks it. A target silently upgraded to (or claiming) interface v2 —
with changed exit-code semantics, new flags, or a different approval
model — is audited against v1 assumptions with no warning.

**Recommendation:** the audit should read `interface_version` from the
marker (and/or probe a `--version`/contract flag on the target's gates)
and fail closed when it is absent or != the pinned version the harness
understands. One focused diff: version read + mismatch refusal in suite A.

**Residual if not fixed:** a contract-version drift between harness and
target is invisible; a green run may be validating the wrong contract.

## P2 — Inert delegate CLIs are provisioned via `sudo` into `/usr/local/bin`

**Evidence:** `.github/workflows/validate.yml:83-102` (`sudo tee
/usr/local/bin/hatch_gws_cli`, `sudo chmod +x`). The stated reason is
that the audit's suite A needs "a second, distinct executable behind each
shim on PATH". `/usr/local/bin` is a shared, privileged location: any
later step (including a compromised dependency, should one ever be added)
can overwrite or shadow these delegates, and the step needs root on the
runner. The audit's delegate discovery iterates PATH directories *after*
the shim dir, and the shim prefers `MOCHI_REAL_*` env overrides — nothing
about `/usr/local/bin` is load-bearing.

**Recommendation:** provision the inert delegates hermetically: write them
to `$RUNNER_TEMP/delegates` (no sudo) and prepend that dir to PATH for
the audit steps. Same fidelity for suite A, no privileged writes, no
shared-namespace risk.

**Residual if not fixed:** low immediate blast radius (fixed heredoc
content, read-only token), but the workflow normalizes `sudo` writes to a
shared bin dir — one future `npm install -g`-style step away from a
delegate-shadowing surprise.

## P2 — C5 still overclaims: "the send would still hit the egress gate" is true only for shimmed CLIs

**Evidence:** `references/attack-surface.md:189-198` (C5, conclusion
PROTECTED (in depth)): "Even if an agent were steered, the send would
still hit the egress gate (A1–A4...)". A steered agent exfiltrating via
`curl --data`, a webhook, or any non-shimmed skill CLI never touches a
gate. Out-of-band egress appears only in the suite-E residual one-liner
(`references/attack-surface.md:304-305`) and the audit's re-report — the
catalog still has no dedicated scenario, so the coverage discipline ("a
path with no scenario is an unexamined path") is violated for the most
obvious non-shim exfil path, and C5 reads as a completeness claim.
(Iteration-5 P1 follow-up.)

**Recommendation:** add the scenario (e.g. C6/A9, verdict OPEN GAP or
POLICY-ONLY) and qualify C5's sentence to "sends through the shimmed
CLIs".

**Residual if not fixed:** readers of the catalog overestimate the
defense-in-depth boundary; the catalog's own coverage rule stays broken
for this path.

## P2 — A7 "PROTECTED (by audit)" overstates a static string check

**Evidence:** `references/attack-surface.md:78-86` (A7, conclusion
PROTECTED); the control is `grep -q 'bin/shims:$PATH'` over cron prompt
files (`bin/leakage-audit:519-527`). A prompt can carry the literal
string and still bypass the gate: a later `PATH=` reassignment, `env -i`,
or delegation to a wrapper that drops the shim directory all preserve
the magic string while defeating the protection. The audit's own suite-E
re-report concedes the check is "static/syntactic". (Iteration-5 P2
follow-up.)

**Recommendation:** downgrade A7 to POLICY-ONLY (matching A8's honest
framing) or strengthen the check to flag `PATH=` reassignment / `env -i`
after the export line.

**Residual if not fixed:** the catalog marks PROTECTED a control that a
prompt can satisfy textually while bypassing functionally.

## P2 — Contract/implementation mismatch: contract says "body/to", stub gates subject+body only

**Evidence:** `references/gate-interface.md:67` — "Gmail `+send`,
`+reply`, `+forward`: body/to pass `egress-gate`." The stub shim's `+send`
branch builds `subject: ...\n\n<body>` and gates that
(`test/stub-memory-skill/bin/shims/hatch_gws_cli`, `gate_file` call);
`--to` is captured for the log context but never passed through the
gate. (Iteration-5 P2 follow-up.)

**Recommendation:** either include the recipient in the gated payload or
correct the contract wording. One-line-class diff either way.

**Residual if not fixed:** minor — recipients are destinations, not
content — but the harness's fidelity to its own contract is unverifiable
on this point, and a future "to-gating" feature would have no test
coverage.

---

## P3 / notes

- **Hardcoded syntax-check file list** (`.github/workflows/validate.yml`,
  "Syntax-check every shell script"): a new script added to `bin/` or the
  stub is silently skipped unless someone remembers to extend the list.
  Prefer globbing (`bin/*`, stub `bin/**`) with an explicit exclusion list.
- **`pull_request` trigger runs the PR's own workflow file.** The header
  comment's safety narrative ("fork PRs get no write token") is true for
  the token, but the workflow code itself is PR-controlled on fork PRs;
  the actual safety rests on `contents: read` + no secrets + required
  human review (CODEOWNERS gates all workflow/harness paths). Consider
  documenting that explicitly, or `pull_request_target` with an explicit
  checkout of the untrusted head.
- **Stub shims call `egress-gate` with no internal timeout**
  (`test/stub-memory-skill/bin/shims/hatch_gws_cli` `gate_file`;
  `hatch_messenger_cli` `send`/`edit` branch). The audit wraps shim
  invocations in `timeout 30`, but any direct (non-audit) caller of the
  shim hangs forever on a wedged gate. A modest internal
  `timeout -k 5 30` in the shims is defense in depth.
- **Live-fire `live_send_expect` has no timeout**
  (`bin/leakage-audit`, suite B live-fire branch): a hung real CLI hangs
  the whole audit. Same `-k` treatment recommended.
- **Undocumented shape gaps persist** (iteration-5 P2 follow-up):
  `(415)555-0132`, `1(415)555-0132`, and `$ 12,500` (space after `$`)
  still classify rc=0 in the stub and are neither pinned as corpus cases
  (like `phone_bare10`/`clean_price` were) nor documented as residuals in
  `patterns.sh`. The header's "fail closed" framing still overpromises
  for shapes the regexes never match.

---

## Notes for the iteration-6 diff

One focused diff: (1) `set -o pipefail` on the CI adversarial step;
(2) `timeout -k` on all gate invocations; (3) fix + anchor the
job-summary greps and fail when an expected line is missing; (4) enforce
`interface_version` in the audit (fail closed on absent/mismatched);
(5) hermetic delegate provisioning without sudo; (6) catalog: new
out-of-band scenario + C5 qualification, A7 verdict correction,
gate-interface body/to wording. Re-validation: `build-blockset.sh
--check`, `bin/adversarial-run` (36/36), full `bin/leakage-audit`
against the stub, and a negative control — e.g. temporarily break one
corpus expectation and confirm the CI adversarial step now goes red.
