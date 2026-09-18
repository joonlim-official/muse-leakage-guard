# Iteration-7 review — staff systems engineer (08-systems)

Repo: `~/workspace/skills/muse-leakage-guard`, HEAD `e20a819` ("Iteration 6:
CI fails honest"). Read-only review; no repo files modified. No live-fire
(`MOCHI_LIVE_FIRE` never set); `local.env` read, never touched. All payloads
used in probing were the repo's own synthetic fixtures (shaped, belonging to
nobody); no real private data involved.

Method: full read of `bin/leakage-audit`, `bin/leakage-report`,
`bin/adversarial-run`, `test/stub-memory-skill/bin/*`, the three references,
README, and `.github/workflows/validate.yml` — then **empirical verification
in simulated mode**, which iter6 did not do: I ran the audit and the
adversarial suite against both the synthetic stub and the real installation,
and probed each suspected stub gap by executing the stub directly against
inert delegates. Claims below marked [empirical] were observed, not inferred.

Scope: full repository, unlimited; centered on contract conformance between
the audit and `references/gate-interface.md` (interface version 1).

---

## Parity runs: stub vs real target (simulated mode)

| Run | Audit | Adversarial |
|---|---|---|
| stub (`test/stub-memory-skill`) | 60 passed · 0 failed · 1 skipped, CLEAN | 36/36 (block 19/19 · review 9/9 · clean 8/8) |
| real (`~/workspace/skills/personal-memory-system`) | 60 passed · 0 failed · 1 skipped, CLEAN | 36/36 (block 19/19 · review 9/9 · clean 8/8) |

`diff` of the two audit transcripts: identical except the target header
lines (stub run additionally prints `target-kind: SYNTHETIC STUB`). With
matched configuration the harness cannot distinguish the stub from the real
installation on any check — see N15 for why that non-divergence needs an
explicit documented boundary.

---

## New findings (N11–N19)

### N11 · HIGH — `--draft`/`--dry-run` token-confusion bypass in the stub GWS shim: a standalone token anywhere in argv disables gating

**Evidence [empirical]:**
- `test/stub-memory-skill/bin/shims/hatch_gws_cli` lines 59–63: the
  draft/dry-run scan is `for a in "$@"; do case "$a" in --draft|--dry-run)
  pass_through "$@";; esac` — it matches any argv **token**, including a
  flag *value*. The subject/body/to parser below it (lines 66–82) is never
  consulted.
- Observed: `hatch_gws_cli gmail +send --to a@example.com --subject --draft
  --body <secret-fixture>` → rc=0, inert delegate invoked
  ("inert delegate got: gmail +send …"), secret body never gated. Same for
  the token as the value of an unrelated flag (`--note --draft`).
- `bin/leakage-audit` suite B has zero coverage of this: its only
  `--draft` case is the genuine-flag form (`send_expect "gmail +send
  --draft with secret passes through"`), which passes by design.

**Why it matters:** this is a fail-open bypass in the *reference
implementation* — the file a real-shim author reads to learn the contract.
A caller whose subject is literally `--draft` (or any injected extra token)
skips the gate entirely while the harness reports green. The contract
(`gate-interface.md`: "`--draft` / `--dry-run`: pass through UNGATED")
means the flag form; the stub implements the token form.

**Recommendation:** make the draft scan flag-aware: reuse the prev-state
parser so `--draft`/`--dry-run` are honored only when they appear as flags
(i.e., not as the value of `--subject`/`--body`/`--to`/unknown options).
Add a suite-B case: `+send --subject --draft --body <secret fixture>` must
be blocked (rc=1, delegate uninvoked). Pin both forms in
`references/test-matrix.md` section B.

**Residual if not fixed:** the reference shim teaches a token-confusion
bypass; any shim copied from it inherits an ungated send path the audit
never probes.

---

### N12 · MEDIUM — interface_version declared, still enforced nowhere: enforcement-point design

**Evidence:**
- `references/gate-interface.md` line 1 ("…contract — version 1") and line
  6 ("`.synthetic-stub` declares `interface_version=1`") are prose only;
  `grep -rn interface_version bin/` → no hits (unchanged since iter6 F1).
- `bin/leakage-audit` line 67 tests only the *existence* of
  `.synthetic-stub` (`STUBKIND`); the `interface_version=1` value inside is
  never parsed. Real (non-stub) skills have no defined declaration point at
  all.

**Design (per the brief: one clean verdict, not N per-check FAILs):**
1. Make the contract version machine-readable: add a `contract_version: 1`
   line to `references/gate-interface.md` (next to the H1), and a
   `REQUIRED_INTERFACE_VERSION=1` constant at the top of `bin/leakage-audit`.
2. Define the target declaration point: `.synthetic-stub`
   (`interface_version=N`) for stubs; for real skills, document one
   (`bin/interface-version` file or equivalent marker — the contract must
   name it, since the audit validates *against the contract*).
3. Enforcement lives in **suite A, as the first check** — the single place
   contract conformance is established before any contract-shaped probe
   runs. Read the target's declared version; compare once.
4. Mismatch verdict: exactly one
   `bad("interface version mismatch: target declares N, harness requires
   M — contract checks not meaningful")`; then **skip suites B–F** with
   reason "interface version mismatch" (skip, not fail — the checks were
   not run, and N per-check FAILs would misattribute a version skew as N
   broken gates). Final verdict: `ATTENTION`, exit 1. Missing/unparsable
   declaration → same single FAIL (fail-closed: an undeclared target cannot
   be conformance-checked).
5. CI negative test: temp copy of the stub with `interface_version=99` →
   assert exactly one FAIL, suites B–F skipped, exit 1. `adversarial-run`
   needs no version logic — the audit is the single enforcement point.

**Residual if not fixed:** a target implementing a different (older/newer)
contract version passes today's suite A–E silently, and every check result
is meaningless against the wrong contract.

---

### N13 · MEDIUM — SHAPES should be a manifest, not an inline regex: drift already present

**Evidence:**
- `bin/leakage-audit` line 586: the fixture-purity `SHAPES` ERE is inline,
  with the comment "Aligned with the stub's candidate shapes
  (`test/stub-memory-skill/bin/patterns.sh)". They are not aligned:
  - amex-with-separators `\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b`
    exists in `patterns.sh` (`STUB_SECRET_CAND`) but `SHAPES` has only the
    bare `\b3[47][0-9]{13}\b`;
  - `\b[0-9]{4}([- ]?[0-9]{4}){3}\b` (patterns.sh) vs `[0-9]{4}[- ][0-9]{4}[- ][0-9]{4}[- ][0-9]{4}` (SHAPES, no `\b`).
- Three consumers of "what is a secret-shaped token" — the audit purity
  check, `patterns.sh` (stub extraction), and the corpus expectations —
  are held together by a comment, not a shared definition.

**Recommendation:** replace the inline regex with a manifest, e.g.
`bin/shapes.yaml`: one entry per shape class with `name`, `ere`,
`class` (secret/figure/phone), `rationale` (why this shape is
secret-shaped), and `coverage` (corpus case names + fixture files
exercising it). The audit and the stub both derive their patterns from
it (generate the ERE list at build/run time, or source a shared
`shapes.sh`). The purity check then also gains a coverage assertion: every
manifest class must have ≥1 exercising corpus case, so a shape can never
be declared but untested.

**Residual if not fixed:** the purity check silently under-covers shapes
the stub actually extracts — an undeclared token in a new shape class can
ship in a public fixture while the check reports clean.

---

### N14 · MEDIUM — Catalog numbering collisions; B18/B19 verified absent

**Evidence:**
- `grep -rn "B18\|B19"` over the repo (excluding hidden_files and .git) →
  **no hits**: B18/B19 rows do not exist anywhere. (Noting explicitly since
  the brief listed them as a lead.)
- Two live numbering axes collide on the same prefixes:
  - README "B. Red team" table: B1–B17 (check illustration numbers) vs
    `references/attack-surface.md` "B. Sharing and publishing": B1–B4
    (scenario IDs). README B1 ("api_key → egress-gate blocked") and catalog
    B1 ("Drive file shared externally") are different things.
  - README "E. Known residuals": E1–E4 vs catalog "E. Classification":
    E1–E3. README E1 (browser-task residual) vs catalog E1 (over-gating).
- README's B-table does not map 1:1 onto audit checks: B8 ("all seven
  payloads → brief-gate → 1/1/1/2/2/0/0") conflates the 14 gate checks the
  audit actually runs (7 payloads × 2 gates), and the two approval-isolation
  checks (`send_expect` "…stays blocked with approval", bin/leakage-audit)
  have no README row at all.

**Recommendation:** give the README illustration tables their own ID prefix
(e.g. T-A1, T-B1…) or drop the numbers; keep attack-surface IDs canonical
everywhere (test-matrix section F already uses them). Add the missing
approval-isolation rows; split B8 into the two gate runs the audit
performs.

**Residual if not fixed:** readers (and future reviewers) cite "B12" or
"E1" meaning different checks/scenarios depending on which document they
read — the exact confusion a catalog exists to prevent.

---

### N15 · LOW — Stub/real parity is total, but the intended parity boundary is undocumented

**Evidence:** parity runs above — 60/0/1 and 36/36 identical on both
targets, transcript diff limited to the header. `references/test-matrix.md`
"Target-kind note" says stub runs prove harness self-consistency, not
protection (E2), but nothing states *which* checks are expected to be
target-invariant (plumbing: PATH shadowing, invocation, rc mapping) vs
target-sensitive (detector verdicts on undeclared shapes — where the stub's
fail-closed lookup and a real detector legitimately differ).

**Recommendation:** extend the target-kind note with the intended parity
boundary: identical outcomes are *required* for plumbing checks A/B
(mechanics), *expected but not required* for detector verdicts, where
divergence must be explainable by the target's declared detector
semantics. That turns future divergence into a classified event instead of
an ambiguous one.

**Residual if not fixed:** the next real detector that (correctly) differs
from the stub on an undeclared shape looks like a regression instead of an
expected target-sensitive difference.

---

### N16 · LOW — Report tier-split ignores evidence: failed checks land in "Other evidence"

**Evidence:** `bin/leakage-report` `tri_state_groups` (line 351) regexes
`rc=(\d)` over `c["text"]` only. A failed check's text is `"[B] <name>"`
(no rc); the want/got rc lives in `c["ev"][0]` ("want rc=1, got rc=2 …").
So exactly the checks that matter most — failures — are grouped under
"Other evidence", defeating the stated purpose ("the report never mixes
the two protection tiers in one undifferentiated list").

**Recommendation:** fall back to scanning `c["ev"][0]` for `want rc=(\d)`
when the text has no rc. One-line change in the grouping function.

**Residual if not fixed:** on a red run, the reader must manually
re-associate failures with their tiers.

---

### N17 · LOW — Live-fire `live_send_expect` has no timeout bound

**Evidence:** `bin/leakage-audit` line 430: `live_send_expect` runs
`"$@"` directly. The simulated `send_expect` wraps every invocation in
`timeout -k 10 30`; the live path relies only on `leakage-report`'s outer
600s bound. A hung real CLI hangs the audit mid-suite.

**Recommendation:** apply the same `timeout -k 10 30` wrapper and the
rc=124 fail-closed path as `send_expect`.

**Residual if not fixed:** a wedged real binary turns a live-fire audit
into a 10-minute hang instead of a diagnosed finding.

---

### N18 · LOW — Suite A does not assert stub blockset currency; corpus/adversarial timeout asymmetry

**Evidence:**
- `test/stub-memory-skill/build/build-blockset.sh --check` is enforced in
  CI but `bin/leakage-audit` suite A never runs it. A locally-stale
  `blockset.txt` fails loudly (verdict mismatches), so this is
  defense-in-depth, not a silent hole — but suite A is the natural home
  for "is the target self-consistent".
- `bin/adversarial-run` uses `timeout -k 5 10` while the audit's
  `gate_expect` uses `timeout -k 10 30` over the same gate invocation; a
  gate answering in 10–30s passes the audit and fails the adversarial run
  for slowness.

**Recommendation:** suite A: when `STUBKIND=synthetic-stub`, run
`build-blockset.sh --check` as one check. Align the two timeouts (or
document why they differ).

**Residual if not fixed:** minor; local runs can drift from CI in ways the
audit won't name.

---

### N19 · LOW — Drive `permissions create` matching is position- and context-insensitive

**Evidence:** `test/stub-memory-skill/bin/shims/hatch_gws_cli` drive
branch: refusal triggers when *any* argv token equals `permissions` and
*any* token equals `create` — not when they are the subcommand in
position. `drive files create --name permissions` would be refused
(fail-closed false positive); the matcher also can't see the words inside
a `--params` JSON blob (currently harmless since the subcommand words are
separate tokens, but fragile).

**Recommendation:** match on subcommand position (`$2,$3` after `drive`)
rather than anywhere-tokens.

**Residual if not fixed:** fail-closed friction on odd-but-legitimate
drive invocations; a latent bypass shape if a future CLI nests the words.

---

## Carried forward — iter6/iter5 items re-verified at e20a819 (still open)

Iteration 6 changed only CI/report/adversarial-runner plumbing (see
`git diff --stat 5ff8950 e20a819`: 6 files, none under
`test/stub-memory-skill/`), so every stub-side finding below is
mechanically still open. Re-verified by reading and, where marked, by
execution:

| ID | Status at e20a819 |
|---|---|
| iter6 F1 — interface_version declared, never enforced | OPEN → design delivered as N12 above |
| iter6 N1 — stub GWS shim doesn't gate the stdin form of raw MIME | OPEN [empirical]: piped `{"raw":"<b64url>"}` on stdin → rc=0, delegate invoked, MIME never examined (`hatch_gws_cli` lines 90–99, 128) |
| iter6 N2 — delegate resolution self-exec loop | OPEN [empirical]: `MOCHI_REAL_HATCH_GWS_CLI=<shim itself>` → infinite exec loop (killed by timeout, rc=124); no canonicalization, no self-guard (shim lines 19–27; messenger shim lines 18–26); audit's "distinct executable" assertion (`bin/leakage-audit` line 260) is string-equality on PATH dirs, defeated by symlinked/aliased dir spellings [empirical] |
| iter6 N4 — stub `die()` exits 2 (review-tier) | OPEN [empirical]: `egress-gate --content-file /nonexistent` → rc=2; with `MOCHI_EGRESS_APPROVED=1` → **rc=0 (allow)** — a broken detector is approval-downgradeable to allow (`memory-egress-check` line 31; `egress-gate` lines 21–30) |
| iter6 N5 — gate-logging contract clause never verified; stub gates don't implement it | OPEN: no `MOCHI_EGRESS_LOG` write in stub `egress-gate`/`brief-gate`/`memory-egress-check` (grep: no hits) |
| iter6 N6 — `build-blockset.sh` writes `blockset.txt` non-atomically | OPEN: `cp "$tmp.hashes" "$OUT"` (build-blockset.sh line ~68); write-temp + rename still not used |
| iter6 N7 — stub GWS shim gates subject+body but not `--to` | OPEN: line 80 gates `subject + body` only; contract says "body/to pass egress-gate" |
| iter6 N8 — messenger "byte-identical replay" is relative to gated content | OPEN: replay replays `$tmp` (stdin + `--text` assembled), not original stdin; audit's replay check covers stdin-only |
| iter6 N9 — `--approved` on the shim CLI silently ignored | OPEN: shims never translate `--approved` → env; contract's "(or --approved)" phrasing (exit-code section) vs gate-CLI-only intent still unpinned in `gate-interface.md` |
| iter6 N10 — stub brief-gate conflates usage error with review-tier (exit 2) | OPEN [empirical]: `brief-gate --task t` (no `--brief-file`) → rc=2 with and without approval |

## Closed since iter6

- **iter6 N3 — adversarial-run emitted zero machine sentinels / CI summary
  grepped a dead phrase: FIXED.** `bin/adversarial-run` now emits
  `@@@ ADV MATCHED/TIERS/MISMATCH`; `.github/workflows/validate.yml`
  parses anchored sentinels and pins 4 expected skips from
  `@@@ CHECK SKIP`. (Verified by reading; the workflow was not executed
  here.)

## Spot-verified working (not findings)

- Sentinel forgery hygiene intact: `msent` strips newlines and rewrites
  `@@@` in names/evidence (bin/leakage-audit); report parses sentinels
  first, hardened legacy fallback second.
- Report fail-closed paths intact: unparseable audit → exit 3, no HTML;
  adversarial non-zero with clean audit → badge forced to ATTENTION;
  unknown mode → MODE UNKNOWN bar; suite sequence pinned to A–E.
- Live-fire safety shape intact: refused vs stub (exit 2), stale
  `MOCHI_REAL_*` unset loudly in live-fire, `local.env`-sourced
  `MOCHI_LIVE_FIRE=1` ignored with warning (explicit-env snapshot logic).
- `build-blockset.sh --check` refuses an empty set; current (21 tokens).
- `local.env` present and gitignored; CI refuses a committed one and
  refuses live-fire variables.

---

## Suggested sequencing for the iteration-7 diff

1. **N11** (draft token-confusion) + **N1** (stdin raw MIME): both are
   fail-open/bypass-shaped gaps in the same stub shim file, both need a
   suite-B case each — one probe-shaped fix.
2. **N12** (interface-version enforcement): the contract-conformance keystone;
   single suite-A check + contract doc + CI negative test.
3. **N4 + N10** (`die()`/usage-error exit codes) + contract pin "non-verdict
   errors never reuse 0/1/2": same tier/error-handling area; N4's
   approval-downgrade is the sharp edge.
4. **N13** (SHAPES manifest) + **N18** (blockset currency in suite A):
   fixture/shape integrity, kills the drift class.
5. **N2** (canonicalized delegate + self-guard) + **N14** (numbering) +
   **N15–N17, N19**: robustness and docs; N14 first among docs since every
   future finding cites these IDs.
