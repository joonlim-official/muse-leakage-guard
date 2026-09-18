# Iteration 6 — Senior SRE review (muse-leakage-guard, HEAD 5ff8950)

Reviewed read-only at HEAD 5ff8950 ("Iteration 5: honest green"). Full-repo,
unlimited scope. Read: `bin/leakage-audit` (636 lines), `bin/leakage-report`
(668), `bin/adversarial-run` (91), `.github/workflows/validate.yml`, the stub
skill (both shims, both gates, `memory-egress-check`, `patterns.sh`,
`build-blockset.sh`), `references/` (attack-surface, gate-interface,
test-matrix), `SKILL.md`, `README.md`, and the iter5 SRE review
(`hidden_files/iter5-reviews/07-sre.md`) for continuity.

Method: two executed simulations, both read-only against the repo —
1. green-path run against the stub in this dev environment: audit exits 0,
   `Total: 59 passed · 0 failed · 2 skipped`; adversarial exits 0, `36/36`
   in ~1s. Healthy end-to-end cost is ~3s against the 20-minute job budget.
2. faithful clean-CI simulation: repo copied to /tmp, `local.env` removed
   (it is gitignored and absent in CI), fresh empty HOME, inert delegate
   binaries on PATH exactly as the workflow's provision step creates them.
   Result: audit exits 0 with `Total: 57 passed · 0 failed · 4 skipped`, and
   the workflow's skip-assertion logic, run verbatim against that log,
   fails with `validate: expected exactly 2 skips`.

Headline: iteration 5 did not touch `.github/workflows/validate.yml`, so
every workflow-level finding from the iter5 SRE review is still open — and
finding 1 below shows one of them is now provably failing, not just latent:
the committed workflow cannot pass on a clean runner.

Severity key: P0 = the committed CI cannot go green as written (breaks the
"honest green" claim). P1 = validation-pipeline reliability/correctness.
P2 = observability and assertion gaps. P3 = robustness nits.

---

## P0

### 1. The pinned skip set (exactly 2) does not match clean-CI reality (4) — the assertion step fails on a clean runner

**Severity:** P0
**Evidence:**
- `.github/workflows/validate.yml:113-125` — "Assert the expected skip set"
  pins `[ "${#skip_lines[@]}" -eq 2 ]` plus reason greps for `memory-audit
  run` and `gate log not found`. The comment claims stub-target runs skip
  exactly those two.
- `bin/leakage-audit:535` (`else skip "cron prompt dirs not configured"`),
  `:543` (`memory-audit`), `:572` (denylist: `else skip "no egress denylist"`),
  `:614` (gate log) — four independent skip paths, all
  reachable in CI.
- Clean-CI simulation (method above): the audit emits exactly these four
  `@@@ CHECK SKIP` lines —
  `cron prompt dirs not configured [set MOCHI_CRON_PROMPT_DIRS]`,
  `memory-audit run [set MOCHI_MEMORY_AUDIT=1 to include]`,
  `no egress denylist [~/memory/.egress-denylist missing or empty]`,
  `gate log not found [… (no sends attempted yet)]` —
  and the verbatim assertion step fails: `validate: expected exactly 2
  skips` (exit 1).
**Why it happened:** the pin was calibrated to the developer's machine,
not the runner. Locally, gitignored `local.env` sets
`MOCHI_CRON_PROMPT_DIRS` (so the cron check runs instead of skipping) and
`~/memory/.egress-denylist` exists (so the denylist check runs) — yielding
exactly 2 skips. In CI, `local.env` is absent (the workflow itself refuses
it, `:59-65`) and the runner HOME has no denylist — yielding 4. The pin
encodes the wrong environment.
**Recommendation:** keep the pinning mechanism (it is valuable — see the
Q4 verdict below) but calibrate it to CI: pin the 4 expected CI skips with
their reason strings, expressed as data (an array of expected reason
substrings) rather than ad-hoc greps, and print the expected set on
failure. Do NOT "fix" this by fabricating CI-only scaffolding (a stub
denylist, a dummy cron dir) just to get back to 2 — that would make the
pin prettier while testing less. Alternatively, make the audit emit a
single `@@@ SKIPSET` sentinel line listing skip reasons, and have the
workflow compare against an expected list — one comparison, no fragile
count-then-grep sequence.
**Residual if not fixed:** the validate workflow's skip-assertion step
fails on every clean run; CI can never be green at HEAD, and the
"Iteration 5: honest green" claim is false for the committed workflow.
(I could not confirm the Actions UI state — run history requires login —
but the step provably fails in a faithful runner simulation.)

---

## P1

### 2. No fail-at-the-end: a red audit produces no adversarial run, no report, no artifact, and a near-empty summary

**Severity:** P1
**Evidence:** `.github/workflows/validate.yml` — steps `:106` (audit),
`:113` (skip assertion), `:127` (adversarial), `:130` (report) carry no
`if:` condition. GitHub Actions skips every subsequent non-`always()` step
after the first failure. Only `:138` (upload) and `:146` (summary) have
`if: always()`. Consequences on a red audit (exit 1 — the *normal* red
case, i.e. findings):
- the adversarial suite never runs, so a detector regression hiding behind
  a plumbing failure is invisible;
- the HTML report — which embeds the raw transcripts of both runs, the
  single most useful debugging artifact — is never generated;
- the `if: always()` upload then fails anyway: `actions/upload-artifact`
  errors ("No files were found") when
  `${{ runner.temp }}/leakage-validation.html` does not exist;
- the `if: always()` summary prints its headers with empty bullets (every
  grep has `|| true`).
Debugging artifacts exist only when nothing is wrong. (Unchanged since
iter5 finding 1.)
**Recommendation — fail-at-the-end shape:**
- Keep the two `Refuse …` steps (`:49`, `:59`) fail-fast (no `if:`): they
  are safety preconditions; the audit must never run with live-fire
  variables present.
- Give every *component* step (`Provision`, `Syntax-check`, `Blockset`,
  `Audit`, `Skip-assert`, `Adversarial`, `Report`) `if: always()` and make
  each capture its own exit code instead of failing the job. The correct
  capture pattern under GitHub's default `bash -e -o pipefail` is:
  ```yaml
  - name: Run the leakage audit against the synthetic stub
    if: always()
    run: |
      set +e; set -o pipefail
      export PATH="$PERSONAL_MEMORY_SKILL/bin/shims:$PATH"
      MOCHI_AUDIT_MACHINE=1 MOCHI_REPORT_WIDTH=48 bin/leakage-audit \
        | tee "${{ runner.temp }}/audit.log"
      echo "${PIPESTATUS[0]}" > "${{ runner.temp }}/rc-audit"
  ```
  (`PIPESTATUS[0]`, not `$?`, is the audit's code rather than `tee`'s;
  `set +e` is required or the step dies before writing the rc file. Do
  NOT use `continue-on-error` — it muddies the step outcome; explicit rc
  files are auditable.)
- Apply the same to skip-assertion (it must tolerate a missing/partial
  `audit.log` and fail with a clear message, not a grep error),
  adversarial, and report (`leakage-report` exits 1 with report written,
  2 on refusal, 3 on generation failure — all meaningful, all captured).
- Keep `Upload` at `if: always()`; accept that it errors when no report
  was generated — the final step explains why.
- Add a final step `Assert green (fail-at-the-end verdict)`, `if:
  always()`, which reads every `rc-*` file, checks the report artifact
  exists, emits `::error::` annotations per failing component, and exits
  nonzero if anything is red. **This step's exit code — not any
  component's — determines the job outcome.**
- **What the job summary shows when each component is red:** a
  per-component table, every row sourced from machine sentinels
  (`@@@ TOTAL`, `@@@ VERDICT`, `@@@ MODE` from `audit.log`; the
  `adversarial-run: N/M cases matched` line), never scraped human text:
  `| Component | Status | Detail |` with one row each for Audit,
  Skip-set pin, Adversarial, Report, Artifact — e.g.
  `| Audit | ❌ FAIL | 57 passed · 2 failed · 4 skipped — VERDICT: ATTENTION |`.
  A red row links to the uploaded HTML report (its raw transcripts carry
  the evidence). If a log is missing entirely the row says `no log
  produced — see step logs` rather than rendering empty. The summary never
  shows CLEAN language when any component is red, and it always shows all
  five rows — never an empty section.
**Residual if not fixed:** red runs stay undebuggable from the CI UI; the
most likely real-world red (audit findings) is precisely the case where
the report artifact would be needed.

### 3. Worst-case hang budget (~21 min) exceeds the 20-minute job timeout — and the timeouts are ~1000× healthy latency

**Severity:** P1
**Evidence:** `bin/leakage-audit:336,338,360` — `timeout 30` on 14
`gate_expect` invocations (7 fixtures × 2 gates) and 16 `send_expect`
invocations; `bin/adversarial-run:62` — `timeout 10` on 36 corpus cases.
Worst case: (14+16)×30s + 36×10s = 900s + 360s = **1260s ≈ 21 min** >
`timeout-minutes: 20` (`.github/workflows/validate.yml:35`). A systemic
hang (e.g. a gate change that blocks on stdin in every check) is killed by
the job timeout — producing no report artifact, no summary content, and,
per finding 2, not even the partial `audit.log` beyond the step log — and
it is the slowest possible failure: the maintainer waits the full 20
minutes to learn nothing. Measured healthy latency is ~2s for the audit
and ~1s for the adversarial run; 30s per check is ~1000× headroom.
(Unchanged since iter5 finding 3; recomputed at HEAD — the two new
approval-isolation `send_expect` calls added 60s to the worst case.)
**Recommendation:** cut per-check timeouts to 10s (gates answer in
milliseconds; 10s is still ~100× headroom), bounding the worst case to
(30×10s + 36×10s) ≈ 11 min including the report's second run — or better,
fix finding 11 (single audit run) and land ≈ 7 min. Add per-step
`timeout-minutes: 3–5` (finding 12) so a hung provision/blockset/report
step fails fast; keep the 20-min job timeout as backstop. Combined with
finding 2's `if: always()`, a timeout kill then still leaves partial logs
and whatever artifact exists.
**Residual if not fixed:** any systemic hang burns the full 20-minute
budget and yields zero diagnostic artifacts — the worst failure mode for
the harness whose job is producing diagnostics.

### 4. `bin/leakage-report` invokes the audit and the adversarial suite with no timeout at all

**Severity:** P1
**Evidence:** `bin/leakage-report:40` —
`MOCHI_REPORT_WIDTH=48 MOCHI_AUDIT_MACHINE=1
"$SKILL_DIR/bin/leakage-audit" > "$AUD_TMP" 2>&1` — and `:46` —
`"$SKILL_DIR/bin/adversarial-run" > "$ADV_TMP" 2>&1`. Neither is wrapped
in `timeout`. The Python heredoc that follows is bounded (it parses files),
but if the audit or the adversarial run hangs, the "Generate the HTML
validation report" step hangs with it — bounded only by the job timeout,
with no artifact and no message. The audit's *internal* per-check timeouts
do not bound the *report's* invocation of the audit as a whole (and per
finding 3, even those sum past the job budget). The brief explicitly asked
about "the report's Python" — the Python is fine; the two unbounded
subprocess invocations above it are the hole.
**Recommendation:** wrap both invocations, e.g.
`timeout -k 10 600 "$SKILL_DIR/bin/leakage-audit" > "$AUD_TMP" 2>&1`,
treat 124 as "component timed out" (report still written from the partial
log if parseable, else exit 3 with a clear message naming the hung
component). This also bounds the report step for local operators, not just
CI.
**Residual if not fixed:** a hung gate turns the report step — the step
whose artifact is the whole point of the run — into a silent 20-minute
hang with no output.

### 5. Delegates provisioned via `sudo` into shared `/usr/local/bin` — non-hermetic, and the smoke test models the forbidden bypass

**Severity:** P1
**Evidence:** `.github/workflows/validate.yml:67-84` — "Provision inert
delegate CLIs behind the stub shims" runs `sudo tee
/usr/local/bin/hatch_gws_cli`, `sudo tee
/usr/local/bin/hatch_messenger_cli`, `sudo chmod +x …`, then smoke-tests
them by absolute path (`/usr/local/bin/hatch_gws_cli &&
/usr/local/bin/hatch_messenger_cli`). This writes outside the workspace to
a path shared by every job on the runner; it works on `ubuntu-latest`
(passwordless sudo, `/usr/local/bin` on PATH) but a sudo password prompt
on a self-hosted runner would hang the step until the job timeout, and two
concurrent runs outside the concurrency group (e.g. a local repro running
the same commands) can clobber each other's delegates. The "second,
distinct executable" invariant (`references/gate-interface.md`) does not
require a system directory. Secondary irony: the smoke test invokes the
delegates **by absolute path** — the exact bypass the repo's own policy
forbids ("Never invoke a delegate binary by absolute path to dodge the
gate", `AGENTS.md`). (Unchanged since iter5 finding 4.)
**Recommendation (hermetic):** provision into `$RUNNER_TEMP/delegates`
(unique per job, auto-cleaned):
```yaml
- name: Provision inert delegate CLIs behind the stub shims
  run: |
    d="${{ runner.temp }}/delegates"; mkdir -p "$d"
    printf '#!/usr/bin/env bash\nexit 0\n' | tee "$d/hatch_gws_cli" > /dev/null
    printf '#!/usr/bin/env bash\nexit 0\n' | tee "$d/hatch_messenger_cli" > /dev/null
    chmod +x "$d"/hatch_gws_cli "$d"/hatch_messenger_cli
    echo "$d" >> "$GITHUB_PATH"   # or export PATH in later steps
```
and set `PATH="$PERSONAL_MEMORY_SKILL/bin/shims:${{ runner.temp }}/delegates:$PATH"`
in the audit/adversarial/report steps — shim dir first, so the shadowing
invariant the audit asserts (`bin/leakage-audit`, suite A: "shim shadows
real binary on PATH", "real binary discoverable behind shim") passes
identically. No sudo, no writes outside the workspace, no cross-job
interference, works on self-hosted runners. (Verified the PATH-scan logic
in `bin/leakage-audit` suite A and the stub shims both honor "first shim
dir, then any later dir with the delegate".)
**Residual if not fixed:** CI stays coupled to passwordless-sudo
`ubuntu-latest` specifics; a self-hosted runner or a sudo-prompt
regression turns provisioning into a 20-minute silent hang.

### 6. No `timeout -k`: a TERM-trapping gate/shim hangs the check forever despite the "30s" bound

**Severity:** P1
**Evidence:** every `timeout` in the repo is bare —
`bin/leakage-audit:336,338,360` (`timeout 30`), `bin/adversarial-run:62`
(`timeout 10`). GNU `timeout` without `-k/--kill-after` sends SIGTERM and
then *waits indefinitely* for the process to exit. If a future gate, shim,
or delegate ever installs a TERM trap (or ignores SIGTERM), the "30s"
bound is fiction: the check hangs until the job timeout. The timeout
branches that report rc=124 as failures are therefore only as reliable as
the assumption that nothing traps TERM — an assumption nothing enforces.
(Unchanged since iter5 finding 2, secondary point.)
**Recommendation:** switch all wraps to `timeout -k 10 30 …` /
`timeout -k 5 10 …` (and the new report-level wraps in finding 4) so a
TERM-ignoring process is SIGKILLed and the bound is real.
**Residual if not fixed:** the per-check timeouts are advisory, not
enforced — a single TERM-trap in a gate or delegate converts any check
into an unbounded hang.

### 7. Fake delegates model only the happy path — the timeout/failure branches are dead code in CI

**Severity:** P1 — answers brief focus Q3.
**Evidence:** `bin/leakage-audit:292-328` — the suite-B fakes
(`$T/fakebin/real-gws`, `real-msg`) implement exactly one behavior:
instant `exit 0` with canned stdout. There is no fake variant that (a)
hangs past the 30s `timeout`, (b) responds slowly, (c) emits partial or
garbage output, or (d) exits nonzero as a delegate. The rc=124 branches in
`gate_expect` (`:334-339`) and `send_expect` (`:358-364`) are therefore
never exercised — if a future edit dropped `timeout 30`, nothing would
turn red. (Unchanged since iter5 finding 2, main point.)
**What *is* verified solid (brief Q3, first half):** timeout outcomes ARE
asserted as failures, never passes. `gate_expect` converts rc=124 into
`bad` ("gate timed out after 30s… do not trust verdicts"); `send_expect`
does the same; `adversarial-run:63-67` converts 124 into a MISMATCH with
`got TIMEOUT (gate hung >10s)` and counts it as a failure. The assertions
are exact-match on `(rc, invoked)`, so any unexpected exit code (125/126/
127/137) is also a failure, never a pass. The gap is purely that no test
drives those branches.
**Recommendation:** add fake-binary variants selectable via env (at
minimum `hang-35s`, `slow-25s`, `exit-3`, `garbage-stdout`), exercised by
a small dedicated suite (or as infrastructure cases alongside the corpus —
not in the pinned 36, per the brief constraint), including a negative test
that a hanging gate yields rc=124 and is reported as a timeout failure.
Combine with finding 6's `timeout -k`.
**Residual if not fixed:** timeout regressions are undetectable by the
harness itself — the safety net has never been load-tested.

---

## P2

### 8. Step summary scrapes human-rendered text instead of the machine sentinels

**Severity:** P2
**Evidence:** `.github/workflows/validate.yml:146-156` — "Summarize the
validation" extracts figures with `grep -aE 'Total: [0-9]+ passed'` and
`'adversarial-run: [0-9]+/[0-9]+ cases matched'` from rendered text. The
audit emits purpose-built, forgery-sanitized sentinels (`@@@ TOTAL p f s`,
`@@@ VERDICT …`, `@@@ MODE …`, `@@@ STUBKIND …` — `bin/leakage-audit`,
`msent`), but the one CI consumer ignores them. A width/layout change (the
`WIDTH >= 56` branch of `print_summary` renders the Total row without the
colon, so the grep silently matches nothing) or a copy edit empties the
summary while the job stays green. (Unchanged since iter5 finding 8.)
**Recommendation:** parse `^@@@ TOTAL`, `^@@@ VERDICT`, `^@@@ MODE` from
`audit.log` in the summary step (and keep the `adversarial-run:` line
parse, or add a sentinel there too); this is subsumed by the finding-2
summary redesign — the per-component table is built from sentinels, never
from prose.
**Residual if not fixed:** the summary can go silently empty while CI is
green, and any future layout change breaks observability without breaking
the build.

### 9. Total pass count is echoed but never asserted — silently dropped checks go green

**Severity:** P2
**Evidence:** the workflow pins skip count and skip reasons (`:113-125`)
but nothing pins the pass count. Measured healthy totals differ by
environment: **57 passed / 4 skipped in clean CI** (simulation) vs 59
passed / 2 skipped on the developer machine (local.env + denylist
present). A refactor that accidentally deletes or early-returns a block of
checks (e.g. a broken `begin_suite`/`end_suite` pairing, a loop that
iterates zero times) would go green with fewer passes and the same skips.
(Unchanged since iter5 finding 7.)
**Recommendation:** pin per-suite subtotals from the `@@@ ENDSUITE`
sentinels (letter, pass, fail, skip) — strictly stronger than a single
total — **calibrated to the CI environment** (57/0/4 today, not the dev
machine's 59/0/2), the same way the skip pin must be (finding 1). Expect to
update the pin when checks are intentionally added/removed; the failure
message should print expected vs actual per suite.
**Residual if not fixed:** coverage can silently shrink while CI stays
green — the exact failure mode a validation harness exists to prevent.

### 10. Live-fire discovery commands run with no timeout at all

**Severity:** P2
**Evidence:** `bin/leakage-audit:446`
(`"$G" gmail users getProfile …`) and `:472`
(`"$M" threads --limit 50 …`) invoke the *real* CLIs with no `timeout`
wrapper, unlike every simulated-path call. A hung real CLI here hangs the
audit indefinitely — no 30s bound, only the 20-min job timeout (and no job
timeout at all for a local operator's terminal). CI never runs live-fire,
but the audit is also a local-ops tool. (Unchanged since iter5 finding 6.)
**Recommendation:** wrap both in `timeout -k 10 30` and report a timeout
as a fail-closed `bad` with the same "do not trust verdicts from this
installation until it answers" wording `gate_expect` uses.
**Residual if not fixed:** a hung real CLI in live-fire hangs the
operator's terminal with no message and no bound.

### 11. The audit runs twice per CI job and the two runs can disagree

**Severity:** P2
**Evidence:** `.github/workflows/validate.yml:106-111` runs
`bin/leakage-audit | tee ${{ runner.temp }}/audit.log`; then `:130-136`
runs `bin/leakage-report`, which re-runs the identical audit internally
(`bin/leakage-report:40`) into a separate temp file. The skip-assertion and
the summary judge the *first* run; the uploaded artifact's badge judges
the *second*. If the two runs ever disagree (flaky gate, time-dependent
behavior), the artifact can say ATTENTION while CI passed the first run —
or vice versa. It also doubles the hang-budget exposure (finding 3) and
the ~2× healthy runtime.
**Recommendation:** run once per job: teach `bin/leakage-report` to accept
pre-run logs (e.g. `--audit-log/--adversarial-log`), with the current
run-it-itself behavior as the default for local use; the workflow then
passes the tee'd logs. Single canonical run, single verdict.
**Residual if not fixed:** the artifact CI uploads is not the run CI
judged — a latent source of "but the report says…" confusion.

### 12. No per-step timeouts — any hung step burns the whole job budget

**Severity:** P2
**Evidence:** `.github/workflows/validate.yml:35` sets only job-level
`timeout-minutes: 20`. No step — provision (`:67`, with its sudo call),
syntax-check (`:87`), blockset check (`:103`), report generation (`:130`)
— has an individual bound. (Unchanged since iter5 finding 9; raised to P2
here because finding 5's sudo-prompt hang scenario makes it concrete.)
**Recommendation:** `timeout-minutes: 3` on each step (5 for the audit and
report steps once finding 3's reductions land); keep 20 at the job level
as backstop.
**Residual if not fixed:** a hang in an early step wastes up to 20 minutes
before the maintainer learns anything.

---

## P3

### 13. Header timestamp defeats byte-diff forensics across runs

**Severity:** P3
**Evidence:** `bin/leakage-audit` `print_header` emits `date '+%Y-%m-%d
%H:%M %Z'` in human text and the `@@@ TS` sentinel; `bin/leakage-report`
embeds the transcript verbatim in the HTML artifact. Two behaviorally
identical green runs therefore produce different bytes, so `audit.log`
cannot be diffed across runs to detect drift or to confirm a red is "the
same red as last night". (Unchanged since iter5 finding 5.)
**Recommendation:** add a `MOCHI_AUDIT_FIXED_TS` override (CI pins it for
artifact comparison) or document that transcript diffs must strip the two
header lines. Cosmetic, but it currently defeats "green for the wrong
reasons" forensics on flaky reds.
**Residual if not fixed:** none functional; slower 2am debugging.

### 14. `build-blockset.sh` sorts without a pinned locale; `--check` compares byte-exact

**Severity:** P3
**Evidence:**
`test/stub-memory-skill/build/build-blockset.sh` pipes through `sort -u`
twice with no `LC_ALL` pinning (verified: no `LC_ALL` anywhere in
`bin/`, `test/`, or the workflow), while `--check` compares with byte-exact
`cmp -s`. A locale change between the machine that wrote `blockset.txt`
and CI could flip ordering and fail the check with no semantic change.
Stable today on `ubuntu-latest` (C.UTF-8) — latent, not active.
(Unchanged since iter5 finding 10a.)
**Recommendation:** `export LC_ALL=C` at the top of the build/check
pipeline.
**Residual if not fixed:** a future runner-image locale change produces a
mystifying red.

### 15. Suite-B temp dir has no trap; `mktemp -d` failure is unchecked

**Severity:** P3
**Evidence:** `bin/leakage-audit` — `T="$(mktemp -d)"` (suite B) is
cleaned only by the trailing `rm -rf "$T"` on the happy path; no
`trap … EXIT`. A SIGTERM/SIGINT mid-suite (e.g. the job timeout firing)
litters `/tmp` with fixture-derived temp dirs. If `mktemp` itself failed,
`T` would be empty and `rm -rf "$T"` errors while the fakes'
`touch "$T_INVOKED_DIR/invoked-any"` degrades to `touch "/invoked-any"`
(permission-denied → fake exits 1 → loud test failures, not silent
green — so fail-closed, but noisy and confusing).
**Recommendation:** `T="$(mktemp -d)" || { echo "…mktemp failed" >&2;
exit 2; }` and `trap 'rm -rf "$T"' EXIT` (guarded for unset T).
**Residual if not fixed:** /tmp litter on kills; a pathological mktemp
failure yields confusing cascading failures instead of one clear error.

### 16. `send_expect`'s stdin arrives via implicit redirect inheritance — fragile

**Severity:** P3
**Evidence:** `bin/leakage-audit:404,411-413` — e.g.
`send_expect "messenger send clean passes" 0 1 -- $M send --cid '999'
--text-stdin < "$FIX/clean.txt"`. The `<` redirect applies to the
`send_expect` *function call*; the fixture reaches the shim only because
`out="$(timeout 30 "$@" 2>&1)"` (`:360`) inherits the function's stdin
through the command substitution. It works, but the data flow is invisible
at the call site — a future editor "fixing" quoting or restructuring the
function can silently change what the shim reads (empty stdin → gate sees
`(no payload)`-equivalent empty input → clean passes vacuously).
**Recommendation:** make it explicit — pass the fixture path and redirect
inside `send_expect` (`... < "$fixture"` at the `timeout` invocation), or
add a comment at the function definition documenting the contract.
**Residual if not fixed:** a well-meaning refactor can silently turn
stdin-gated checks vacuous.

### 17. `bin/leakage-report` has no explicit `python3` presence check

**Severity:** P3
**Evidence:** `bin/leakage-report:48` — `python3 - … <<'PYEOF'`; if
python3 is missing the script dies with "command not found" (exit 127),
caught only generically as "HTML generation failed" (exit 3). The stub
shim already models the better pattern
(`test/stub-memory-skill/bin/shims/hatch_gws_cli`: fail-closed message
when python3 is missing).
**Recommendation:** `command -v python3 >/dev/null || { echo
"leakage-report: python3 is required …" >&2; exit 3; }` before the
heredoc.
**Residual if not fixed:** cryptic failure on minimal images.

---

## Brief focus questions — verdicts

1. **CI fail-at-the-end:** confirmed broken as described; full design in
   finding 2 (always-run components with rc-file capture, `PIPESTATUS`
   pattern, final assert step owning the job outcome; refuse-steps stay
   fail-fast). The summary on red must show a five-row per-component table
   (Audit / Skip-set pin / Adversarial / Report / Artifact) sourced from
   `@@@` sentinels, with red rows linking to the uploaded report's raw
   transcripts — never an empty section, never CLEAN language when
   anything is red.
2. **Hermetic delegates:** finding 5 — `$RUNNER_TEMP/delegates` on PATH
   after the shim dir; drop sudo entirely; fixes the self-hosted-runner
   hang and the absolute-path smoke-test irony as side effects.
3. **Timeout/fake-delegate failure modes:** timeout outcomes ARE asserted
   as failures everywhere (never passes — exact-match on `(rc, invoked)`);
   but NO test exists where the fake delegate itself fails — the rc=124
   branches are dead code (finding 7).
4. **Pinned skip set:** pinning is *valuable* (it catches a check that
   starts skipping instead of failing — otherwise silent green), but the
   current pin is *miscalibrated*: it encodes the dev machine (2 skips),
   not CI (4 skips), so the assertion step fails on a clean runner
   (finding 1). When a legitimate new skip appears, the intended behavior
   is: CI fails with the expected-vs-actual sets printed, and the PR that
   introduces the skip updates the pin (one-line, review-visible). That
   brittleness is the feature — provided the baseline is honest. Fix:
   pin the 4 CI skips as data, calibrated in CI.
5. **20-minute budget vs runtimes:** healthy is ~3s; the budget is purely
   a hang-containment net, and the net has holes — worst-case hang is
   ~21 min > 20 min (finding 3), and the report step's two subprocess
   invocations are entirely unbounded (finding 4).

## Verified solid (not findings)

- `@@@` sentinel forgery-sanitization (`@@@`→`[at]`, newline collapse);
  per-check invocation asserted by sentinel *file*, not stdout.
- Exact-match `(rc, invoked)` assertions: no unexpected outcome can pass.
- Fail-closed on fixture/corpus/blockset rot; `local.env` never overrides
  explicit env and never arms live-fire; live-fire refused against stubs,
  in CI, and non-interactively.
- Report writes atomically (`os.replace`) and refuses to emit a report it
  cannot parse; `set -o pipefail` on the tee'd audit step; SHA-pinned
  actions; shallow checkout; `pull_request` (not `pull_request_target`);
  `concurrency: cancel-in-progress`.
- The iteration-5 additions reviewed clean from the SRE angle:
  approval-isolation tests, fail-closed undecodable-MIME handling,
  newline-separated token extraction, widened fixture-purity SHAPES.

## Suggested priority order for iteration 6

1. Finding 1 (P0) — recalibrate the skip pin to the 4 CI skips; CI cannot
   be green until this lands.
2. Finding 2 (P1) — fail-at-the-end with rc-file capture + final assert +
   sentinel-based summary.
3. Findings 3+4+12 (P1/P2) — 10s per-check timeouts, bounded report
   subprocesses, per-step `timeout-minutes` (worst case ≈ 7 min).
4. Finding 5 (P1) — hermetic delegates under `$RUNNER_TEMP`, drop sudo.
5. Findings 6+7 (P1) — `timeout -k` everywhere + fake-delegate failure
   variants so the timeout branches are actually exercised.
6. Findings 8+9 (P2) — sentinel-based summary; pin per-suite subtotals
   from `@@@ ENDSUITE`, calibrated to CI (57/0/4).
