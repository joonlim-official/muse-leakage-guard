# Iteration-9 review — Open-source community maintainer
**Reviewer lens:** open-source readiness — README accuracy, CONTRIBUTING quickstart verbatim-runnability, SECURITY.md presence, issue/PR templates, FP/FN reporting flow, license clarity, contributor experience, CI friendliness.
**Repo:** `~/workspace/skills/muse-leakage-guard` @ `e35c1bc` ("Iteration 8: report integrity and readability"), not pushed.
**Date:** 2026-09-17
**Method:** read every doc and script end-to-end; ran the README quickstart, the CONTRIBUTING quickstart, `bin/leakage-audit`, `bin/adversarial-run`, and `bin/leakage-report --out /tmp/...` in simulated mode with synthetic payloads only (no live-fire, no network sends, no real data). Verified `-h` outputs, the live-fire-vs-stub refusal, and suite D against an empty gate log. No files in the repo were modified; nothing was committed or pushed.

**Marker:** findings tagged **[EXEC]** were confirmed by running the code; **[STATIC]** come from reading code/docs.

**What I verified works (honesty wins):**
- README quickstart is verbatim-runnable: `bin/leakage-audit` → exit 0 (67 passed, 1 skipped), `bin/adversarial-run` → exit 0 (36/36 matched), `bin/leakage-report --out /tmp/leak-report.html` → exit 0. **[EXEC]**
- Live-fire refused against the stub (`MOCHI_LIVE_FIRE=1 … bin/leakage-audit` → exit 2) — the E2 labeling/refusal story holds. **[EXEC]**
- HTML report carries `SYNTHETIC STUB TARGET` banner and `<title>Leakage validation — CLEAN (synthetic stub)</title>`; the adversarial card says "36 author-designed test cases — not a real-world sample, and not ML recall/precision" and "This figure measures the harness against the stub, not real detector quality." Card B is tri-state (blocked outright / needs approval / allowed). The honesty architecture from iterations 3–8 is real, not aspirational. **[EXEC]**
- The audit exports `MOCHI_EGRESS_LOG` to a temp dir for validation traffic (`bin/leakage-audit:394`) — validation runs don't pollute the operator's real gate log. (Iter-8 review finding 12 does not reproduce on this HEAD.) **[STATIC]**
- License: MIT, `Copyright (c) 2026 Joon Lim`, with a README License section. `local.env` gitignored with `local.env.example`. CI workflow is well-shaped (`pull_request` not `pull_request_target`, `contents: read`, SHA-pinned actions, shallow checkout, no secrets, live-fire variables refused). **[STATIC]**

---

## Findings (ranked by severity)

### P1-1. No SECURITY.md — no responsible-disclosure path in a security-adjacent public repo [STATIC]
**Where:** repo root (absent); `.github/` contains only `workflows/validate.yml` and `CODEOWNERS`.
**What:** This skill audits leakage protection and deliberately ships key-shaped values in `bin/adversarial-corpus.txt`. If someone finds a real bypass — in the harness or in the gates it audits — the only channel is an untemplated public GitHub issue, which is exactly where a bypass report should *not* go. (Carried over from the iter-8 OSS review; still unaddressed.)
**Why it matters:** For a security-validation tool, the disclosure path is part of the product. A bypass reported as a public issue is itself a disclosure incident.
**Remediation:** Add `SECURITY.md`: who to contact (private channel), what counts as in-scope (harness bugs that misreport verdicts, shim/gate bypasses, fixture-purity failures, stub-vs-real confusion), the corpus's synthetic-shapes policy (currently only in a file-header comment), and a safe-harbor note for good-faith testing.

### P1-2. No issue/PR templates; no false-positive/false-negative reporting flow anywhere [STATIC]
**Where:** `.github/` (absent); `CONTRIBUTING.md`; `README.md`.
**What:** No `.github/ISSUE_TEMPLATE/`, no `PULL_REQUEST_TEMPLATE.md`. The repo *knows* verdict quality is its core risk (E3 bare-9-digit conservative default; corpus `phone_bare10`/`clean_price` "expects X by design"; test-matrix mentions "adversarial-run false-positive traps") — yet a contributor who finds a new FP, a missed block-tier shape, or an unexpected `rc` has no documented channel: no CONTRIBUTING section, no README mention, no template fields (payload shape, gate, want-vs-got, synthetic-only confirmation, minimal repro, proposed corpus case name). (Carried over from iter-8; still unaddressed.)
**Why it matters:** For an audit tool, the verdict-feedback loop is the most important community interaction. Undocumented, it arrives as confused free-text issues or not at all.
**Remediation:** Add `detection-issue.yml` / `false-positive.yml` issue forms (name, `want_rc` vs `got_rc`, gate binary, minimal synthetic payload, "I confirm this payload is synthetic" checkbox, proposed corpus case name) and a PR template that references the existing PR checklist in CONTRIBUTING.md.

### P1-3. CONTRIBUTING.md quickstart is NOT verbatim copy-paste runnable [EXEC]
**Where:** `CONTRIBUTING.md:19-33` (the fenced block under "## Quickstart (stub-first, no private setup)").
**What:** Step 2 is a *comment*, not a command — the inert-delegate creation block exists only in the README quickstart. Running the CONTRIBUTING block exactly, in a fresh shell, yields:
```
✗ [A] real hatch_gws_cli not found on PATH — shim has nothing to delegate to
✗ [A] real hatch_messenger_cli not found on PATH — shim has nothing to delegate to
→ VERDICT: ATTENTION — 2 finding(s) need review. (exit 1, not CLEAN)
```
(Carried over from iter-8; re-verified at this HEAD.)
**Why it matters:** CONTRIBUTING is the contributor funnel's front door. A newcomer's first run failing — with the failure *blaming their setup* rather than the doc — burns trust in the tool whose job is trust.
**Remediation:** Make CONTRIBUTING the single canonical quickstart: include the inert-delegate block verbatim (same as README's), have the README link to it. While there, fix the comment's "it is never invoked with real data in simulated mode" — the delegate **is** invoked for allowed sends (T-B10 approval-tier send, T-B17 pass-throughs); its point is that it's an inert *sink*, not that it's never called. A newcomer who points the delegate at their real CLI misunderstands the safety model.

---

### P2-1. `gmail +forward` has no red-team test — a contract-covered path the audit never fires [STATIC]
**Where:** `test/stub-memory-skill/bin/shims/hatch_gws_cli:84` handles `+send|+reply|+forward`; `bin/leakage-audit` suite B never invokes `+forward` (verified: zero occurrences).
**What:** The shim interception contract (`references/gate-interface.md`) requires subject/body/to of `+send`, `+reply`, **and** `+forward` to pass `egress-gate`. Suite B tests `+send` (secret/figure/draft/token-confusion) and `+reply` (SSN) — but not a single `+forward`. The README's T-B11 row even says "all send subcommands covered, not just `+send`" while `+forward` is uncovered.
**Why it matters:** A regression in the shim's `+forward` routing (e.g. a case-pattern edit that drops it) would pass the audit silently — and forwarding is a classic exfiltration primitive (forward a thread containing secrets to an outside address).
**Remediation:** Add `send_expect "gmail +forward secret blocked" 1 0 -- $G gmail +forward --message-id x --body "$(cat "$FIX/secret.txt")"` (and a clean-pass case), plus the row in `references/test-matrix.md` section B.

### P2-2. Messenger `edit` has no red-team test, though A6 claims "send/edit" verified [STATIC]
**Where:** `test/stub-memory-skill/bin/shims/hatch_messenger_cli:44` handles `send|edit`; `bin/leakage-audit` suite B only ever invokes `send` (zero `edit` invocations); `references/test-matrix.md` row A6 says "Covered by: B: messenger send secret blocked…" with no edit row; `references/attack-surface.md` A6's conclusion is "PROTECTED / APPROVAL-GATED" for "send or edits".
**What:** Same shape as P2-1: the contract covers `edit`, the shim implements it, the catalog claims it verified, the audit never exercises it. Editing an already-sent message is a quiet way to plant private content after the fact.
**Remediation:** Add `send_expect "messenger edit secret blocked" 1 0 -- $M edit --cid '999' --text-stdin < "$FIX/secret2.txt"` (and clean-pass), plus the test-matrix row.

### P2-3. Suite D passes on an empty gate log — but test-matrix claims D proves "the gate is actually being exercised, not bypassed" [EXEC]
**Where:** `bin/leakage-audit:690-706`; `references/test-matrix.md:76`.
**What:** With `MOCHI_EGRESS_LOG` pointing at an empty file, suite D prints "0 gate decisions logged" then `✓ gate log reviewed` — D: 1 passed · 0 failed · 0 skipped. An installation whose gates were *never invoked in real operation* (e.g. every cron worker bypassing the shim — the exact A7 scenario) renders the identical green check as a heavily-exercised gate. The check's own "Proves" statement ("the gate is actually being exercised, not bypassed") is stronger than what it verifies.
**Why it matters:** This is the audit's "is anyone actually using the protection" sensor, and it cannot distinguish "deployed and working" from "deployed and bypassed". A green D on a zero-decision log is the most misleading green in the report.
**Remediation:** Split the check: (a) log exists and is parseable → pass; (b) if the log exists but has zero decisions, emit a distinct `CHECK WARN`/skip with an explicit callout ("gate log is empty — the gate has not been exercised in real operation; verify the shim PATH is actually wired") rather than a ✓. Update the test-matrix "Proves" cell to say what it now proves.

### P2-4. The gate logging contract is specified but verified by nothing; the stub doesn't implement it [STATIC]
**Where:** `references/gate-interface.md:55-56` ("Logs every decision (timestamp, context, verdict) to `$MOCHI_EGRESS_LOG`"); `test/stub-memory-skill/bin/egress-gate` (33 lines, zero log writes — confirmed by reading); no check in `bin/leakage-audit` asserts any log write.
**What:** Logging is in the v1 interface contract, yet: the stub — the thing CI validates against — never logs, and no audit check asserts that a run produced log lines. Suite D only *reviews* a pre-existing log; in simulated mode the audit diverts `MOCHI_EGRESS_LOG` to a temp file (`bin/leakage-audit:394`), so a target that logs correctly would leave evidence the audit could assert on — but nothing does.
**Why it matters:** The audit-log review (suite D) is a headline feature ("recent gate decisions are summarized; approval overrides surfaced"). If a real gate regresses to not logging, suite D silently degrades to "log not found → skip" and the operator loses their highest-risk-event sensor (approved-override review) with no finding.
**Remediation:** Either (a) add a suite-B check in simulated mode: after the send tests, assert the temp gate log is non-empty and contains a `BLOCKED` line (the contract's machine-readable verdict vocabulary) — and make the stub gate log its decisions so CI exercises it; or (b) move logging out of the interface contract into a documented SHOULD. Option (a) is stronger and matches the contract's current MUST language.

### P2-5. SKILL.md claims `bin/leakage-audit -h` "prints usage" — it prints a tagline [EXEC]
**Where:** `SKILL.md:65`.
**What:** `bin/leakage-audit -h` prints one line ("leakage-audit: validate a private-memory leakage protection installation.") plus a blank line — the `sed -n '2,/^#$/p'` range ends at the first lone-`#`, so Usage/Exit/Config never print. `bin/leakage-report -h` prints 4 lines (first paragraph only, no usage/exit codes); `bin/adversarial-run -h` prints 1 line. (Carried over from iter-8; re-verified.)
**Why it matters:** For tools whose exits are nuanced (0/1/2/3, gate-rc vs runner-exit), `-h` is the first thing a newcomer probes. The skill file — the agent-facing entry point — misdescribes it.
**Remediation:** Extend the `-h` range to the full header block in all three scripts (or at minimum Usage + Exit lines), or stop claiming it prints usage. Doing the former also softens P3-5.

### P2-6. Stub README "Using it" block is CWD-confused and lacks the delegate command [STATIC]
**Where:** `test/stub-memory-skill/README.md:43-51`.
**What:** The block exports from the stub directory (`PERSONAL_MEMORY_SKILL="$PWD"  # from this directory`) but then runs `bin/leakage-audit   # from the muse-leakage-guard repo root` — executed as-is from the stub dir it fails with `bin/leakage-audit: no such file or directory`. It also repeats the "needs a second executable CLI" comment with no command (same disease as P1-3). (Carried over from iter-8.)
**Why it matters:** A contributor exploring the stub — the most likely entry point for someone adapting the harness — gets a broken block.
**Remediation:** Fold into the canonical CONTRIBUTING quickstart (per P1-3 remediation); the stub README should link to it, not carry a divergent copy.

### P2-7. Adversarial corpus is thin: 36 single-line cases, no evasion/obfuscation variants [STATIC]
**Where:** `bin/adversarial-corpus.txt` (48 lines, 36 cases).
**What:** Every case is a single line with the payload in canonical form. Missing: whitespace-split secrets ("sk- abcdef…"), zero-width / homoglyph tricks, case variants (`API_KEY=`, `Password:`), multi-line payloads, payloads mixing tiers (secret + figure — worst-wins logic), secrets adjacent to punctuation the extractor might miss, and the classic "secret split across MIME parts" shapes the README already admits are a known gap. The header's "deliberately shortened below hosting-platform secret-scanner thresholds" is good hygiene, but nothing documents the corpus's *coverage philosophy* — what evasion classes it intends to cover vs. explicitly excludes.
**Why it matters:** `bin/adversarial-run` is the "detection-performance" half of validation. A regression set with no adversarial transforms in it undersells the runner's name; a contributor adding a real detector improvement has no evasion cases to guard against regressions.
**Remediation:** Add a documented evasion-case section to the corpus (start with whitespace/case/punctuation variants and multi-tier payloads), and a one-paragraph "corpus coverage philosophy" in the corpus header: which evasion classes are in-scope for the corpus vs. declared known gaps (nested MIME, attachments).

### P2-8. Corpus-case proposal procedure is scattered across five places; the "Adding a new exfiltration path" flow never mentions corpus cases [STATIC]
**Where:** `README.md` ("Adding a new exfiltration path", 4 steps), `CONTRIBUTING.md`, `bin/adversarial-corpus.txt` header, `bin/fixtures/SYNTHETIC.txt` header, `test/stub-memory-skill/README.md` ("How the block set is built").
**What:** A new exfiltration path with a detection dimension almost always wants a corpus case, but neither the README's 4-step flow nor CONTRIBUTING's scenario section mentions it. Assembling the procedure requires five documents. (Carried over from iter-8.)
**Remediation:** Add "Proposing a new adversarial corpus case" to CONTRIBUTING (format → declare in `SYNTHETIC.txt` first → rebuild blockset → `--check` → run suite), and reference it from README's "Adding a new exfiltration path" step 3.

---

### P3-1. Raw `@@@` machine sentinels render inside the HTML report's transcripts [EXEC]
**Where:** `bin/leakage-report` transcript rendering; observed in `/tmp/leak-report.html` (`<pre>` blocks contain `@@@ TOTAL 67 0 1`, `@@@ CHECK SKIP …`, `@@@ SUITE …` lines).
**What:** Iteration 8's headline was report readability ("plain language … readable by everyone"). The evidence transcripts still show the machine-sentinel lines the parser already consumed — noise for a human reader, confusing for a newcomer ("what are these @@@ lines?").
**Why it matters:** Minor, but it directly undercuts the iteration's stated goal.
**Remediation:** Strip lines starting with `@@@ ` (plus the trailing space) from the rendered transcripts; keep them in a collapsed "machine log" details block or drop them (the parsed cards already carry the figures).

### P3-2. README's "Exits with the audit's exit code (0 = CLEAN)" is imprecise [STATIC]
**Where:** `README.md:102` ("What a real run reports" section).
**What:** `bin/leakage-report` exits 0 (CLEAN + all adversarial matched), 1 (findings *or* adversarial mismatches — report still written), 2 (refused/usage — no report), 3 (untrustworthy report — no HTML). "Exits with the audit's exit code" is wrong twice over: the exit combines audit + adversarial-run outcomes, and SKILL.md documents the fuller 0/1/2/3 semantics that the README omits.
**Remediation:** Replace with the four-line exit table from SKILL.md's "How to run" (or link to the consolidated table proposed in P3-5).

### P3-3. Contract-covered `--dry-run` and `--json` raw-send forms are untested [STATIC]
**Where:** `references/gate-interface.md` ("`--draft` / `--dry-run` as flags pass through UNGATED"; raw path via "`--params`/`--json`"); `bin/leakage-audit` suite B (zero `dry-run`, zero `--json` occurrences).
**What:** The audit pins `--draft` passthrough (T-B13) but never `--dry-run`; it pins `--params` and stdin raw forms but never `--json`. The stub shim implements both. Ungated-passthrough paths are exactly where a future bypass hides (the T-B19 token-confusion test exists because of this class).
**Remediation:** Add `send_expect "gmail +send --dry-run with secret passes through" 0 1 … --dry-run` and a `--json` raw-send blocked case.

### P3-4. The three residual lists don't enumerate identically [STATIC]
**Where:** `README.md` section E (10 items) vs `references/attack-surface.md` "Residual risk summary" paragraph vs `bin/leakage-audit` suite E (10 items).
**What:** The attack-surface "Residual risk summary" names A8, B2, B4, C3, C4 plus compositional/chunked, out-of-band, and E3 — but omits voice calls, the A7-static-check caveat, and nested-MIME-part encodings, all of which suite E reports every run. Three lists that should be the same list aren't.
**Remediation:** Make `attack-surface.md`'s residual summary the canonical enumeration (it already has per-scenario detail) and have the README + audit derive from it; or add a comment in all three pointing at the canonical one.

### P3-5. Exit codes documented in four places with no consolidated reference; gate-rc 1 (good) vs runner-exit 1 (bad) collide [STATIC]
**Where:** `README.md` (gate rc + "exits with the audit's exit code"), `SKILL.md` (audit/report exits), `bin/leakage-audit` / `bin/adversarial-run` / `bin/leakage-report` headers.
**What:** Gate verdict codes (`0`=clean, `1`=hard block = good outcome, `2`=review refused) share numbers with runner exits (`1`=FAIL = bad outcome). No single table distinguishes the two families; the full picture requires reading three script headers. (Carried over from iter-8.)
**Remediation:** One "Exit codes" section (README or `references/exit-codes.md`) with two tables — *gate verdict codes* vs *runner exit codes* — linked from SKILL.md, CONTRIBUTING, and each script header.

### P3-6. Fixture-recipient convention is undocumented in the public repo [STATIC]
**Where:** nowhere in the repo (the `a@example.com` / cid `'999'` usage in `bin/leakage-audit` suite B).
**What:** The audit's simulated send tests use `a@example.com` and Messenger cid `'999'` as fixture recipients — safe only because nothing is ever sent in simulated mode (asserted via `invoked=0`). The "synthetic recipients are never real send targets" rule lives in private operator notes, not in the repo. A contributor adding a send test could reasonably use a real-looking address.
**Remediation:** One ground-rule line in CONTRIBUTING ("Test sends use `a@example.com` / cid `999` / `415-555-01xx` numbers only — never a real address; simulated mode asserts `invoked=0` on the delegate").

### P3-7. README live-fire one-liner omits the shim-PATH prerequisite [STATIC]
**Where:** `README.md` ("Live-fire mode" section: `MOCHI_LIVE_FIRE=1 MOCHI_TEST_EMAIL=<your own address> bin/leakage-audit`).
**What:** The simulated quickstart stresses PATH ordering; the live-fire one-liner assumes the operator's shell already has it. A fork owner running it verbatim gets the no-delegate suite-A failure instead of a run. (Carried over from iter-8.)
**Remediation:** Cross-reference the PATH setup ("same PATH as the quickstart: shims first") in the live-fire section.

### P3-8. README has no table of contents; ~16KB first-visit document [STATIC]
**Where:** `README.md`.
**What:** First-time visitors land on the scenario catalog and scroll through quickstart → CI → configuration → live-fire → layout → "adding a path" → license with no signposts; the quickstart ends without a pointer to CONTRIBUTING (the only CONTRIBUTING link is buried in the CI section). (Carried over from iter-8.)
**Remediation:** Add a TOC and a one-line "next: read CONTRIBUTING.md to propose a change" at the end of the quickstart.

### P3-9. Two report homes: `hidden_files/reports/` vs `reports/` [STATIC]
**Where:** `bin/leakage-report` default (`hidden_files/reports/`, gitignored) vs `SKILL.md` Usage ("save it with `bin/leakage-audit | tee reports/<date>.md`").
**What:** A contributor following SKILL.md writes audit text to a different place than the report generator writes HTML. Partially improved since iter-8: `reports/.gitkeep` now exists, so the dir is present in fresh clones. (Carried over, downgraded.)
**Remediation:** Pick one canonical location or cross-link them in both docs.

### P3-10. The "95% lower bound" on the adversarial card has no sampling interpretation [STATIC]
**Where:** HTML adversarial card: "Worst case consistent with these results (95% lower bound): block-tier ≥ 0.82 · review-tier ≥ 0.66 · clean ≥ 0.63."
**What:** The corpus is 36 hand-designed regression cases, not i.i.d. draws from a real-world distribution — a binomial confidence bound over it is illustrative, not inferential. The card's adjacent disclaimer ("not a real-world sample, and not ML recall/precision") is honest and well-placed, and "worst case consistent with these results" is a careful plain-language gloss — so this is a nit, not a deception. But a maintainer could still quote "≥ 0.82" as a guarantee.
**Remediation:** Label it explicitly illustrative ("illustrative bound — the corpus is a hand-built regression set, not a random sample") or drop the numbers and keep the plain-language disclaimer.

---

## Status of the iter-8 OSS review's findings at this HEAD
Iteration 8 touched only `CHANGELOG.md`, `README.md` (1 line), `SKILL.md` (1 line), `bin/adversarial-run` (timeout-denominator fix), and `bin/leakage-report`. Accordingly:
- **Still open:** P1-1 (SECURITY.md), P1-2 (templates/FP-FN flow), P1-3 (CONTRIBUTING quickstart), P2-5 (SKILL.md `-h` claim), P2-6 (stub README), P2-8 (corpus-case procedure), P3-5 (exit-code docs), P3-7 (live-fire PATH), P3-8 (TOC), P3-9 (report homes, partially improved — `reports/.gitkeep` now exists).
- **Does not reproduce:** iter-8 finding 12 (quickstart polluting the real gate log) — the audit diverts `MOCHI_EGRESS_LOG` to a temp dir (`bin/leakage-audit:394`).
- **New in this review:** P2-1 (`+forward`), P2-2 (messenger `edit`), P2-3 (empty-log green), P2-4 (logging contract unverified), P2-7 (thin corpus), P3-1 (`@@@` in HTML), P3-2 (report exit wording), P3-3 (`--dry-run`/`--json`), P3-4 (residual-list drift), P3-6 (fixture-recipient convention), P3-10 (lower-bound interpretability).

## Suggested priority for the maintainer
1. P1-3 (CONTRIBUTING quickstart) — the contributor funnel's front door is still broken; fold the three divergent quickstarts into one canonical block while fixing it.
2. P1-1 + P1-2 (SECURITY.md, issue/PR templates with a detection-issue form) — the disclosure and verdict-feedback paths a security-validation tool must have before inviting external contributors.
3. P2-1 + P2-2 + P2-3 + P2-4 — close the audit's own coverage/honesty gaps (`+forward`, `edit`, empty-log green, logging contract). These are the findings that make the *validation* more trustworthy, which is this repo's entire product.
4. P2-7 + P2-8 (corpus depth + proposal procedure) — strengthen the detection-performance half.
5. P3 polish as time allows; P3-1 and P3-2 are cheap and directly serve iteration 8's readability goal.

**Totals: 18 findings — 3 P1, 8 P2, 7 P3.** Of the 12 iter-8 OSS findings, 10 remain open (1 partially improved, 1 does not reproduce); 11 findings are new in this review. Repo left unmodified — all runs in simulated mode against the synthetic stub; nothing committed, pushed, or sent.
