# Iteration 5 — Senior SRE review (muse-leakage-guard, HEAD e4b2af1)

Reviewed read-only. Focus: Suite-B fake-binary fidelity/timeout regressions,
CI reliability/flakiness, determinism, and 2am-debuggability.

Method notes: ran the green path locally against the synthetic stub
(`PERSONAL_MEMORY_SKILL=test/stub-memory-skill`, shim dir first on PATH,
`MOCHI_AUDIT_MACHINE=1 MOCHI_REPORT_WIDTH=48`): audit exits 0 in ~1.5s,
`Total: 57 passed · 0 failed · 2 skipped`; `bin/adversarial-run` exits 0 in
~0.9s, `36/36 cases matched`. So a healthy run costs ~2.5s against a
20-minute job budget — the budget exists almost entirely as a hang
containment net, and that net has holes (findings 1–3).

---

## P0

### 1. A red audit stops the job before any debugging artifact is produced

**Priority:** P0
**Evidence:** `.github/workflows/validate.yml` — steps at lines 106 (audit),
113 (skip assertion), 127 (adversarial), 130 (report generation), 138
(upload) have no `if: always()` on lines 113, 127, 130. Only the upload
(139) and the summary (147) carry `if: always()`, but the job never reaches
them: GitHub Actions stops the job on the first failing step, so if the audit
exits 1 (findings — the *normal* red case), the adversarial suite never runs,
the HTML report is never generated, the artifact is never uploaded, and the
"Assert the expected skip set" step never runs either. The `leakage-report`
generator even *embeds the raw transcripts* of both runs — the single most
useful 2am-debugging artifact — but it is only ever built when everything is
already green. Debugging artifacts exist only when nothing is wrong.
**Recommendation:** Adopt fail-at-the-end: add `if: always()` to the
adversarial, report-generation, and skip-assertion steps; add a final
"Assert green" step (after the artifact upload) that fails the job based on
the captured exit codes / greps of `audit.log` and `adversarial.log`. Do not
rely on step exit codes for job outcome once every step is `always()`.

---

## P1

### 2. Fake binaries never model the failure modes the timeouts exist for

**Priority:** P1
**Evidence:** `bin/leakage-audit` lines ~292–328. The suite-B fakes
(`$T/fakebin/real-gws`, `real-msg`) implement only the happy path: instant
`exit 0` with canned stdout. There is no fake that (a) hangs past the 30s
`timeout` in `gate_expect`/`send_expect`, (b) responds slowly, (c) emits
partial/garbage output, or (d) exits non-zero as a delegate. Consequently, if
a future edit removes `timeout 30` from `gate_expect`/`send_expect` (or
`timeout 10` from `bin/adversarial-run:60`), nothing turns red — the timeout
regression the audit is supposed to guard against is undetectable by the
harness itself. Secondary: GNU `timeout` without `-k` sends SIGTERM and then
*waits*; a shim/gate that ever installs a TERM trap (or a delegate that
ignores SIGTERM) hangs the check indefinitely, past the stated 30s bound.
**Recommendation:** Add fake-binary variants (at minimum: `hang-35s`,
`slow-25s`, `exit-3`, `garbage-stdout`) selectable via env, exercised in a
small dedicated suite or in `adversarial-run`'s corpus as infrastructure
cases; add a negative test that a hanging gate yields rc=124 and is reported
as a timeout (not as a pass); switch all wraps to `timeout -k 5 <N>` so a
TERM-ignoring process is SIGKILLed and bounded.

### 3. Worst-case hang budget exceeds the 20-minute job timeout

**Priority:** P1
**Evidence:** Per-check timeouts: 30s in `gate_expect` (~14 calls: 7
fixtures × 2 gates) and `send_expect` (~15 calls), plus 10s × 36 cases in
`bin/adversarial-run`. Worst case ≈ 14×30 + 15×30 + 36×10 = ~1,230s ≈ 20.5
min — *over* the job's `timeout-minutes: 20` (validate.yml:35). A systemic
hang (e.g., a gate change that blocks on stdin under every check) is killed
by the job timeout, which (a) produces no report artifact, no summary, and —
per finding 1 — no `audit.log` beyond the step log, and (b) is the slowest
possible failure mode: the maintainer waits the full 20 minutes to learn
nothing. Normal runtime is ~2.5s (measured), so 30s per check is ~1000× the
healthy latency.
**Recommendation:** Reduce per-check timeouts to 10s (gates answer in
milliseconds; 10s is still 100× headroom), which bounds the worst case to
~7 min; add per-step `timeout-minutes` (e.g., 3–5) so a hung provision or
blockset step fails fast instead of burning the whole job budget; keep the
20-min job timeout as backstop. Combined with finding 1's `if: always()`,
a timeout kill then still leaves partial logs and whatever artifact exists.

### 4. Delegates are provisioned via sudo into a shared system path — non-hermetic

**Priority:** P1
**Evidence:** validate.yml:67 "Provision inert delegate CLIs behind the stub
shims" runs `sudo tee /usr/local/bin/hatch_gws_cli` and
`/usr/local/bin/hatch_messenger_cli`. This writes outside the workspace to a
path shared by every job on the runner. It works on `ubuntu-latest` because
`/usr/local/bin` is on PATH and passwordless sudo exists, but it is fragile
on self-hosted runners (different PATH, sudo password prompts — a
*sudo password prompt would hang the step until the job timeout*), and two
concurrent runs outside the concurrency group (e.g., a local repro running
the same script) can clobber each other's delegates. The "second, distinct
executable" invariant the audit asserts (gate-interface.md) does not require
a system directory.
**Recommendation:** Provision delegates into `$RUNNER_TEMP/delegates`
(or a `mktemp -d` dir), `chmod +x`, and export
`PATH="$PERSONAL_MEMORY_SKILL/bin/shims:$RUNNER_TEMP/delegates:$PATH"` —
shim dir first (shadowing preserved), delegate dir second. No sudo, no
writes outside the workspace, no cross-job interference; the audit's
"real binary discoverable behind shim" check passes identically.

---

## P2

### 5. Header timestamp makes every run's transcript non-identical

**Priority:** P2
**Evidence:** `bin/leakage-audit` lines 185–186: `print_header` emits
`date '+%Y-%m-%d %H:%M %Z'` in both human text and the `@@@ TS` sentinel.
Two byte-identical green runs therefore produce different `audit.log`
bytes, and `bin/leakage-report` embeds that transcript verbatim in the HTML
artifact — so consecutive identical runs yield different artifacts, and
`audit.log` cannot be byte-diffed across runs to detect behavioral drift.
(The committed sample report
`hidden_files/reports/leakage-validation-20260917-204438-9012.html` is also
un-tracked/local-only, so there is no in-repo baseline to diff against
anyway.)
**Recommendation:** Keep the human timestamp, but make transcripts
diff-stable: either add a `MOCHI_AUDIT_FIXED_TS` override (CI pins it for
artifact comparison) or document that transcript diffs must strip the first
two header lines. Low urgency — cosmetic — but it currently defeats
"CI green/non-green for the wrong reasons" forensics on flaky reds.

### 6. Live-fire discovery commands run with no timeout at all

**Priority:** P2
**Evidence:** In live-fire mode, `bin/leakage-audit` line 440
(`"$G" gmail users getProfile ...`) and line 466
(`"$M" threads --limit 50 ...`) invoke the *real* CLIs with no `timeout`
wrapper, unlike every simulated-path call. A hung real CLI here hangs the
audit indefinitely — no 30s bound, no job-step bound other than the 20-min
job timeout. CI never runs live-fire, but the audit is also a local-ops
tool where the operator's terminal hangs with no message.
**Recommendation:** Wrap both discovery commands in `timeout 30` (or `-k`
per finding 2) and report a timeout as a fail-closed `bad` with the same
"do not trust verdicts until it answers" wording used in `gate_expect`.

### 7. Total pass count is echoed but never asserted — silently dropped checks go green

**Priority:** P2
**Evidence:** validate.yml:113–125 "Assert the expected skip set" pins skip
*count* (2) and the two *reason strings* — good — but nothing pins the pass
count. The measured healthy total is 57 passed / 0 failed / 2 skipped. A
refactor that accidentally deletes or early-returns a block of checks (e.g.,
a suite `begin_suite`/`end_suite` pairing breaks) would go green with, say,
47 passed and the same 2 skips. The step summary greps (`'Total: [0-9]+
passed'`, validate.yml:147+) echo figures without asserting them.
**Recommendation:** Pin the expected total (or per-suite subtotals from the
`@@@ ENDSUITE` sentinels) in the workflow, failing on any deviation, the
same way the skip set is pinned. Expect to update the pin when checks are
intentionally added/removed.

### 8. Step summary scrapes human text instead of the machine sentinels

**Priority:** P2
**Evidence:** validate.yml:147+ "Summarize the validation" extracts figures
with `grep -aE 'Total: [0-9]+ passed'` and `'adversarial-run: [0-9]+/[0-9]+
cases matched'` from rendered text. The audit emits purpose-built,
forge-proof sentinels (`@@@ TOTAL p f s`, `@@@ VERDICT ...`, `@@@ MODE ...`)
precisely to decouple machine parsing from text layout — but the one
consumer in CI ignores them. A width/layout change (the `WIDTH >= 56`
branch in `print_summary` renders the Total row differently) or a copy
edit silently empties the summary while the job stays green.
**Recommendation:** Parse `^@@@ TOTAL`, `^@@@ VERDICT`, and `^@@@ MODE`
sentinels from `audit.log` in the summary step, and `^adversarial-run:` is
fine as-is (it has no sentinel equivalent) or add one.

---

## P3

### 9. No per-step timeouts — any hung step burns the whole job budget

**Priority:** P3
**Evidence:** validate.yml sets only job-level `timeout-minutes: 20`
(line 35). Steps like "Provision inert delegate CLIs" (sudo — see finding 4),
"Check the stub block set is current" (a `cmp` that could block on a
pathological filesystem), and the report generation have no individual
bounds. Combined with finding 1, a hang in an early step wastes up to 20
minutes before the maintainer learns anything.
**Recommendation:** Add `timeout-minutes: 3`–`5` to each step (keep 20 at
the job level as backstop). Cheap, strictly better failure latency.

### 10. Determinism nits: locale-dependent sort; default report filename

**Priority:** P3
**Evidence:** (a) `test/stub-memory-skill/build/build-blockset.sh` pipes
through `sort -u` twice with no `LC_ALL` pinning; the `--check` comparison
is byte-exact (`cmp -s`), so a locale change between the machine that wrote
`blockset.txt` and CI could flip ordering and fail the check for no
semantic reason. On `ubuntu-latest` (C.UTF-8) it is stable today — latent,
not active. (b) `bin/leakage-report`'s default `--out` embeds
`date +%Y%m%d-%H%M%S` *and* `$$` (line 32): non-deterministic filenames mean
no stable artifact identity across runs; fine for local use, but CI should
keep passing an explicit `--out` (it does — good).
**Recommendation:** (a) prefix the build/check pipeline with
`export LC_ALL=C`; (b) no change needed in CI, but document that local
default-filename reports are not comparable across runs.

---

## What is already solid (not findings)

- The `@@@` machine sentinels are sanitized against forgery (`@@@` →
  `[at]` in `msent`, newline-collapsed) — report parsing can't be spoofed
  by hostile check names or wrapped CLI output.
- Per-check invocation is asserted by sentinel *file* (`invoked-any`
  touched by the fake), not by stdout text — a crashing delegate that echoes
  a marker can't fake it.
- The audit fails closed on fixture/corpus rot (empty fixtures, empty
  corpus, stale blockset all fail), and the workflow pins exactly which
  skips are expected with reason-string matching.
- `concurrency: cancel-in-progress` prevents overlapping runs on the same
  ref; SHA-pinned actions, shallow checkout, `pull_request` (not
  `pull_request_target`), and live-fire refusal in CI are all correct.
- `leakage-report` writes atomically (`os.replace` via `.tmp.<pid>`) and
  refuses to write a report it cannot parse — no half-written or
  misleading artifacts.

## Suggested priority order for iteration 5

1. Finding 1 (P0) — fail-at-the-end so red runs produce the report,
   artifact, and summary.
2. Finding 2 (P1) — fake variants + `timeout -k` so timeout regressions
   are actually covered.
3. Finding 3 (P1) — 10s per-check timeouts + per-step bounds so the worst
   case is ~7 min, not >20.
4. Finding 4 (P1) — hermetic delegate provisioning under `$RUNNER_TEMP`,
   drop sudo.
5. Findings 7+8 (P2) — pin totals and parse sentinels in the summary.
