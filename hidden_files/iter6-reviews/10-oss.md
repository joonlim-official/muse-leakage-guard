# Iteration 6 review — Open-source community maintainer

Reviewer perspective: first external contributor / fork-PR author / newcomer
evaluating the repo cold. Read-only review at HEAD `5ff8950`
("Iteration 5: honest green"). No repo files were modified.

Method: read README, CONTRIBUTING, SKILL.md, the CI workflow, CODEOWNERS,
LICENSE, `local.env.example`, the stub README, references docs, and the
scripts; then **executed** both documented quickstarts in a scratch clone
(`/tmp/coldtest`, checked out at HEAD) — once with the machine's normal
environment and once with a fresh `HOME=/tmp/fakehome` to emulate a
contributor's cold machine / GitHub Actions runner — and ran the CI
workflow's skip-assertion block verbatim against the simulated audit log.

Verdict on the cold run: the harness itself works well (audit CLEAN,
adversarial 36/36, report generates), but the repo's CI and contributor
docs have a small number of sharp, deterministic defects. Two of them make
every fork PR fail red for reasons no contributor can fix.

---

## HIGH

### H1. CI skip-set assertion is unreachable — every fork PR fails red

**Evidence:**
- `.github/workflows/validate.yml:113-125` — "Assert the expected skip
  set (no silent new skips)": `[ "${#skip_lines[@]}" -eq 2 ] || exit 1`,
  with the comment (lines 114-121) claiming a stub-target run "is expected
  to skip exactly: 1. memory-audit …, 2. gate-log review …".
- `bin/leakage-audit` legitimately skips **four** things in a runner-like
  environment: (a) `skip "cron prompt dirs not configured"` (MOCHI_CRON_PROMPT_DIRS
  unset in CI), (b) `skip "memory-audit run"` (opt-in), (c) `skip "no egress
  denylist"` (no `~/memory/.egress-denylist` on a runner — the check is
  designed to skip), (d) `skip "gate log not found"` (fresh CI log).

**Reproduction** (fresh `HOME`, exact CI env + commands):
```
@@@ CHECK SKIP cron prompt dirs not configured [set MOCHI_CRON_PROMPT_DIRS]
@@@ CHECK SKIP memory-audit run [set MOCHI_MEMORY_AUDIT=1 to include]
@@@ CHECK SKIP no egress denylist [~/memory/.egress-denylist missing or empty]
@@@ CHECK SKIP gate log not found [~/workspace/memory-sync/egress-gate.log (no sends attempted yet)]
```
→ `validate: expected exactly 2 skips`, step exits 1. The assertion cannot
pass in real CI: the cron and denylist skips are structurally unavoidable
on a runner, and no workflow input suppresses them.

**Recommendation:** Pin the real expectation — assert exactly these four
skip reasons by name (cron-dirs-unconfigured, memory-audit opt-in,
denylist absent, gate-log absent) — and fix the stale comment. Do not
weaken the check to a minimum count; the point is "no silent *new*
skips".

**Residual if not fixed:** Every fork PR (and every push to `main`) gets a
red X at the "Assert the expected skip set" step that no contributor can
fix from their side. This is the single worst fork-PR experience defect in
the repo.

### H2. Fork-PR failure cascade: no diagnosable artifacts when steps fail

**Evidence:**
- `.github/workflows/validate.yml` — only "Upload the validation report"
  and "Summarize the validation" carry `if: always()`. If the audit step
  *or* the skip-assertion step fails, "Run the adversarial suite" and
  "Generate the HTML validation report" are skipped entirely.
- The report-generation step is exactly the artifact that would explain an
  audit failure (`bin/leakage-report` writes HTML with findings from a
  failed-but-parseable audit — it exits 1, still writing the report; it
  only refuses on exit-2 audit refusal). Skipping it on audit failure
  throws away the diagnosis.
- "Upload the validation report" (`if: always()`) then runs against a
  nonexistent `leakage-validation.html` → errors, and "Summarize" greps
  missing/partial logs (`|| true`) → a near-empty step summary: the
  contributor sees a red workflow and a summary with no Audit/Adversarial
  lines.

**Recommendation:** Add `if: always()` to the adversarial-run and
report-generation steps so failure evidence is captured as artifacts
regardless of earlier step outcomes; make the upload step conditional on
the file existing; keep the workflow's overall verdict gated on the
audit/assert steps. (Related to H1: with H1 fixed, the common path is
green; this covers the remaining failure modes.)

**Residual if not fixed:** A fork-PR contributor whose audit genuinely
fails cannot diagnose it from the PR page (summary + artifacts) alone —
they must re-run locally and guess, which is the exact experience the
brief asked me to test.

---

## MEDIUM

### M1. CONTRIBUTING quickstart fails on a truly cold machine

**Evidence:**
- `CONTRIBUTING.md:19-33` quickstart sets
  `export PATH="$PERSONAL_MEMORY_SKILL/bin/shims:$PATH"` and says step 2:
  "The audit needs a second executable CLI behind each shim on PATH. (In
  CI these are inert fakes; locally any second executable works — it is
  never invoked with real data in simulated mode.)"
- On a machine with no hatch CLIs installed (fresh contributor laptop),
  the audit's A-suite fails: `real hatch_gws_cli not found on PATH — shim
  has nothing to delegate to`, and the printed suggestion is "install the
  real CLI" — steering the contributor *toward* the real installation,
  the opposite of the stub-first promise.
- Reproduced: sanitized PATH (shims dir + core utils only) → `bin/leakage-audit`
  exits 1, "Total: 57 passed · 2 failed · 2 skipped".
- The README quickstart (iter-5 addition) has the copy-paste inert-delegate
  provisioning block; CONTRIBUTING's quickstart does not, and it also lacks
  the PATH-ordering explanation ("shims FIRST … inert delegates AFTER").
  Same gap in `test/stub-memory-skill/README.md` "Using it", which points
  at CI's fakes (`.github/workflows/validate.yml`) without a local
  copy-paste step.

**Recommendation:** Port the README's inert-delegate provisioning block
into CONTRIBUTING's quickstart verbatim (and cross-reference it from the
stub README). One canonical snippet, referenced twice, not rewritten twice.

**Residual if not fixed:** Newcomers following CONTRIBUTING alone hit a red
audit they didn't cause, plus a suggestion that pushes them off the
supported stub-first path.

### M2. CI summary greps 'block-tier recall' — still stale at HEAD (known example)

**Evidence:**
- `.github/workflows/validate.yml:156`:
  `grep -aE 'block-tier recall' "${{ runner.temp }}/adversarial.log"`.
- `bin/adversarial-run:86` prints
  `adversarial-run: block-tier pass 19/19 · review-tier pass 9/9 · clean pass 8/8`
  (iteration 5 renamed recall → pass rates). The grep matches nothing, so
  with `|| true` the line silently vanishes from the PR summary.
- The neighboring greps are healthy: `Total: [0-9]+ passed` and
  `adversarial-run: [0-9]+/[0-9]+ cases matched` both match current output.

**Recommendation:** Grep `'block-tier pass'` instead. Consider asserting
(not `|| true`) on the two load-bearing greps so future renames fail
loudly instead of silently dropping summary lines.

**Residual if not fixed:** Cosmetic, but it silently degrades the one
summary a contributor reads — and it is the same text-scraping fragility
the machine-sentinel work was meant to retire.

### M3. Approval-isolation tests are undocumented in the scenario catalog

**Evidence:**
- Iteration 5 added two B-suite checks (`bin/leakage-audit`: `send_expect
  "gmail +send secret stays blocked with approval (approval isolation)"`
  and the messenger equivalent) — confirmed in `CHANGELOG.md` ("Approval
  isolation") and in code comments.
- `README.md:36-53` scenario catalog B-table lists B1–B17 with no
  approval-isolation row. A newcomer cannot map two of the audit's checks
  to any documented scenario — the inverse of the usual docs-drift, but the
  same "docs describe fewer behaviors than the code has" category as the
  brief's focus area.

**Recommendation:** Add B18/B19 rows (gmail + messenger, approval
isolation) to the README catalog.

**Residual if not fixed:** Contributors auditing the B-suite against the
docs find undocumented checks; the coverage-map discipline
("every check has a documented scenario") is violated in spirit.

### M4. `bin/leakage-report` exit-code docs are imprecise (README) and incomplete (SKILL.md)

**Evidence:**
- `README.md` ("What a real run reports"): "Exits with the audit's exit
  code (0 = CLEAN)." Not true in one case: if the audit is CLEAN (rc 0)
  but the adversarial suite mismatches, `bin/leakage-report` exits **1**
  while the audit exited 0
  (`if [ "$RC" -ne 0 ] || [ "$ADV_RC" -ne 0 ]; then exit 1`).
- `SKILL.md` ("How to run") documents report exits 0/1/3 but omits exit 2
  (usage error, or the audit refused to run — no report written), which the
  script header documents and the code implements.

**Recommendation:** State the composition explicitly in both places: exit 0
= audit CLEAN *and* all adversarial cases matched; exit 1 = findings or
mismatches (report still written); exit 2 = usage error / audit refused
(no report); exit 3 = report unparseable (no HTML written).

**Residual if not fixed:** Minor — but contributors scripting the report in
their own harnesses can misread a 1 as "audit failed" or miss that exit 2
means "no report exists".

### M5. Pre-purge private values remain in public git history (disclosed, unresolved)

**Evidence:**
- `ITERATIONS.md:25` (iteration 2): "pre-purge private values remain in
  public history around `918e243` — no rewrite without the owner's
  decision." Verified still present: `git show 918e243:bin/adversarial-corpus.txt`
  contains the pre-scrub `order_num` (a real confirmation number) and
  `zip_code` (home zip) lines; later commits replaced them with synthetic
  values (`5550001234`, `90210`). Current-tree fixtures are clean
  (fixture-purity check passes).
- The commit also carries the owner's personal email as author
  (normal for GitHub, but it is in the public record).

**Recommendation:** This is the owner's call (as the disclosure says). If
the repo is already pushed to github.com/joonlim-official, history rewrite
won't retract existing clones — in that case, record the accept-the-risk
decision in-repo (e.g., a short note in `SECURITY.md`, see L2) and close
the thread. Do not propose the rewrite unilaterally.

**Residual if not fixed:** The values stay fetchable from history; anyone
cloning the repo gets them. The disclosure is honest, but the thread is
open.

---

## LOW

### L1. Remaining "36/36" literals: acceptable, but a magic constant in 6 places

**Evidence:** `SKILL.md:116`, `references/attack-surface.md:256`,
`references/gate-interface.md:84`, `test/stub-memory-skill/README.md:29-30`
(plus historical uses in `CHANGELOG.md`/`ITERATIONS.md`, which are
correctly frozen as history). All live uses are in the specific
stub-consistency disclaimer context the brief allows, and the number is
real: `bin/adversarial-corpus.txt` has exactly 36 non-comment cases
(verified), and the corpus is pinned by parent constraint (no change
proposed).

**Recommendation:** Keep the wording; add one cheap tripwire so a future
corpus revision can't silently stale them — e.g., a CI step asserting the
corpus case count equals the number quoted in the stub-disclaimer docs, or
a single "corpus size" note in `references/test-matrix.md` that the other
docs reference.

**Residual if not fixed:** None today; future corpus edits would leave
stale numbers in user-facing disclaimers.

### L2. No SECURITY.md / issue templates — no private channel for bypass reports

**Evidence:** `.github/` contains only `CODEOWNERS` and `workflows/`. For a
tool whose whole purpose is *finding protection bypasses*, there is no
documented way to report a bypass privately; a contributor's responsible
move would be a public issue describing a leakage hole.

**Recommendation:** Add a minimal `SECURITY.md` naming a private reporting
contact (the owner's address, already public in git history) and a
"please don't open public issues for suspected bypasses" note. Optional:
PR/issue templates.

**Residual if not fixed:** Security-sensitive findings arrive as public
issues, or don't arrive at all.

### L3. Newcomer verdict line mentions skips the quickstart never explains

**Evidence:** On a contributor's cold machine (fresh HOME), the README
quickstart yields `VERDICT: CLEAN — all 57 checks passed (4 skipped).`
The four skips (cron dirs, memory-audit, denylist, gate log) are all
legitimate, but the quickstart says only "expect CLEAN and every corpus
case matched" — a first-timer has to go read the audit source to learn
that skips are expected and don't fail the run.

**Recommendation:** One sentence in the quickstart: "4 skips on a fresh
machine are expected (opt-in memory audit, unconfigured cron dirs, no
denylist, no gate log yet); skips don't fail the run."

**Residual if not fixed:** Cosmetic confusion only; no functional impact.

### L4. CI "Syntax-check every shell script" uses a hand-maintained file list

**Evidence:** `.github/workflows/validate.yml` enumerates 10 script paths
in a `for` loop. A contributor adding a new script (e.g., a new
provisioning helper per M1's recommendation) gets no syntax check unless
they also edit the workflow. The current list happens to be complete
(verified against `git ls-files` shebang scan).

**Recommendation:** Derive the list with `find` (e.g., all tracked files
with a bash shebang, excluding `hidden_files/`), so the check covers new
scripts automatically.

**Residual if not fixed:** A syntactically broken new script could pass CI's
syntax gate.

---

## Notes (checked, no finding)

- `local.env` is gitignored and untracked; the committed
  `hidden_files/reports/leakage-validation-*.html` owner reports are also
  ignored (only `.gitkeep` files are tracked). The CI "refuse a committed
  local.env" step works as documented.
- Coverage-map discipline holds: 23 `### [A-E][0-9]+.` scenarios in
  `references/attack-surface.md`, 23 matching rows in
  `references/test-matrix.md`.
- The 36-case corpus is intact (`build-blockset.sh --check` passes, 21
  tokens; adversarial 36/36 with block 19/19, review 9/9, clean 8/8).
- PATH-ordering notes added in iteration 5 are sufficient *in the README*
  (shims-first rationale is explicit and correct). The gap is that
  CONTRIBUTING and the stub README don't carry them (M1).
- `bin/leakage-audit -h` / `bin/adversarial-run -h` work as documented.
- CI safety shape is as advertised: `pull_request` (not `pull_request_target`),
  `contents: read`, `persist-credentials: false`, `fetch-depth: 1`,
  SHA-pinned actions, live-fire variables refused, no secrets. No finding.
- The stub's "not protection / not a detector" disclaimers are prominent
  and repeated in the right places (stub README, report banner, SKILL.md).

## Suggested shape of the one focused diff

1. Fix the CI skip assertion (H1) + `if: always()` on adversarial/report
   steps and conditional upload (H2).
2. Port the inert-delegate block into CONTRIBUTING + stub README (M1).
3. One-line CI summary grep fix (M2).
4. B18/B19 catalog rows (M3); exit-code wording touch-ups (M4).
5. `SECURITY.md` (L2); optional: corpus-count tripwire (L1),
   find-based syntax check (L4), skip-expectation sentence (L3).
6. Owner decision on the 918e243 history thread (M5) — recorded in-repo.

Privacy note for this review: per the brief, no personal details were
needed or used. All payloads examined were the repo's own synthetic
fixtures; the only real identifiers encountered were the author's public
git identity and the already-disclosed history thread (M5).
