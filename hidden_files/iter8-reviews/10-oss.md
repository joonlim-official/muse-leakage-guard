# Iteration-8 review — Open-source community maintainer
**Reviewer lens:** contributor & newcomer experience · **Repo:** `~/workspace/skills/muse-leakage-guard` @ `2243723` (Iteration 7) · **Date:** 2026-09-17
**Method:** read README as a first-time visitor; ran both quickstarts verbatim in a fresh clone (`/tmp/qs-test/repo`, simulated mode only, synthetic payloads only); checked `.github/`, `CONTRIBUTING.md`, `SECURITY.md` presence, `SKILL.md` claims, and exit-code docs. No files modified.

**What I verified works:** README quickstart is verbatim-runnable — in a fresh clone, `bin/leakage-audit` → `rc=0` (VERDICT: CLEAN, 66 checks, 2 skipped), `bin/adversarial-run` → `rc=0` (36/36 matched, block 19/19 · review 9/9 · clean 8/8), `bin/leakage-report --out /tmp/qs-test/report.html` → `rc=0` with `SYNTHETIC STUB TARGET` banner present. LICENSE (MIT, Joon Lim 2026) exists with a README License section; `local.env` is gitignored with a `local.env.example`; CODEOWNERS pins `bin/`, `test/stub-memory-skill/`, and the three references files.

---

## Findings (ranked by severity)

### 1. HIGH — CONTRIBUTING.md quickstart is NOT verbatim copy-paste runnable (verified failure)
CONTRIBUTING's "Quickstart (stub-first, no private setup)" gives step 2 as a *comment*, not a command:

```bash
export PERSONAL_MEMORY_SKILL="$PWD/test/stub-memory-skill"
export MOCHI_AGENTS_FILE="$PWD/test/stub-memory-skill/AGENTS.md"
export PATH="$PERSONAL_MEMORY_SKILL/bin/shims:$PATH"
# 2. The audit needs a second executable CLI behind each shim on PATH.
#    (In CI these are inert fakes; locally any second executable works —
#    it is never invoked with real data in simulated mode.)
# 3. Run the full loop
bash -n bin/leakage-audit && ... && bin/adversarial-run
bin/leakage-audit          # expect CLEAN
```

Running exactly this in a fresh clone (fresh shell, nothing else on PATH) fails:

```
✗ [A] real hatch_messenger_cli not found on PATH — shim has nothing to delegate to
Suggestion: install the real CLI or extend PATH so the shim has a delegate; a
shim with no delegate breaks every send.
```

→ audit exits **1**, not CLEAN. The inert-delegate creation block exists **only** in the README quickstart (`/tmp/leakage-inertbin` with `printf`+`chmod`); CONTRIBUTING omits it entirely. The brief asked explicitly whether CONTRIBUTING's quickstart is verbatim runnable *including the inert-delegate block* — it is not: the block is absent. Additionally the wording "locally any second executable works — it is never invoked with real data in simulated mode" is misleading: the delegate **is** invoked for allowed sends (e.g. T-B10's approval-tier send, T-B17 pass-throughs); the point of the inert delegate is that it's a safe *sink*, not that it's never called. Newcomers may set the delegate to their real CLI and not understand why.
**Suggested remediation:** make CONTRIBUTING the canonical quickstart, include the inert-delegate block verbatim (same as README's), have the README link to it. Fix the "never invoked" phrasing to "a safe inert sink for allowed sends; it must never send anything."

### 2. HIGH — No SECURITY.md (responsible-disclosure path) in a security-adjacent public repo
There is no `SECURITY.md`, and `.github/` contains only `workflows/validate.yml` and `CODEOWNERS`. This skill audits leakage protection and deliberately ships key-shaped values in `bin/adversarial-corpus.txt` (shortened, synthetic, per the corpus header). If someone finds a real bypass — in the harness or in the gates it audits — the only channel is an untemplated public GitHub issue, which is exactly where a bypass report should *not* go. A `SECURITY.md` is also the natural home for the corpus's synthetic-shapes policy (currently only in a file-header comment) and for stating what counts as in-scope (harness bugs, bypasses of the gates, fixture-purity failures).

### 3. HIGH — No issue/PR templates; no false-positive reporting path anywhere
No `.github/ISSUE_TEMPLATE/`, no `PULL_REQUEST_TEMPLATE.md`. Combined with finding 2, a contributor who discovers a detection problem (new false positive, missed block-tier shape, unexpected `rc`) has no template telling them what to include. The repo *knows* FP risk exists (attack-surface E3 bare 9-digit SSN deliberately conservative; corpus `clean_price` expects `rc=2` by design; `references/test-matrix.md` mentions "adversarial-run false-positive traps"), but there is no documented channel for reporting a *new* FP/FN: no CONTRIBUTING section, no README mention, no template fields (payload shape, gate, want-vs-got, synthetic-only confirmation, minimal repro). For an audit tool whose whole purpose is verdict quality, the verdict-feedback loop is the most important community interaction — and it's undocumented.
**Suggested remediation:** add `false-positive.yml` / `detection-issue.yml` issue forms (name, `want_rc` vs `got_rc`, gate, minimal synthetic payload, confirmation it's synthetic, corpus case name if proposing one) and a PR template referencing the existing PR checklist.

### 4. MEDIUM — Corpus-case proposal methodology is scattered across five places; never a single procedure
To propose a new adversarial case a contributor must assemble: (a) the line format `name|want_rc|content` (only in the corpus file's header comment), (b) the SYNTHETIC.txt declaration-first rule (CONTRIBUTING ground rules), (c) the blockset rebuild + `--check` (stub README "How the block set is built" + PR checklist), (d) design-intent notes like `phone_bare10`/`clean_price` conventions (corpus header comments). Neither README's "Adding a new exfiltration path" (4 steps) nor CONTRIBUTING's "Adding an attack-surface scenario" mentions adding a corpus case at all — even though a new exfiltration path with a gate-verdict dimension almost always wants one. A newcomer adding a path per the documented 4 steps would produce an incomplete contribution.
**Suggested remediation:** add a "Proposing a new adversarial corpus case" section to CONTRIBUTING (format → declare in SYNTHETIC.txt → rebuild blockset → run `--check` → run suite), and reference it from README's "Adding a new exfiltration path" step 3.

### 5. MEDIUM — Exit codes documented in four places with no consolidated reference — and the two "1"s collide
Gate verdict codes and runner exit codes share numbers with opposite valence:
- **Gate rc** (`references/gate-interface.md`): `0`=clean/allowed, **`1`=hard block** (good outcome), `2`=review-tier refused. Stub shims add `127`=no delegate.
- **Runner exits** (`bin/leakage-audit` header): `0`=all pass, **`1`=at least one FAIL** (bad outcome), `2`=usage/refused live-fire. `bin/adversarial-run` header: `0`=all matched, `1`=mismatch, `2`=usage, `3`=runner failed. `bin/leakage-report` header: `0`=CLEAN+matched, `1`=findings, `2`=usage/refused, `3`=untrustworthy report.

A newcomer reading the README's "`rc=1` — blocked" next to "Exit 1 = failures" will reasonably ask whether 1 is good or bad. No single table distinguishes gate-verdict codes from runner exit codes. README documents only gate rc + "exits with the audit's exit code (0 = CLEAN)"; SKILL.md documents audit/report exits but not adversarial-run's; the full picture requires reading three script headers.
**Suggested remediation:** one "Exit codes" reference (README section or `references/exit-codes.md`) with two tables — *gate verdict codes* vs *runner exit codes* — and link it from SKILL.md, CONTRIBUTING, and each script header.

### 6. MEDIUM — SKILL.md has four accuracy gaps against the repo it describes
1. **"`bin/leakage-audit -h` prints usage."** It doesn't. Verified: `-h` prints a one-line tagline + blank line (the `sed -n '2,/^#$/p'` range ends at the first lone-`#` line, so Usage/Exit/Config never print). `bin/leakage-report -h` prints 4 lines (first paragraph only) — no Usage, no exit codes. `bin/adversarial-run -h` prints a single line. For tools whose exits are nuanced (0/1/2/3, see finding 5), the built-in help is the first thing a newcomer probes — and it hides the information. Either extend the `-h` range to the full header or stop claiming it prints usage.
2. **"How to run" omits the stub/inert-delegate/PATH prerequisite.** SKILL.md says `bin/leakage-audit` runs "the full validation against the local installation" — a newcomer following SKILL.md alone hits the exact no-delegate failure from finding 1 (rc=127 from the shim → suite-A FAIL → exit 1). No mention of `PERSONAL_MEMORY_SKILL`, the stub, or inert delegates.
3. **Layout omits** `test/stub-memory-skill/`, `local.env.example`, and `references/gate-interface.md` (the interface contract SKILL.md itself references for live-fire/stub behavior).
4. Minor: CONTRIBUTING says "The audit labels stub targets as `SYNTHETIC STUB`" — the actual audit label is `target-kind: SYNTHETIC STUB` and the report banner is `SYNTHETIC STUB TARGET`. Copy-paste searchers for the quoted string won't find it.

### 7. MEDIUM — Three divergent quickstarts (README / CONTRIBUTING / stub README); only one works
- README: full block with inert delegates — **works verbatim** (verified).
- CONTRIBUTING: missing inert-delegate command — **fails verbatim** (finding 1).
- `test/stub-memory-skill/README.md` "Using it": also says "the audit needs a second executable CLI behind each shim on PATH (CI provisions inert fakes…)" with no command — **fails verbatim**; worse, its block is CWD-confused: it exports from the stub dir (`PERSONAL_MEMORY_SKILL="$PWD"  # from this directory`, `PATH="$PWD/bin/shims:$PATH"` correct there) but then runs `bin/leakage-audit  # from the muse-leakage-guard repo root` — a newcomer running the block as-is from the stub dir gets `bin/leakage-audit: no such file or directory`. The comment acknowledging the two CWDs does not make it copy-paste runnable.
**Suggested remediation:** one canonical quickstart (in CONTRIBUTING), README and stub README link to it verbatim; delete the divergent copies.

### 8. MEDIUM — README has no table of contents; ~16KB first-visit document
The README is a strong document, but a first-time visitor lands on the scenario catalog and must scroll through quickstart → CI → configuration (9-env-var table) → live-fire → layout → "adding a path" → license to find anything. No TOC, no "start here" pointer. The quickstart itself ends without a pointer to CONTRIBUTING — the only CONTRIBUTING link is buried in the CI section ("See `CONTRIBUTING.md` for the contributor workflow"). The natural funnel (clone → run → propose a change) has no signposts. Add a TOC and a one-line "next: read CONTRIBUTING.md to propose a change" at the end of the quickstart.

### 9. LOW — Two report homes: `hidden_files/reports/` vs `reports/`
`bin/leakage-report` defaults to `hidden_files/reports/leakage-validation-<timestamp>.html` (README Layout says so; both are gitignored). But SKILL.md's Usage says: "A report is printed to stdout; save it with `bin/leakage-audit | tee reports/<date>.md`" — pointing at root `reports/`, which exists but is **empty** (no `.gitkeep` despite `.gitignore` carrying a `!reports/.gitkeep` exception, so a fresh clone has no `reports/` dir at all). A contributor following SKILL.md writes to a different place than the report generator does. Pick one canonical location or cross-link them.

### 10. LOW — README live-fire example omits the shim-PATH requirement
`MOCHI_LIVE_FIRE=1 MOCHI_TEST_EMAIL=<your own address> bin/leakage-audit` — the simulated quickstart stresses PATH ordering ("shims FIRST… the inert delegates AFTER"), but the live-fire one-liner assumes the operator's shell already has it. A fork owner running the live-fire line verbatim gets the no-delegate failure instead of a run. Cross-reference the PATH requirement (or note that live-fire requires the same PATH setup as the quickstart).

### 11. LOW — CONTRIBUTING's own commands are not all verbatim-safe
`export PERSONAL_MEMORY_SKILL="$PWD/test/stub-memory-skill"` assumes repo-root CWD; the doc says so only implicitly ("stub-first" heading). Fine on its own, but combined with finding 1 it means the quickstart currently has *zero* fully-working paths documented in CONTRIBUTING. Also the PR checklist's `test/stub-memory-skill/build/build-blockset.sh --check` is repo-root-relative — consistent, good.

### 12. LOW — Stub README oversells the "Using it" block's hermeticity
Even with delegates provided, the stub README's block doesn't set `MOCHI_EGRESS_LOG`, so the audit reads/writes the user's default `~/workspace/memory-sync/egress-gate.log` — for an external contributor that path doesn't exist (audit skips suite D gracefully, verified: "gate log not found" skip), but a contributor pointing at their *own* installation without reading the env table will get their real gate log mixed with synthetic audit traffic. Worth one line in the canonical quickstart.

---

## Deferred-thread notes (from the brief, seen through this lens — not new findings)
- The README's residual list and the corpus's `phone_bare10`/`clean_price` "expects X by design" comments are the existing FP/FN documentation; finding 3 is about the *reporting path* for new ones, not the documentation itself.
- Exit-code discipline (iteration 7) is implemented in the scripts; finding 5 is about *consolidating the docs*, not the implementation.
- `rc=137` / slow-hanging stub variants and timeout asymmetry are covered by `leakage-report`'s `timeout -k 10 600` + `124→exit 3` handling; from a contributor-docs perspective the behavior is documented in the script header but not in the README.

## Suggested priority for the maintainer
1. Fix CONTRIBUTING quickstart verbatim-runnability (finding 1) — it's the contributor funnel's front door and it's broken today.
2. Add SECURITY.md (finding 2) and issue/PR templates with a false-positive/detection-issue form (finding 3).
3. Canonicalize the quickstart (finding 7) and add the corpus-case proposal section (finding 4).
4. Consolidate exit-code docs (finding 5) and fix SKILL.md accuracy (finding 6).
5. README TOC + report-home unification (findings 8–10) as polish.

**Total findings: 12** (3 high, 5 medium, 4 low). Repo left unmodified — `git status` verified clean (only pre-existing untracked `hidden_files/iter*-*` dirs). All test runs used synthetic payloads in simulated mode; nothing in `~/workspace/your_files/` or memory files was touched; `local.env` untouched.
