# Iteration 7 — Senior SRE review (muse-leakage-guard, HEAD e20a819)

Scope: full repository, read-only. Method: read every script/doc in the
repo; ran `bin/leakage-audit` (simulated, stub target) and
`bin/adversarial-run` locally; forced a red audit (broke the stub gate)
and walked the CI fail-at-the-end path step by step in simulation;
empirically probed `timeout -k` semantics against plain, slow, and
TERM-trapping hangs (strace-verified). Never set `MOCHI_LIVE_FIRE=1`;
never touched `local.env`. All payloads synthetic.

Result: **16 findings — 2 P1, 5 P2, 9 P3. No P0.** Iteration 6's
fail-at-the-end machinery re-verified end to end and holds (see
"Verified solid"). The two P1s are CI-truthfulness holes, not
silent-green verdict bugs: nothing found lets a red audit report green.

Finding counts: P1: 2 · P2: 5 · P3: 9

---

## P1

### 1. Pass totals are echoed but never asserted — a silently dropped check or corpus case still goes green
- **Severity:** P1
- **Evidence:** `.github/workflows/validate.yml`, "Assert the pinned CI skip set" step — pins exactly 4 skips and their reasons, but nothing asserts the audit's `@@@ TOTAL` figures or the adversarial `@@@ ADV MATCHED` figures. The "Summarize the validation" step only *displays* them. `ITERATIONS.md` (Iteration 6 validation note) itself states the CI expectation is `57 / 0 / 4` and `adversarial 36/36` — those numbers exist in prose, not in the workflow.
- **Why it matters:** delete 10 checks from `bin/leakage-audit` (or 5 cases from `bin/adversarial-corpus.txt`) and CI stays green: fewer passes, zero fails, skip pin intact. This is the exact hole iter-6 finding #9 named; iteration 6 fixed the skip pin but not the total pin.
- **Recommendation:** in the skip-assert step (or a sibling step), assert `@@@ TOTAL 57 0 4` from `audit.log` and `@@@ ADV MATCHED 36/36` from `adversarial.log`, anchored on the sentinels. The CI environment is already deterministic (the 4-skip pin proves it), so the pass total is pinnable. If a future change legitimately moves the totals, the pin update is a deliberate, reviewed diff — which is the point.
- **Residual if not fixed:** coverage can rot silently; CI green no longer implies the full check set ran.

### 2. `timeout -k` against a TERM-trapping gate exits 137, not 124 — the timeout diagnostic branch is dead for the exact case it was written for
- **Severity:** P1
- **Evidence:** `bin/leakage-audit` lines 334–352 (`gate_expect`: `if [ "$rc" -eq 124 ]`), lines 360–368 (`send_expect`: same 124 check); `bin/adversarial-run` lines 72–80 (`if [ "$got" = 124 ]`). Comments claim: "a TERM-trapping gate is SIGKILLed after 10s, so the 30s bound is enforced rather than advisory (rc=124 then engages the fail-closed timeout path below)."
- **What actually happens (verified empirically, strace-confirmed):** coreutils `timeout -k` puts itself and the child in a *new* process group; when the child ignores SIGTERM, the `-k` escalation issues `kill(0, SIGKILL)` to that group — killing the `timeout` process itself. Observed across 4 experiments: plain hang → rc=124 at 30s; TERM-trapping hang → **rc=137** at 40s (30s + 10s grace), never 124. The parent harness survives (separate group), so there is no blast-radius issue — but the `rc -eq 124` branch **never fires** for a TERM-trapping gate.
- **Consequence:** a TERM-trapping gate is still recorded as FAIL (red — no silent green), but misdiagnosed as a generic verdict mismatch (`want rc=0, got rc=137` + the wrong suggestion) instead of the actionable "gate timed out" finding with the hang-specific remediation. The comment block describing the 124 path is factually wrong.
- **Recommendation:** treat `124` **and** `137` as timeout in all three places (with a comment citing the `kill(0, SIGKILL)` group behavior), and correct the comments. Bonus: the "timed out after 30s" message is really 40s (30s + 10s `-k` grace) — say so.
- **Residual if not fixed:** operators triaging a hung gate chase a phantom verdict bug instead of a hang; the timeout-specific suggestion never reaches them.

---

## P2

### 3. No operational runbook for red CI
- **Severity:** P2
- **Evidence:** `CONTRIBUTING.md` has "What CI green means" but no "red CI: what now". `README.md` "Continuous integration" section likewise. Searched the repo for runbook/triage/on-call guidance — none exists.
- **Recommendation:** add a short "When CI is red" section to `CONTRIBUTING.md`: read the summary table's Outcome word (CLEAN/ATTENTION/BLOCKED/INCOMPLETE), download the `leakage-validation-report` artifact, map ATTENTION to the report's Findings section, and list the common causes in triage order (skip-set drift → intentional change, update the pin; blockset stale → rebuild; fixture/corpus change → check SYNTHETIC.txt declarations; timeout flakes → see finding #8). One paragraph + a bullet list; no new machinery.
- **Residual if not fixed:** every red run costs the owner a from-scratch investigation; contributors may "fix" red by weakening pins.

### 4. Fake-binary fidelity: no slow / hanging / flaky gate or delegate variants — every timeout/failure branch is dead code in CI
- **Severity:** P2
- **Evidence:** `test/stub-memory-skill/bin/egress-gate`, `brief-gate`, `memory-egress-check` model only the happy path (~50ms, verified by timing 20 invocations); the audit's fake "real" binaries (`bin/leakage-audit`, `real-gws`/`real-msg` heredocs) `exit 0` immediately and always touch the sentinel. The `rc=124` branches in `gate_expect`/`send_expect`, the `TIMEOUT` branch in `adversarial-run`, and the delegate-failure paths are never exercised by any test. (Iter-6 finding #7, still open.)
- **Recommendation:** add an env-driven fault injector to the stub (e.g. `STUB_GATE_FAULT=hang|slow15|term-trap|flaky` honored by the stub gates, and a slow/failing variant for the fake real binaries), plus one CI step that runs the audit against the faulted stub and asserts the *timeout* findings appear (red, with the hang diagnostic from finding #2). Keep the default path untouched.
- **Residual if not fixed:** the timeout machinery that iteration 6 added is untested against the very conditions it guards; a regression there is invisible until a real gate hangs.

### 5. `bin/leakage-report` silently re-runs the audit — in live-fire mode that re-sends real emails/messages
- **Severity:** P2
- **Evidence:** `bin/leakage-report` lines 43–54 invoke `bin/leakage-audit` inheriting the full environment, including `MOCHI_LIVE_FIRE=1`, `MOCHI_TEST_EMAIL`, `MOCHI_LIVE_FIRE_NONINTERACTIVE`. The audit's live-fire suite B sends real mail to the owner's own accounts (2 Gmail + 1 Messenger message per run, distinct `MARK` per PID). Neither the report's header comment ("runs the leakage audit AND the adversarial suite") nor the README live-fire section warns that generating a report re-arms the sends. Running `bin/leakage-audit` then `bin/leakage-report` (both documented flows) double-sends.
- **Recommendation:** document it in the report header + README live-fire section ("in live-fire mode the report re-runs the audit, re-sending the test messages"), or add a `--reuse-audit-log` path. One-diff scope: the doc warning is enough; the sends go to the owner's own accounts, so this is noise/duplication, not a safety breach.
- **Residual if not fixed:** an owner validating in live-fire gets unexplained duplicate test messages and may mistrust the harness.

### 6. Live-fire discovery commands run with no timeout
- **Severity:** P2
- **Evidence:** `bin/leakage-audit` live-fire branch: `"$G" gmail users getProfile ... | python3 -c ...` and `"$M" threads --limit 50 ... | python3 -c ...` — no `timeout` wrapper (iter-6 finding #10, still open). A hung real CLI here hangs the audit indefinitely; only the report's outer 600s bound (when run via the report) limits it — a direct `bin/leakage-audit` live-fire run has no bound at all.
- **Recommendation:** wrap both discovery invocations in `timeout -k 10 60`, failing closed ("cannot determine identity → refuse") on 124/137, consistent with the existing fail-closed posture.
- **Residual if not fixed:** a wedged CLI turns a live-fire validation into an unbounded hang instead of a clean refusal.

### 7. The stub gates never log to `$MOCHI_EGRESS_LOG` — suite D's log-parsing code is untested in CI
- **Severity:** P2
- **Evidence:** `references/gate-interface.md` requires: "Logs every decision (timestamp, context, verdict) to `$MOCHI_EGRESS_LOG`." The stub `egress-gate` writes nothing to the log (verified: `MOCHI_EGRESS_LOG=/tmp/...` → no file created). The audit exports `MOCHI_EGRESS_LOG="$T/gate.log"`, so suite D always takes the "gate log not found" skip against the stub — one of the 4 pinned CI skips. The parsing code (`grep -c "| $v$"`, override/blocked tailing) is therefore exercised only against the owner's real log locally, never in CI.
- **Recommendation:** have the stub `egress-gate` append synthetic decision lines (synthetic contexts only) to `$MOCHI_EGRESS_LOG` when set; update the pinned skip set (4→3) and add an assertion that suite D parses the synthetic lines. Alternative: a suite-D self-test with a synthetic log fixture. Either is one focused diff.
- **Residual if not fixed:** a refactor that breaks suite D's parsing stays green in CI; the interface contract's logging clause is unvalidated against the stub.

---

## P3

### 8. The audit and the adversarial runner disagree on the gate timeout budget (30s vs 10s)
- **Severity:** P3
- **Evidence:** `bin/leakage-audit` line 339/341/363: `timeout -k 10 30`; `bin/adversarial-run` line 74: `timeout -k 5 10`. The corpus comment claims "same invocation shape as the audit's gate_expect" — shape yes, budget no. A gate that answers in 20s: audit says fine (`ok`), adversarial-run reports `TIMEOUT` mismatch (red). Healthy stub latency is ~50ms, so both budgets are ~200–600× healthy; the inconsistency, not the magnitude, is the issue.
- **Recommendation:** use one shared budget (or document why they differ). Simplest: a `MOCHI_GATE_TIMEOUT` default (e.g. 30) honored by both.
- **Residual if not fixed:** a legitimately slow real gate yields contradictory verdicts between the two tools.

### 9. The report's inner 600s timeouts exceed its CI step budget (15 min) — the second bound can never fire
- **Severity:** P3
- **Evidence:** `bin/leakage-report` lines 44/54: `timeout -k 10 600` on the audit and again on the adversarial run (600+600s = 20 min); `.github/workflows/validate.yml` report step: `timeout-minutes: 15`. If the audit consumes its 600s and the adversarial run then hangs, the runner kills the step at 900s: no graceful `exit 3`, no `rc/report` file, no partial diagnostics — `assert-green` still fails the job via `not-run` (safe), but the operator loses the report that fail-at-the-end was built to preserve.
- **Recommendation:** size the inner bounds to fit the step (e.g. 400s + 400s with margin) so the script's own timeout handling fires before the runner's.
- **Residual if not fixed:** worst-case hangs lose diagnostics instead of producing the graceful timeout report.

### 10. `assert-green` does not check the artifact-upload outcome
- **Severity:** P3
- **Evidence:** `.github/workflows/validate.yml` — the final assert checks rc files and `report_exists`, but never `steps.upload.outcome`. A transient `upload-artifact` failure yields a green job with no `leakage-validation-report` artifact. The summary does print "artifact not uploaded" (visible, not silent), but the job outcome doesn't reflect it — and iteration 6's theme explicitly lists the artifact as part of honest failure output.
- **Recommendation:** add `check "artifact upload"` on `steps.upload.outcome == 'success'` (skipped-upload when `report_exists != 'true'` stays out of scope).
- **Residual if not fixed:** green CI with no downloadable report; debuggability reduced exactly when it's needed.

### 11. Suite B's temp dir `$T` has no EXIT trap
- **Severity:** P3
- **Evidence:** `bin/leakage-audit`: `T="$(mktemp -d)"` with only a terminal `rm -rf "$T"`; no `trap`. (Iter-6 finding #15, still open.) `adversarial-run` and `build-blockset.sh` both trap theirs. A killed audit leaves `/tmp` dirs containing fixture copies and fake binaries behind.
- **Recommendation:** `trap 'rm -rf "$T"' EXIT` next to the `mktemp`. Fixtures are synthetic, so this is hygiene, not a leak.
- **Residual if not fixed:** `/tmp` litter accumulates on interrupted runs.

### 12. `build-blockset.sh` sorts without a pinned locale
- **Severity:** P3
- **Evidence:** `test/stub-memory-skill/build/build-blockset.sh` lines 48/50: two `sort -u` with no `LC_ALL=C`. (Iter-6 finding #14, still open.) `--check` compares byte-exact; on macOS (different collation) a contributor can see spurious stale/fresh flip-flop. Deterministic on `ubuntu-latest` CI, so CI is unaffected.
- **Recommendation:** `export LC_ALL=C` at the top of the script.
- **Residual if not fixed:** contributor friction on non-Linux platforms; potential false `--check` failures.

### 13. `--dry-run` passthrough is in the contract but untested
- **Severity:** P3
- **Evidence:** `references/gate-interface.md`: "`--draft` / `--dry-run`: pass through UNGATED". The stub shim implements both; `bin/leakage-audit` tests `--draft` ("gmail +send --draft with secret passes through") but never `--dry-run` (`grep -c dry-run bin/leakage-audit` → 0).
- **Recommendation:** add one `send_expect` line mirroring the `--draft` case.
- **Residual if not fixed:** a shim regression that gates (or mishandles) `--dry-run` is invisible.

### 14. Messenger `edit` is in the contract but untested
- **Severity:** P3
- **Evidence:** `references/gate-interface.md` shim contract covers `send`/`edit`; the stub messenger shim implements both; `bin/leakage-audit` suite B exercises only `send` (no `edit` case found).
- **Recommendation:** add `send_expect` cases for `edit` (clean passes, secret blocked) mirroring the `send` cases.
- **Residual if not fixed:** the `edit` interception path is validated by code inspection only.

### 15. The 127 no-delegate contract is asserted by existence, never by behavior
- **Severity:** P3
- **Evidence:** `references/gate-interface.md`: "No delegate → exit 127 (fail closed, never silently drop)." Suite A checks a delegate *exists* behind each shim, but never that a shim with no delegate exits 127. The 127 path in both stub shims is untested.
- **Recommendation:** in suite A (subshell with a PATH containing only the shim dir), assert `hatch_gws_cli` exits 127 with no delegate resolvable. Self-contained; no fixture changes.
- **Residual if not fixed:** a shim refactor that silently drops (or hangs) instead of 127 goes unnoticed.

### 16. `bin/leakage-report` has no explicit `python3` presence check
- **Severity:** P3
- **Evidence:** the report shells out to `python3` for all HTML generation; a missing interpreter surfaces as a bare command-not-found inside the heredoc invocation rather than a clear `exit 3`. (Iter-6 finding #17, still open.) `ubuntu-latest` always has python3, so this is a local-run UX issue.
- **Recommendation:** `command -v python3 || { echo "..."; exit 3; }` near the top, mirroring the stub shim's own python3-missing fail-closed message.
- **Residual if not fixed:** confusing failure on minimal systems.

---

## Verified solid (not findings)

- **Iteration-6 fail-at-the-end re-verified end to end.** Forced a red audit (revoked the stub `egress-gate`'s exec bit → 19 findings, rc=1): the audit step captured rc=1 via `PIPESTATUS[0]` and exited 0; the report step still wrote `leakage-validation.html` (rc=1, `SYNTHETIC STUB TARGET` banner present); the emulated assert-green fails on `check "audit" 1`. Red produces logs + report + (in CI) artifact + summary, then fails via assert-green. No path found where a red component reports green: refuse-step failures gate all `always()` components; missing rc files read as `not-run` (red); the summary's BLOCKED/INCOMPLETE words derive from refuse outcomes and component codes, never from prose.
- **`local.env` in CI.** The workflow refuses a committed `local.env` at the repo root with a clear `::error::` before any component runs, and every `always()` component requires both refuse outcomes `== 'success'`. The audit/adversarial-run only ever source `$SKILL_DIR/local.env` (repo root); a `local.env` committed in a subdirectory would be inert. `local.env` is gitignored, untracked, and `local.env.example` contains only paths and empty live-fire placeholders. No path found for a contributor's `local.env` to reach CI logs or the 14-day artifact.
- **Nightly-evaluation wording.** Zero occurrences of "nightly" anywhere in the repo. Schedule language is limited to "on a schedule" (README, SKILL.md) and "the memory skill's daily health check" (SKILL.md — refers to the *memory skill's* own schedule, not this repo's CI). No contradictions found.
- **Git hygiene.** `local.env` and `hidden_files/reports/*` are gitignored and untracked (only `.gitkeep` files tracked); the committed HTML report on disk is untracked working-tree output.
- **Hermetic delegates.** Provision step uses `$RUNNER_TEMP`, no sudo, no `/usr/local/bin`; smoke test resolves and executes the delegates; suite A asserts shim-shadows-delegate ordering.
- **Sentinel-based summary.** All figures flow from anchored `@@@` sentinels; missing sentinels render "unavailable"; `msent` escapes `@@@` in untrusted content so case names cannot forge sentinels.
- **Stub self-labeling.** `SYNTHETIC STUB TARGET` banner enforced in the report step; audit refuses live-fire against stub targets (exit 2); stub detector/README/interface doc consistently state the stub is not a protection layer.

## Suggested priority for the iteration-7 diff

1. Findings #1 (pin totals) + #2 (137 timeout) — both are one-spot changes in safety/CI-truth machinery; #2's fix is also the prerequisite for #4's fault-injection test to assert the right diagnostic.
2. Findings #3 (runbook), #7 (stub gate logging → exercises suite D), #4 (fault-injection variants).
3. Findings #5, #6 (live-fire rough edges), then the P3 batch (#8–#16) as time allows; #11/#12/#16 are one-liners.

## Method notes for the record

- `timeout -k` semantics were verified with `strace -f -e trace=kill`: on a TERM-ignoring child, `timeout` issues `kill(0, SIGKILL)` to the *new* process group it created for itself+child — hence rc=137 and the `timeout` process dying, while the parent harness (different group) survives. Plain hangs still yield rc=124. This is standard coreutils behavior, not a bug in `timeout` — the bug is the scripts' assumption that 124 is the only timeout rc.
- All fixture values referenced are synthetic shapes from the repo's own fixtures/corpus, belonging to nobody.
