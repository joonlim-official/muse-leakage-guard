# Privacy review — muse-leakage-guard @ e35c1bc (iteration 9)

Reviewer persona: senior privacy engineer. Scope: fixture purity
(synthetic-only guarantees), whether any real private data could enter the
repo/CI/logs, literal republication of audit evidence, disclosure risks in
reports and error output, over-claimed privacy guarantees.

Method: full read of `bin/leakage-audit` (730 lines), `bin/leakage-report`
(822 lines), `bin/adversarial-run`, fixtures, corpus, SYNTHETIC.txt,
`references/{attack-surface,gate-interface,test-matrix}.md`,
`.github/workflows/validate.yml`, the stub skill (gates, shims,
patterns.sh, build-blockset.sh), plus the gates/shims under test in
`~/workspace/skills/personal-memory-system` (read-only; log *formats* only,
never log contents or the denylist contents). Execution was
simulated-mode only against the synthetic stub — no live-fire, no sends,
no real private data touched. `git status` confirms no tracked files were
modified.

## Execution results (confirmed by execution)

- `bin/leakage-audit` vs stub (SIMULATED): **66 passed · 0 failed ·
  2 skipped → CLEAN**, exit 0. (Skips: `memory-audit run` [opt-in not set],
  `gate log not found` [fresh temp log].)
- `bin/adversarial-run` vs stub: **36/36 matched** (block 19/19, review
  9/9, clean 8/8), exit 0.
- `MOCHI_LIVE_FIRE=1` vs stub target: **refused, exit 2**, no sends.
- `MOCHI_LIVE_FIRE=1` from `local.env` only: **ignored with loud warning**,
  run continued simulated, exit 0. (`local.env` restored byte-identical
  afterwards; `git status` clean.)
- Fixture contents are synthetic and every secret-shaped token is declared
  in `bin/fixtures/SYNTHETIC.txt` (purity check passes). The one redaction
  observed in tool output (`api_key: <redacted>`) is the harness redacting
  the *declared synthetic* token `sk-testfakekey1234567890abcdefgh` — the
  fixture is fine; the redaction is environmental, not a repo defect.

## Findings

Severity: P0 critical / P1 high / P2 medium / P3 low.

---

### P1-1. Suite C republishes memory-audit evidence verbatim — including denylisted private literals

- **Where:** `bin/leakage-audit:630-638`
  ```bash
  audit_out="$("$MEM_SKILL/bin/memory-audit" 2>&1)"; arc=$?
  ...
  detail="$(printf '%s\n' "$audit_out" | grep -E '^  (/|!)' | head -12)"
  bad "memory-audit reported findings (judge public vs private yourself)" "$detail" ...
  ```
- **What:** On memory-audit failure (opt-in `MOCHI_MEMORY_AUDIT=1`), up to
  12 raw output lines are embedded in the audit's Findings and in the HTML
  report (Findings card + raw transcript). The real `memory-audit`'s
  `flag()` prints `  ! <message>` and its check #8
  (`personal-memory-system/bin/memory-audit:178-192`) prints
  `  <file>:<line>` for every denylisted-literal hit **with the matched
  line content — i.e. the private literal itself**. Both shapes match the
  `^  (/|!)` filter. Flag messages also carry 80–100 char excerpts of real
  memory content (`cut -c1-100` trace lines, `cut -c1-80` duplicated
  passages).
- **Why it matters:** The one scenario where a real private literal has
  demonstrably entered a public repo is exactly when this validator would
  copy that literal into its own terminal output and HTML report. The
  report's scrubbing (`scrub_transcript`) only redacts emails and `$HOME` —
  a leaked API key, SSN, or figure passes through untouched. This is the
  sharpest "validator amplifies the leak" shape in the repo. (Contrast:
  the skill's own B2/B3 denylist check correctly prints **filenames only** —
  `bin/leakage-audit:655-666`.)
- **Remediation:** In suite C, never republish memory-audit evidence
  verbatim: emit section headers + counts only (e.g. "memory-audit: 3
  flagged lines in sections 2, 8 — see the tool's own output locally").
  Upstream (memory skill): check #8 should print `file:line-number` only,
  never matched line content.

### P1-2. D1 "secrets written to memory" is cataloged PROTECTED but never exercised by any test

- **Where:** `references/attack-surface.md` §D1 ("Conclusion: PROTECTED (at
  write time)" via `bin/memory-guard` pre-write scan);
  `references/test-matrix.md` §D1 row; `bin/leakage-audit` suite C.
- **What:** The audit's only memory-skill check is the opt-in
  `memory-audit` (a *post-hoc scan* of existing memory — a different
  binary). Nothing in `bin/leakage-audit` or `bin/adversarial-run` ever
  fires a synthetic secret/figure/clean payload at the target's
  `bin/memory-guard` (the pre-write hook D1's verdict rests on) — not
  against the stub, and not against the real installation either.
  Test-matrix D1 admits "not harness-verified where CI runs," but the gap
  is wider: it is not harness-verified *anywhere*.
- **Why it matters:** A catalog verdict of PROTECTED with zero
  contract-shaped probes is an asserted guarantee, not a validated one —
  the exact failure mode this skill exists to prevent ("a path with no
  scenario is an unexamined path" applies equally to a scenario with no
  test). If `memory-guard` regressed (pattern rot, hook unwired), every
  suite would still report CLEAN.
- **Remediation:** Add suite-C red-team cases piping the synthetic
  secret/figure/clean fixtures through `$MEM_SKILL/bin/memory-guard`
  (expect block / flag-for-review / allow per its contract). The stub
  ships no `memory-guard` → emit a pinned, labeled skip there ("stub ships
  no memory-guard; D1 is mandate-only for stub runs"), so the gap is
  explicit rather than invisible.

### P2-1. Suite D republishes real gate-log contexts into reports; scrubbing covers only emails and $HOME

- **Where:** `bin/leakage-audit:690-706` (prints last 5 `| BLOCKED$` and
  `| approved-override$` lines verbatim via `wdetail`); context formats in
  the gates under test: `personal-memory-system/bin/shims/hatch_gws_cli:86`
  (`--context "gmail $sub to ${to:-unknown}"` — the **real recipient
  address**) and `personal-memory-system/bin/brief-gate:32`
  (`--context "brief:$TASK"` — free-form agent-written task text);
  `bin/leakage-report` `scrub_transcript` (EMAIL_RE + `$HOME` only).
- **What:** On a real installation, suite D copies real gate-log lines —
  recipient addresses and brief task descriptions (names, topics, figures
  possible) — into the audit output and the HTML report's raw transcript.
  Emails are redacted in the HTML, but names, figures, topics, and
  non-email identifiers are not, and the terminal/`tee`'d markdown output
  is not scrubbed at all.
- **Why it matters:** The HTML report is the shareable artifact
  ("mobile-friendly," CI-uploaded), and its footer claims "nothing real
  was sent or disclosed" — false whenever suite D ran against a real log.
  Brief task descriptions are the highest-risk field: unlike recipient
  emails they are never scrubbed.
- **Remediation:** In suite D, strip contexts to channel-only (print
  timestamp + verdict, not the context string), or redact contexts through
  the gate before display. Make the report footer conditional on suite D
  having run against a synthetic/empty log. Fix the terminal path too or
  document that `tee`'d reports are for local eyes only.

### P2-2. The interface contract under-specifies undecodable raw-MIME payloads; stub and real shim disagree

- **Where:** `references/gate-interface.md:89` ("the MIME is base64-decoded
  and gated before delegation" — no rule for undecodable input);
  `test/stub-memory-skill/bin/shims/hatch_gws_cli:160-197` (malformed
  JSON / bad base64 → **refuse, exit 1**, fail closed);
  `personal-memory-system/bin/shims/hatch_gws_cli:127-140` (on JSON
  failure: `sys.stdout.write(p); sys.exit(0)` — gates the **opaque,
  still-encoded bytes as if they were content** and proceeds to delegate).
- **What:** The contract's A4 "PROTECTED (single encoding layer)" claim is
  validated only against the stub's strict fail-closed behavior. The real
  shim's fallback gates undecodable bytes (where secret shapes cannot
  match by construction) and then sends them. In practice the Gmail API
  will reject garbage, so exploitability is low — but the two
  implementations of the same contract embody opposite policies, and the
  audit has no case covering the divergence.
- **Remediation:** Pin "undecodable `raw` → refuse (never gate opaque
  bytes)" in `gate-interface.md`; align the real shim with the stub;
  add an audit case (malformed JSON, bad base64 → expect rc=1) that runs
  against every target.

### P2-3. The `.egress-allowlist` exemption path (E1/E3) is never exercised

- **Where:** `references/attack-surface.md` §E1/E3 (exemption "lives in the
  installation's `.egress-allowlist`"); `references/test-matrix.md` §C
  claims E1 covered by "public-number allowlist"; `bin/leakage-audit`
  (the word "allowlist" appears only in a suggestion string, line 417).
- **What:** No check verifies the gate actually honors the allowlist. If
  the real gate ignored it, user-ruled-public literals would be
  over-gated forever — the approval-fatigue risk E1 exists to prevent —
  with no failing check. Test-matrix claims coverage that does not exist.
- **Remediation:** Add a check that a synthetic allowlisted literal exits
  0/2-as-configured (ship a synthetic allowlist fixture for the target, or
  document a pinned skip when the target declares none). Correct the
  test-matrix row until the check exists.

### P2-4. Contract-gated paths `gmail +forward` and messenger `edit` have zero red-team coverage

- **Where:** `bin/leakage-audit` suite B (tests `+send`, `+reply`, never
  `+forward`; messenger `send`, never `edit`); `references/gate-interface.md`
  lists both as gated; `references/test-matrix.md` §B table likewise omits
  them (its T-B11 claims "all send subcommands covered, not just `+send`"
  — inaccurate while `+forward` is untested).
- **Why it matters:** A forward of an inbound email carrying a secret, or
  a message edit inserting one, are realistic exfiltration shapes; an
  argument-parsing bug specific to those subcommands would be invisible.
- **Remediation:** Add `send_expect` cases: secret body via `+forward` →
  blocked; secret via messenger `edit` → blocked; clean edit → allowed
  with byte-identical replay. Fix the T-B11 wording.

### P2-5. The B2/B3 denylist scan is never tested in CI

- **Where:** `bin/leakage-audit:650-668`; `.github/workflows/validate.yml`
  "Assert the pinned CI skip set" (expects `no egress denylist` as one of
  exactly 4 skips).
- **What:** The public-repo leak backstop — the `mktemp` denylist flow,
  `git ls-files -z | xargs -0 grep -lF`, filename-only reporting — runs
  only on the owner's machine. CI pins its absence, so rot in this code
  path (e.g. the `xargs` stdin-hang edge in P3-5, a broken `-z` split)
  would never be caught where the repo is actually built.
- **Remediation:** Add a CI step that creates a *synthetic* denylist and a
  scratch worktree (or temp copy) with a planted synthetic literal,
  runs the scan logic, and asserts (a) detection, (b) only filenames —
  never literal content — appear in output.

### P2-6. Live-fire safety guards have no CI coverage

- **Where:** `bin/leakage-audit:103-140` (stub-target refusal, non-TTY/`$CI`
  refusal, `local.env`-sourced opt-in ignored, stale `MOCHI_REAL_*`
  unset); `.github/workflows/validate.yml` (refuses live-fire variables
  outright, so these paths never execute in CI).
- **What:** The highest-risk logic in the repo — the guards that stand
  between a flag and real sends — is verified only manually (I verified
  the stub refusal and the local.env ignore by execution this review; the
  non-TTY refusal and stale-override unset were not re-verified here).
- **Remediation:** Add safe CI steps asserting exit 2 for: live-fire vs
  stub target; live-fire with stdin non-TTY and no
  `MOCHI_LIVE_FIRE_NONINTERACTIVE`; `local.env`-sourced live-fire ignored.
  None of these can send anything.

### P2-7. Gate-decision logging (a contract requirement) is never verified

- **Where:** `references/gate-interface.md` ("Logs every decision
  (timestamp, context, verdict) to `$MOCHI_EGRESS_LOG`");
  `bin/leakage-audit:148` (exports `MOCHI_EGRESS_LOG="$T/gate.log"` but
  never asserts the file grew); stub `bin/egress-gate` / `bin/brief-gate`
  (no logging at all).
- **What:** Three-way gap: the contract requires logging, the stub doesn't
  implement it, the audit doesn't check it. A gate that silently stopped
  logging would break suite D's "proves the gate is exercised, not
  bypassed" claim with every check still green.
- **Remediation:** After a blocked send in suite B, assert the temp gate
  log contains the verdict line. Either make the stub log (preferred —
  then the assertion runs everywhere) or document the deviation and pin a
  stub-only skip.

### P2-8. Git history is not scanned; the residual is acknowledged elsewhere but missing from the catalog

- **Where:** `bin/leakage-audit:655-666` (`git ls-files` = working tree
  only); `.github/workflows/validate.yml` header comment ("public history
  contains older private values"); `ITERATIONS.md` iteration-2 note
  ("pre-purge private values remain in public history around `918e243` —
  no rewrite without the owner's decision").
- **What:** The B2/B3 check's pass message ("no denylisted literals in
  public repo tracked files") is honestly worded, but anyone cloning the
  public repo gets full history including the pre-purge values. The
  residual is real, documented in two places — yet absent from
  `references/attack-surface.md`'s residual summary and suite E, the two
  places the project promises "every residual is reported, never silent."
- **Remediation:** Either extend the check to `git rev-list --all`
  (printing filenames only, never content), or add the history residual
  explicitly to attack-surface.md and suite E with the owner's
  no-rewrite decision recorded.

### P3-1. Report mislabels local timestamps as UTC

- **Where:** `bin/leakage-report:241` (`fmt_ts` does
  `.replace(tzinfo=timezone.utc)` on the audit's timestamp);
  `bin/leakage-audit` prints `date '+%Y-%m-%d %H:%M %Z'` — **local** time.
- **What:** On a non-UTC machine (the owner's is America/Los_Angeles), the
  report converts a PT timestamp as if it were UTC and displays a wrong
  local time on a security report (verified by code trace; this machine is
  UTC so the shipped sample report is coincidentally correct).
- **Remediation:** Parse the `%Z`/offset the audit already prints, or drop
  the conversion and display the timestamp verbatim.

### P3-2. Suite D's "gate log reviewed" check can never fail

- **Where:** `bin/leakage-audit:706` (`ok "gate log reviewed"` —
  unconditional after printing tails).
- **What:** A human-process step (eyeball the overrides) wearing a
  check's clothes inflates the CLEAN pass count; a log full of
  `approved-override` entries still yields a green check.
- **Remediation:** Make it informational (no pass/fail), or assert
  something mechanical (log non-empty, most recent decision within N
  days) and leave the judgment to the human.

### P3-3. README implies gate-log contexts are synthetic

- **Where:** `README.md` §D table, T-D1: "log lines ending `| BLOCKED`
  listed (synthetic contexts like `leakage-audit:…`)".
- **What:** On a real installation contexts are recipient addresses and
  brief task descriptions (see P2-1), not synthetic. A reader could
  conclude suite D output is safe to share.
- **Remediation:** Reword to state contexts are real log data on real
  installations and the output should be treated accordingly.

### P3-4. Audit SHAPES and stub STUB_SECRET_CAND maintained in parallel by comment only

- **Where:** `bin/leakage-audit:672-677` ("Aligned with the stub's
  candidate shapes…"); `test/stub-memory-skill/bin/patterns.sh`.
- **What:** Two hand-synced EREs; if the stub's widens without the
  audit's, a fixture token could be block-tier yet invisible to the
  purity check (fail-closed direction: it would *pass* purity while being
  a real block token — the purity guarantee silently narrows).
- **Remediation:** CI cross-check: extract both patterns, compare match
  sets over fixtures + corpus, fail on divergence.

### P3-5. `xargs -0 grep` without `--no-run-if-empty`

- **Where:** `bin/leakage-audit:658`.
- **What:** With an empty file list, `xargs` runs `grep -lF` with no file
  operands → grep reads the audit's stdin → hang. Unreachable in practice
  (both repos are non-empty), but a one-flag fix.
- **Remediation:** Add `xargs -0 -r`.

### P3-6. CI skip-set assertion uses unanchored substring matching

- **Where:** `.github/workflows/validate.yml`, "Assert the pinned CI skip
  set" (`grep -q "$reason"`).
- **What:** A future skip reason containing a pinned reason as a substring
  would false-pass the assertion.
- **Remediation:** Anchor to the sentinel format
  (`^@@@ CHECK SKIP <reason> \[`).

### P3-7. `local.env` sourced under `set -u`

- **Where:** `bin/leakage-audit:49` (`[ -f "$SKILL_DIR/local.env" ] &&
  . "$SKILL_DIR/local.env"` with `set -u` active).
- **What:** A `local.env` referencing an unset variable aborts the entire
  audit (exit 2, "refused") — a config typo becomes a total validation
  outage, and the failure mode looks like a safety refusal.
- **Remediation:** `set +u` around the sourcing, or validate-and-warn.

### P3-8. Untested contract surface: `--approved` flag, `--dry-run`, `--json` form, gate stdin form

- **Where:** `references/gate-interface.md` lists `--approved`,
  `--draft`/`--dry-run`, `--params`/`--json`, and stdin invocation for
  `memory-egress-check`; suite B covers env-approval, `--draft`,
  `--params` only.
- **Remediation:** Add cases: `--approved` flag downgrades review-tier
  (and not block-tier); `--dry-run` with secret passes through;
  `--json=` raw form gated like `--params`; direct stdin invocation of
  `egress-gate`/`memory-egress-check`.

### P3-9. Stub README "Using it" mixes working directories

- **Where:** `test/stub-memory-skill/README.md` ("Using it": sets
  `PERSONAL_MEMORY_SKILL="$PWD"` "from this directory," then runs
  `bin/leakage-audit` "from the muse-leakage-guard repo root" — `$PWD`
  changes between the two).
- **Remediation:** Use absolute paths or reorder the steps.

## Strengths (privacy-positive, verified where noted)

- **Fixture purity is real:** all secret-shaped tokens in fixtures/corpus
  are declared synthetic in `SYNTHETIC.txt`, enforced by a fail-closed
  audit check (verified: passes).
- **Invocation sentinels, not stdout scraping:** blocked-send assertions
  rest on sentinel files the fake binary touches; argv is sha256-hashed,
  never echoed — failure evidence cannot carry fixture content.
- **Report hygiene:** email redaction, domain-only identity comparison,
  argv-hash evidence, stub banner + page title + footer, atomic writes,
  exit 3 on unparseable output, UNKNOWN-never-SIMULATED.
- **Live-fire guards verified by execution:** stub-target refusal (exit
  2), `local.env`-sourced opt-in ignored with warning.
- **Denylist scan prints filenames only** — the one place the design gets
  literal-handling right (which makes P1-1's verbatim republication next
  to it more conspicuous).
- **Residuals re-reported every run** (suite E) rather than silently
  accepted.

## Counts

- P0: 0 · **P1: 2** · **P2: 8** · **P3: 9** — 19 findings total.
- 5 confirmed by execution (audit CLEAN 66/0/2, adversarial 36/36,
  live-fire refusals ×2, fixture purity); remainder static analysis
  grounded in the cited file/line.

## Recommended follow-ups for the parent

1. P1-1 and P2-1 both concern the validator republishing real data —
   consider one fix pass over "what the audit/report may print" (suite C
   memory-audit evidence, suite D contexts, footer claim).
2. P1-2 (memory-guard never tested) is the largest validation-coverage
   hole; it undercuts the D1 PROTECTED verdict the catalog advertises.
3. P2-5/P2-6 (CI never exercises the denylist scan or the live-fire
   guards) are cheap, safe CI additions with no send risk.
4. No private data was created, copied, or reproduced in this review; the
  only real-data-adjacent file touched was `local.env`, restored
  byte-identical (verified via `git status`: no tracked modifications).
