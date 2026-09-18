# Iteration 8 — Senior SRE review (muse-leakage-guard, HEAD 2243723)

Scope: operational reliability of the validation machinery — CI workflow
(`.github/workflows/validate.yml`) fail-at-the-end behavior, timeouts,
rc=137 handling, slow/hanging/flaky stub fault variants, timeout-budget
asymmetry, hermetic delegates, pinned totals, anchored greps, suite-A
`build-blockset.sh --check`. Full repo read; existing scripts run in
simulated mode only. Never set `MOCHI_LIVE_FIRE=1`; never touched
`local.env`; all payloads synthetic (repo's own fixtures/corpus or
`/tmp` fault-variant copies of the stub — the repo tree is unmodified).

Result: **26 findings — 2 P1, 6 P2, 18 P3. No P0.** No silent-green path
found: every red I could produce still surfaces via the assert-green step
(missing rc files read as `not-run`, which is red). The headline news is
that iteration 7 *demonstrated* iter-7 P1#1 live: the audit's pass total
moved 57 → 64 with zero CI signal and stale docs, and I verified it
empirically by running HEAD~1 and HEAD side by side in CI-equivalent
conditions.

Finding counts: P1: 2 · P2: 6 · P3: 18

Method notes: fault experiments ran against `/tmp` copies of the stub
(`trap '' TERM` hang variants, `sleep 20` slow variant); the repo itself
was only read and executed. `git status` shows no tracked modifications.

---

## P1

### 1. Pass totals still unpinned — and iteration 7 proved the hole live: 57 → 64 with zero CI signal
- **Severity:** P1
- **Status:** iter-7 P1#1, explicitly deferred to iteration 8 — confirmed
  still open at HEAD, now with empirical drift evidence.
- **Evidence:** `.github/workflows/validate.yml` "Assert the pinned CI skip
  set" pins exactly 4 skips and their reasons, but nothing asserts
  `@@@ TOTAL` or `@@@ ADV MATCHED`. I ran the audit in CI-equivalent
  conditions (hermetic delegates, empty `MOCHI_CRON_PROMPT_DIRS`, no
  denylist, fresh gate log, `MOCHI_AUDIT_MACHINE=1`) against a
  `git archive` of HEAD~1 and against HEAD:
  - HEAD~1 (iteration 6): `@@@ TOTAL 57 0 4`
  - HEAD (iteration 7): `@@@ TOTAL 64 0 4`
  - `@@@ ADV MATCHED 36/36` (tiers block 19/19, review 9/9, clean 8/8) —
    unchanged.
  The 4-skip pin passes at both revisions (reasons intact); the 7 net-new
  checks iteration 7 added (interface_version, 2× distinct-delegate,
  operational-failure approval isolation, blockset currency, stdin-form
  blocked/clean, draft token-confusion) moved the total silently.
  `ITERATIONS.md` still documents "57 / 0 / 4" as the CI expectation —
  stale as of the iteration-7 commit.
- **Why it matters:** this is the exact failure mode iter-7 P1#1 predicted,
  now observed in the wild: coverage changed, CI stayed green, docs went
  stale. CI green no longer implies the full check set ran — and the
  documented expectation now disagrees with reality, which trains readers
  to distrust the docs.
- **Recommendation:** in the skip-assert step (or a sibling), assert
  `@@@ TOTAL 64 0 4` from `audit.log` and `@@@ ADV MATCHED 36/36` (plus the
  tier line) from `adversarial.log`, anchored on the sentinels. Update
  `ITERATIONS.md` to 64/0/4. Future total changes then require a deliberate,
  reviewed pin update — which is the point.
- **Residual if not fixed:** the next coverage change (or silent check
  deletion) is equally invisible.

### 2. rc=137 still unhandled everywhere — re-verified at HEAD, with sharper layer semantics than iter-7 reported
- **Severity:** P1
- **Status:** iter-7 P1#2, explicitly deferred — confirmed still open.
  `bin/leakage-audit` lines 407/428/520 (`gate_expect`, `send_expect`,
  `live_send_expect`) and `bin/adversarial-run` line 75 still test only
  `== 124`. The comments ("a TERM-trapping gate is SIGKILLed after 10s,
  so the 30s bound is enforced rather than advisory (rc=124 then engages
  the fail-closed timeout path below)") are still factually wrong.
- **What actually happens (re-verified empirically at HEAD):**
  - Direct child traps TERM → `timeout -k 10 30` exits **137 at 40.0s**
    (30s + 10s grace), never 124. The `== 124` branch never fires; the hang
    is misdiagnosed as a generic verdict mismatch ("want rc=0, got rc=137")
    with the wrong remediation suggestion. The operator triages a phantom
    verdict bug instead of a hang.
  - Refinement over iter-7: the 137 path requires the trap at the **direct
    child** layer. A TERM-ignoring *grandchild* (the detector beneath a
    TERM-sensitive gate script) still yields **124 at 30s** — verified: the
    audit's 124 branch fires correctly there, but the grandchild is
    orphaned and keeps running (see P3#23).
  - Scope precision: `bin/leakage-report`'s own `timeout -k 10 600`
    wrappers are *not* affected — their direct children are the guard's own
    non-trapping scripts. The bug is confined to the audit and
    adversarial-run, where the direct child is third-party code (gate
    scripts, shims, detector) that may legitimately trap TERM.
  - The "timed out after 30s" message is really 40s in the 137 case.
- **Recommendation:** treat 124 **and** 137 as timeout in `gate_expect`,
  `send_expect`, `live_send_expect`, and `adversarial-run` (with a comment
  citing the `kill(0, SIGKILL)` process-group behavior and the direct-child
  layer requirement), and correct the comments. This is also the
  prerequisite for P2#5's fault-injection test to assert the right
  diagnostic.
- **Residual if not fixed:** hung third-party gates are misdiagnosed; the
  hang-specific remediation never reaches the operator.

---

## P2

### 3. Timeout-budget stackup: worst-case hang cascades exceed every step and job budget, so fail-at-the-end diagnostics are lost in exactly the hang scenario the timeouts guard against
- **Severity:** P2
- **Evidence:** per-invocation budgets vs. CI step budgets
  (`timeout-minutes` in `.github/workflows/validate.yml`):
  - Audit step (10 min / 600s): 39 timed invocations in CI (14
    `gate_expect` + 25 `send_expect`) × 30s plain-hang = **1170s
    (19.5 min)**; × 40s TERM-trapping = **1560s (26 min)**. Both exceed
    the step budget — even *without* TERM-trapping.
  - Adversarial step (5 min / 300s): 36 corpus cases × 10s = **360s**;
    × 15s (TERM-trapping) = **540s**. Both exceed the step budget.
  - Report step (15 min / 900s): inner `timeout -k 10 600` × 2 =
    **1200s** > 900s (iter-7 P3#9, still open). If the audit consumes its
    600s bound, the adversarial run's 600s bound can never fire
    gracefully — the runner kills the step first.
  - Job (20 min): sum of step budgets ≈ **50 min** > 20 min. The audit
    step (10) and report step (15) cannot both reach their budgets inside
    one job.
  - Five gate/shim/detector-adjacent invocations have **no timeout at
    all**: suite-A operational-failure probe (line 321), `build-blockset.sh
    --check` (line 328), the stdin-replay integrity check (line 506), and
    the two live-fire discovery commands (lines 539, 565; iter-7 P2#6). A
    hang in any of them wedges the audit until the step/job timeout.
- **Consequence:** under a hung gate the runner SIGTERMs the step mid-suite
  → rc files missing → assert-green fails via `not-run` (safe: the job is
  red, never silent-green) — but `audit.log` is truncated mid-suite, there
  is no findings summary, and no report. The diagnostics that
  fail-at-the-end was built to preserve are gone precisely when the
  timeout machinery was supposed to produce them.
- **Recommendation:** (a) wrap the five untimed invocations in
  `timeout -k`; (b) either raise step budgets to cover worst-case stacks
  (audit ≥ 26 min is unreasonable — better: an audit-level deadline that
  bails with one clear "global hang" finding instead of 39 timeout
  findings); (c) size the report's inner bounds to fit its step
  (e.g. 400s + 400s); (d) reconcile the job budget with the step budgets.
  Deferred threads "timeout-budget asymmetry" and "slow/hanging/flaky stub
  fault variants" both land here.

### 4. Timeout-budget asymmetry empirically demonstrated: a 20s gate is green in the audit and red in adversarial-run
- **Severity:** P2
- **Status:** iter-7 P3#8, explicitly deferred — confirmed still open, now
  demonstrated rather than just read.
- **Evidence:** `bin/leakage-audit` uses `timeout -k 10 30`;
  `bin/adversarial-run` uses `timeout -k 5 10`. Against a fault-variant
  detector answering in 20s with the correct verdict: audit-style
  invocation → rc=0 (`ok`); adversarial-style → rc=124 → `MISMATCH …
  got TIMEOUT` → red. The corpus comment claims "same invocation shape as
  the audit's gate_expect" — shape yes, budget no. A legitimately slow
  real gate yields contradictory verdicts between the two tools.
- **Recommendation:** one shared budget (e.g. `MOCHI_GATE_TIMEOUT`,
  default 30) honored by both, or document why they differ. Healthy stub
  latency is ~50ms, so both budgets are ~200–600× healthy; the
  inconsistency, not the magnitude, is the issue.

### 5. No slow/hanging/flaky stub fault variants — every timeout/failure branch is still dead code in CI
- **Severity:** P2
- **Status:** iter-7 P2#4, explicitly deferred — confirmed still open. No
  `STUB_GATE_FAULT` or similar exists in `test/stub-memory-skill/`.
- **Evidence:** the stub gates model only the happy path (~50ms). The
  `rc=124` branches in `gate_expect`/`send_expect`, the `TIMEOUT` branch
  in `adversarial-run`, and the delegate-failure paths are never exercised
  by any test. My `/tmp` experiments confirm the plain-hang branches
  behave as designed (124 → red finding, audit continues, no wedge) — but
  nothing in the repo pins that behavior, so a regression is invisible
  until a real gate hangs.
- **Recommendation:** env-driven fault injection in the stub
  (`STUB_GATE_FAULT=hang|slow20|term-trap|flaky`, honored by the stub
  gates and the fake real binaries; default path untouched) plus one CI
  step running the audit against the faulted stub asserting the *timeout*
  findings appear (red, with the hang diagnostic from P1#2 once fixed).
  Cover both the 124 and 137 variants.

### 6. SHAPES (audit fixture-purity) vs STUB_SECRET_CAND (patterns.sh) are separate literals that can drift silently
- **Severity:** P2
- **Status:** deferred thread "SHAPES manifest or fixture-purity
  cross-check" — confirmed open.
- **Evidence:** `bin/leakage-audit`'s `SHAPES` regex and
  `test/stub-memory-skill/bin/patterns.sh`'s `STUB_SECRET_CAND` are
  independently maintained ERE literals. The stub's set is a superset:
  e.g. stub matches dashed Amex `3[47]..([- ]?......)([- ]?.....)` and
  flexible-separator 16-digit cards, while the audit's SHAPES only covers
  bare `\b3[47][0-9]{13}\b` and fixed-separator 16-digit groups.
  Consequence: a dashed-Amex-shaped token in a fixture would be extracted
  and hashed into `blockset.txt` (affecting stub verdicts) without the
  fixture-purity check ever requiring its declaration in
  `bin/fixtures/SYNTHETIC.txt` — the exact thing the purity check claims
  to prevent ("catches any other undeclared secret-shaped value before it
  can ship in a public fixture"). `patterns.sh` even documents the
  superset relationship in a comment, but nothing enforces it.
- **Recommendation:** single-source the shapes (the audit's purity scan
  sources the stub's `patterns.sh`, which ships with the repo even for
  real-target runs) or add a CI cross-check asserting
  stub-shapes ⊇ audit-SHAPES.

### 7. The audit echoes undeclared secret-shaped tokens into its output — and the HTML report redacts only email addresses
- **Severity:** P2
- **Status:** deferred thread "HTML redaction beyond email addresses" —
  confirmed open.
- **Evidence:** `bad "undeclared secret-shaped fixture values"
  "$undeclared"` prints the raw tokens; `wdetail` turns each into an
  `@@@ CTX` sentinel; the report renders CTX lines into check evidence and
  the verbatim transcript. The report's `scrub()` / `scrub_transcript()`
  only redact email addresses (and `$HOME` → `~`) — token shapes pass
  through into the 14-day CI artifact HTML. The tool that flags a
  secret-shaped value also broadcasts it. (All current fixtures are
  declared synthetic, so this is latent — but the failure path is exactly
  where a real leak would occur.)
- **Recommendation:** hash or truncate secret-shaped tokens in failure
  evidence, consistent with the existing `argv-sha256` precedent in the
  fake real binaries. E.g. print `sha256:<digest>` instead of the token.

### 8. Stub gates never log to $MOCHI_EGRESS_LOG — suite D's parsing is untested in CI
- **Severity:** P2
- **Status:** iter-7 P2#7 — confirmed still open.
- **Evidence:** `references/gate-interface.md` requires gates to "log every
  decision (timestamp, context, verdict) to `$MOCHI_EGRESS_LOG`". The stub
  `egress-gate` and `brief-gate` write nothing there (verified by grep and
  by running with `MOCHI_EGRESS_LOG` set — no file created). The audit
  points validation at a temp log, so suite D always takes the "gate log
  not found" pinned skip in CI. The parsing code (`grep -c "| $v$"`,
  blocked/override tailing) is exercised only against the owner's real log
  locally, never in CI.
- **Recommendation:** have the stub gates append synthetic decision lines
  (synthetic contexts only) to `$MOCHI_EGRESS_LOG` when set; update the
  pinned skip set (4→3) and assert suite D parses the synthetic lines. Or a
  suite-D self-test with a synthetic log fixture.

---

## P3

### 9. Live-fire discovery commands still run with no timeout
- **Status:** iter-7 P2#6 — confirmed still open (`bin/leakage-audit`
  lines 539, 565). `$G gmail users getProfile … | python3` and
  `$M threads --limit 50 … | python3` have no `timeout` wrapper. A wedged
  real CLI hangs the audit indefinitely; only the report's outer 600s
  bound limits it, and a direct `bin/leakage-audit` live-fire run has no
  bound at all. Recommend `timeout -k 10 60`, failing closed
  ("cannot determine identity → refuse") on 124/137.

### 10. Suite B's temp dir $T has no EXIT trap
- **Status:** iter-7 P3#11 — confirmed still open (`T="$(mktemp -d)"`,
  line 255; only a terminal `rm -rf`). `adversarial-run` and
  `build-blockset.sh` both trap theirs. A killed audit leaves `/tmp` dirs
  with fixture copies and fake binaries. Recommend
  `trap 'rm -rf "$T"' EXIT`. (Fixtures are synthetic — hygiene, not a leak.)

### 11. build-blockset.sh sorts without a pinned locale
- **Status:** iter-7 P3#12 — confirmed still open (two `sort -u`, no
  `LC_ALL`). `--check` compares byte-exact; non-Linux collation can cause
  spurious stale/fresh flip-flop for contributors. Recommend
  `export LC_ALL=C` at the top.

### 12. No timeout(1) precondition — non-GNU systems get 39 misleading findings instead of one clear error
- **Evidence:** the harness assumes GNU `timeout` everywhere; nothing
  asserts `command -v timeout`, and CONTRIBUTING.md names no platform
  requirement. On stock macOS (no `timeout`), every `gate_expect` /
  `send_expect` records "want rc=X, got rc=127" — 39 phantom verdict bugs
  instead of one "timeout(1) required" usage error.
- **Recommendation:** `command -v timeout >/dev/null || { echo …; exit 2; }`
  early in `bin/leakage-audit` and `bin/adversarial-run`, plus a
  CONTRIBUTING platform note.

### 13. --dry-run, messenger edit, and exit-127 are in the contract but untested
- **Status:** iter-7 P3#13/14/15 — confirmed still open. `grep -c` for
  `dry-run`, `edit`, and `127` in `bin/leakage-audit` → 0, 0, no matches.
  The stub shims implement all three (`--dry-run` passthrough,
  messenger `send`/`edit`, no-delegate → 127); the audit exercises none.
  Recommend one `send_expect` per case mirroring the `--draft` test, and a
  suite-A subshell asserting 127 with no delegate on PATH.

### 14. assert-green does not check the artifact-upload outcome
- **Status:** iter-7 P3#10 — confirmed still open. The final assert checks
  rc files and `report_exists` but never `steps.upload.outcome`. A
  transient `upload-artifact` failure yields a green job with no
  `leakage-validation-report` artifact. The summary prints "artifact not
  uploaded" (visible) but the job outcome ignores it. Recommend
  `check "artifact upload"` on `steps.upload.outcome == 'success'`.

### 15. bin/leakage-report silently re-runs the audit — in live-fire mode that re-sends real messages
- **Status:** iter-7 P2#5 — confirmed still open; downgraded to P3 because
  the sends go to the owner's own accounts (noise/duplication, not a
  safety breach). The report inherits the full environment including
  `MOCHI_LIVE_FIRE=1`; neither its header comment ("runs the leakage audit
  AND the adversarial suite") nor the README live-fire section warns that
  generating a report re-arms the sends. Running `bin/leakage-audit` then
  `bin/leakage-report` (both documented flows) double-sends. Recommend a
  doc warning in the header + README live-fire section.

### 16. No operational runbook for red CI
- **Status:** iter-7 P2#3 — confirmed still open. CONTRIBUTING.md documents
  what green means, not "red CI: what now". Recommend a short section:
  read the summary Outcome word (CLEAN/ATTENTION/BLOCKED/INCOMPLETE),
  download the report artifact, map ATTENTION to the report's Findings,
  triage in order (skip-set drift → intentional? update the pin; stale
  blockset → rebuild; fixture/corpus change → check SYNTHETIC.txt
  declarations; timeout flakes → P1#2/P2#3 here).

### 17. bin/leakage-report has no explicit python3 presence check
- **Status:** iter-7 P3#16 — confirmed still open. A missing interpreter
  surfaces as bare command-not-found inside the heredoc instead of a clear
  `exit 3`. Recommend `command -v python3 || { …; exit 3; }` near the top.

### 18. Duplicate corpus case names are not detected
- **Status:** deferred thread "duplicate corpus-name detection" —
  confirmed open. `adversarial-run` has no duplicate-name assertion;
  currently all 36 names are unique, but a duplicated name would
  double-count and the report's F card matches mismatches by name
  (`next((m for m in mismatches if m[0] == name), None)`), misattributing
  `got` values. Recommend a startup assertion failing closed (exit 3) on
  duplicates.

### 19. [B] [B] / [A] [A] prefix duplication in the report's Findings section
- **Status:** deferred thread — confirmed open, verified on a forced-red
  report (revoked the stub `egress-gate`'s exec bit in a `/tmp` copy):
  Findings entries read "[B] [B] egress gate: clean passes",
  "[A] [A] bin/egress-gate missing or not executable". `bad()` prefixes
  `[$SUITE_LETTER]` into the sentinel text and the report's findings
  builder prefixes `[{s['letter']}]` again. Cosmetic; strip one layer.

### 20. Yellow semantics: the legend promises 🟡 "protected through approval" but no card is ever yellow
- **Status:** deferred thread "yellow-semantics consistency" — confirmed
  open. `render_card` assigns only red/stub/ok/skip; CSS defines
  `.card.ok` / `.card.red` / `.card.stub` (no `.card.skip`, no yellow).
  The B card — whose evidence is split into hard-block / approval-gated /
  pass-through groups — renders green "ok" even though much of its
  protection is approval-gated. The legend's tri-state (green/yellow/red)
  is not honored by the cards. Either render approval-gated-dominant
  suites yellow or reword the legend.

### 21. Report tri-state grouping collapses on red runs: failed B checks all land in "Other evidence"
- **Status:** deferred thread "report tri-state fallback to ev[0]"
  (sys N16 / designer H2) — confirmed open, verified on the forced-red
  report ("Other evidence" group present; the 14 failed checks filed under
  it). `tri_state_groups` regexes `rc=(\d)` over check *text*, but a failed
  check's text is `[B] <name>` (no rc marker) — the want/got rc lives in
  `ev[0]`. The grouping works exactly when nothing is red and collapses
  precisely when it is needed. Fix: fall back to parsing `ev[0]` for the
  rc when the text has none. (Visual side belongs to the designer review;
  noted here for the red-path diagnostics angle.)

### 22. The report shows only ev[0] per check — the remediation suggestion is dropped
- **Evidence:** `ev_item` and the findings list render only the first
  evidence line per check. `bad()`'s third argument — the concrete
  "Suggestion: …" remediation — never appears in cards, only in the raw
  transcript. Verified on the forced-red report: the finding shows
  "want rc=0, got rc=126" with no suggestion. On a red run the operator
  must dig into the transcript for the fix. Recommend rendering the full
  evidence list (or at least the suggestion line) in cards.

### 23. TERM-ignoring detector descendants are orphaned after the timeout fires
- **Evidence:** when the TERM trap sits *below* the direct child (e.g. in
  the detector beneath a TERM-sensitive gate script), `timeout -k 10 30`
  exits 124 at 30s and the audit correctly records the hang finding — but
  the grandchild survives orphaned (verified via `/proc` scan: the
  fault-variant detector was alive 2s after timeout exited; it later
  `exec`s the real check detached from the audit). The `-k` group-kill
  only engages when the *direct* child survives to the grace deadline. A
  hang-forever detector leaks one process per timed-out check (up to 39
  per audit run).
- **Recommendation:** document the limitation, or wrap gate invocations so
  the whole process tree is killed (e.g. run each timed check in its own
  process group and kill the group). Hygiene, not a verdict bug.

### 24. Skip-assert reason matching is substring, not exact
- **Evidence:** `printf '%s\n' "${skip_lines[@]}" | grep -q "$reason"` —
  a renamed skip containing the pinned reason as a substring
  (e.g. "memory-audit runner") would still satisfy the pin at the same
  count. The count check (exactly 4) catches *new* skips, but not
  *renamed* ones that happen to contain the old text. Recommend
  `grep -qxF` against the four full expected sentinel lines.

### 25. Summary mislabels checkout failures as BLOCKED "safety precondition failed"
- **Evidence:** the Refuse steps have no `if:` (default `if: success()`),
  so if checkout fails they are skipped (`outcome: 'skipped'` ≠
  `'success'`), and the summary prints BLOCKED with "safety precondition
  failed (see Refuse steps); no component ran". The job outcome (red) is
  correct; the label is imprecise — it was checkout, not a refusal.
  Trivial; consider distinguishing 'skipped' from 'failure' in the
  outcome derivation.

### 26. Near-miss / probe-first methodology is absent
- **Status:** deferred thread — confirmed open; no occurrences of
  probe-first/near-miss anywhere in `bin/`, `references/`, or `SKILL.md`.
  The runner records want/got per case, but exit codes don't distinguish a
  near-miss (wrong tier, e.g. got rc=2 want rc=1 — the dangerous
  direction) from a far-miss, and there is no documented workflow for
  expanding the corpus by probing the gate with near-miss payloads before
  pinning expectations. Methodology debt; overlaps iteration-9/10
  territory (corpus-case proposal methodology, probe-first
  corpus-expansion).

---

## Verified solid (not findings)

- **Fail-at-the-end re-verified at HEAD.** Forced-red run (stub
  `egress-gate` non-executable in a `/tmp` copy): 19 findings, rc=1
  captured via `PIPESTATUS[0]`; `bin/leakage-report` still wrote the HTML
  (rc=1, `SYNTHETIC STUB TARGET` banner present, findings listed with
  evidence links); the emulated assert-green fails on the audit rc. No
  path found where a red component reports green: refuse-step failures
  gate all `always()` components; missing rc files read as `not-run`
  (red); the summary's BLOCKED/INCOMPLETE words derive from refuse
  outcomes and component codes, never prose.
- **Plain-hang behavior is correct.** A hanging (non-TERM-trapping) gate
  under the audit's `timeout -k 10 30` yields rc=124 at 30s; the 124
  branch fires, records the "gate timed out" finding with the hang
  remediation, and the audit continues — no wedge. The gap is only the
  137 variant (P1#2) and the budget stackup (P2#3).
- **The 4-skip pin still passes at HEAD** — the drift was in the pass
  total, which is precisely what is unpinned (P1#1).
- **Hermetic delegates.** Provision step uses `$RUNNER_TEMP`, no sudo, no
  `/usr/local/bin` writes; smoke test resolves and executes the inert
  delegates; suite A asserts shim-shadows-delegate ordering and
  canonical-path distinctness (no self-delegate).
- **Anchored greps.** Every figure in the workflow summary and report
  comes from `^@@@ `-anchored sentinels (`TOTAL`, `VERDICT`, `MODE`,
  `ADV MATCHED`, `ADV TIERS`, `CHECK SKIP`); `msent` escapes `@@@` and
  newlines in untrusted content so case names cannot forge sentinels.
- **local.env / live-fire safety in CI.** The workflow refuses a committed
  `local.env` before any component runs; every `always()` component
  requires both refuse outcomes `== 'success'`; the audit only sources
  `$SKILL_DIR/local.env` with explicit-environment precedence, and a
  `MOCHI_LIVE_FIRE=1` from local.env alone is ignored with a loud
  warning. No path found for live-fire to arm in CI.
- **Suite-A `build-blockset.sh --check`** is wired in both the workflow
  and the audit; exit codes are 0 current / 1 stale / 2 error, and the
  workflow captures the rc faithfully (assert-green requires 0).
- **Git hygiene.** No tracked files modified during this review
  (`git status` clean apart from pre-existing untracked iteration dirs);
  `local.env` untouched; all fault experiments ran against `/tmp` copies.

## Suggested priority for the iteration-8 diff

1. P1#1 (pin `@@@ TOTAL 64 0 4` + `@@@ ADV MATCHED 36/36`; fix
   ITERATIONS.md) and P1#2 (124+137 handling + comment corrections) —
   both are small, both are CI-truth machinery, and #2 is the prerequisite
   for #5's fault-injection test.
2. P2#3 (timeout-budget stackup: wrap the five untimed invocations; an
   audit-level hang deadline; size inner report bounds to the step) and
   P2#4 (slow gate: one shared `MOCHI_GATE_TIMEOUT`).
3. P2#5 (stub fault injection + CI fault step), P2#6 (single-source or
   cross-check the shape sets), P2#7 (redact/hash secret-shaped tokens in
   failure evidence), P2#8 (stub gate logging → suite D exercised in CI).
4. The P3 batch as time allows; #12 (timeout precondition), #13
   (dry-run/edit/127), and #22 (render suggestions in cards) are the
   highest-value one-liners.
