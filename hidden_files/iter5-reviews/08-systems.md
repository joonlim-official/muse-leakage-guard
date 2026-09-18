# Iteration-5 review — staff systems engineer (08-systems)

Repo: `~/workspace/skills/muse-leakage-guard`, HEAD `e4b2af1`. Read-only review;
no files modified. Scope: `bin/leakage-audit` (621 lines), `bin/leakage-report`
(518), `bin/adversarial-run` (89), `test/stub-memory-skill/bin/*` (patterns.sh,
memory-egress-check, egress-gate, brief-gate, shims ×2, build/build-blockset.sh),
`references/gate-interface.md`, `.github/workflows/validate.yml`.

Method: full read of all scripts + references, plus a live validation run against
the synthetic stub to ground the performance section (measured, not estimated).
Audit run: 57 checks, 0 failures, 3.4 s wall. Adversarial run: 36/36, 2.1 s wall.

Findings ordered by priority. "Code health" is the top theme; the two brief-required
recommendations (SHAPES manifest, interface versioning) are F1 and F2.

---

## F1 · HIGH — Interface version declared, never validated (the top code-health issue)

**Evidence:** `references/gate-interface.md` (title: "Gate/shim interface contract —
version 1"; "`test/stub-memory-skill/.synthetic-stub` declares
`interface_version=1`"); `test/stub-memory-skill/.synthetic-stub` contains
`kind=synthetic-stub` + `interface_version=1`. `bin/leakage-audit` reads the stub
marker only to set `STUBKIND` (line ~57) — it never reads or compares
`interface_version` anywhere. `grep -n interface_version bin/leakage-audit` → no
hits.

**Why it matters:** when the real skill's interface moves to v2 while the stub (or
the harness's expectations) stay v1, the audit will not say "interface mismatch".
It will run v1-shaped probes against a v2 CLI and report a pile of confusing
per-check FAILs (wrong exit codes, unrecognized flags, parse failures) that look
like a protection regression but are really a contract drift. A versioned contract
that is never checked is a comment, not a contract.

**Recommendation — conformance check for interface versioning:**
1. Make `references/gate-interface.md` the single source: add a machine-readable
   header line `interface_version: 1` at the top (in addition to the prose).
2. Harness-side constant: `bin/leakage-audit` parses the expected version from
   `gate-interface.md` (fail closed if the file lacks the header).
3. Target-side declaration: require every skill under test to declare its version
   — for the stub, the existing `.synthetic-stub` file; for the real skill, a new
   `bin/.interface-version` (plain `1`). New suite-A check reads it.
4. Mismatch behavior: on version mismatch, FAIL the run with a single verdict
   `interface version mismatch: target=v2, harness=v1 — not running contract
   probes` and skip suites B/C (their results would be noise). Missing declaration
   on a non-stub target → warn + continue (legacy tolerance); missing on the stub
   → fail (the stub is harness-owned and must be exact).
5. Version-gated conformance probes: the audit should run a small, version-keyed
   probe set that exercises the contract's MUSTs for the declared version, so a
   silent semantic change inside the same version number is also caught. v1 probes:
   - exit-code table (0/1/2) on known fixtures;
   - `--content-file` vs stdin equivalence for `memory-egress-check`;
   - **approval-override isolation: block-tier payload + `MOCHI_EGRESS_APPROVED=1`
     must still exit 1** (see F3 — currently untested anywhere);
   - shim delegate discovery: no delegate on PATH → exit 127 (fail closed, never
     silently drop), already pinned in gate-interface.md but never probed;
   - gate-log line format `... | BLOCKED|needs-approval|approved-override` (see F6).
6. CI: add a negative test that bumps a copy of the stub to `interface_version=2`
   and asserts the audit refuses with the mismatch verdict.

---

## F2 · HIGH — SHAPES manifest: concrete design (backlog item, specified)

**Evidence of the gap:** the audit's fixture-purity check hardcodes its own shape
regex (`bin/leakage-audit`, the `SHAPES='...ssn...card...sk_live...'` line in suite C,
~line 468), while the stub extracts candidates with a *different* hand-written
regex (`test/stub-memory-skill/bin/patterns.sh`, `STUB_SECRET_CAND`, line ~19 —
whose comment claims it is "a superset of the shapes the audit's fixture-purity
check looks for"). Two regexes, two files, one verbal promise of consistency. The
expected-verdict mapping is likewise triple-sourced: suite B's `gate_expect` list
(hardcoded fixture→rc pairs, ~line 370), `bin/adversarial-corpus.txt`
(`name|want|content`), and `build-blockset.sh` (want=1 extraction, ~line 33).
`build-blockset.sh`'s own comment (~line 13) claims the `--check` mode is "used by
CI and the audit's fixture-purity check" — but `bin/leakage-audit` never calls it
(verified by grep); only `.github/workflows/validate.yml` does. Stale coverage
claims are exactly how manifests rot.

**Recommendation — explicit, versioned manifest.** Add
`references/shapes-manifest.yaml`:

```yaml
manifest_version: 1            # must equal gate-interface interface_version
shapes:
  - id: stripe-secret-key
    tier: block                # block | review | clean
    want_rc: 1
    patterns: ['sk_(live|test)_[A-Za-z0-9]+']
    corpus_cases: [stripe_live, stripe_test]
    fixtures: [secret.txt]
    documented_residuals: []
  - id: phone-bare-10digit
    tier: clean
    want_rc: 0
    patterns: ['\\b[0-9]{10}\\b']
    corpus_cases: [phone_bare10]
    fixtures: []
    documented_residuals: ["collides with confirmation/order numbers — corpus phone_bare10, see attack-surface E1"]
```

Generation/derivation rules (single source, no second hand-written regex):
- The audit's fixture-purity `SHAPES` regex and the stub's `patterns.sh` candidate
  regexes are *generated* from `manifest.patterns` (or the audit runs a
  `--check-manifest` that asserts the checked-in regexes equal the generated ones —
  same mechanism as `build-blockset.sh --check`, which CI already enforces).
- `build-blockset.sh` already derives block-tier tokens from corpus want=1 cases;
  extend it to derive from the manifest (`tier: block` shapes → corpus_cases →
  tokens), keeping its `--check` semantics.

**Where the audit must fail on manifest↔corpus disagreement** (new suite-C checks,
fail closed):
- M1: every `name` in `adversarial-corpus.txt` appears in exactly one shape's
  `corpus_cases`, and every listed case exists in the corpus (both directions).
- M2: for each corpus case, `want` equals its shape's `want_rc`.
- M3: every file in `bin/fixtures/*.txt` is referenced by ≥1 shape; every
  referenced fixture exists and is non-empty (absorbs the current ad-hoc fixture
  loop).
- M4: `manifest_version` equals the gate-interface `interface_version` (ties F2
  to F1 — a contract bump forces a manifest review).
- M5 (real-skill runs): every `tier: block` shape's extracted tokens hash into
  the runtime blockset — i.e., run `build-blockset.sh --check`-equivalent logic
  inside the audit so local runs can't drift silently (today only CI checks it).

---

## F3 · MEDIUM — Contract MUST "approval never unblocks block-tier" is untested

**Evidence:** `references/gate-interface.md`: "It must NEVER turn a block-tier 1
into 0." Suite B tests review-tier approval (`gmail +send figure allowed with
approval`, `drive permissions create allowed with approval`) but has **no** case
for block-tier + `MOCHI_EGRESS_APPROVED=1`. The stub egress-gate
(`test/stub-memory-skill/bin/egress-gate`, ~line 20) happens to check
`RC -eq 1 → exit 1` before the approval branch, so it is correct today — but
nothing would catch a future refactor that reorders the branches.

**Recommendation:** add to suite B:
`send_expect "gmail +send secret still blocked with approval" 1 0 -- env MOCHI_EGRESS_APPROVED=1 $G gmail +send ... --body "$(cat $FIX/secret.txt)"`
and the equivalent for `brief-gate`. This is also v1 conformance probe #3 in F1.

---

## F4 · MEDIUM — Live-fire send path has no timeout (hang not caught everywhere)

**Evidence:** brief asks whether a hanging gate is caught everywhere.
- Simulated suite B: `gate_expect` wraps gates in `timeout 30` (~line 336–338);
  `send_expect` wraps the whole shim invocation in `timeout 30` (~line 360).
- `bin/adversarial-run`: `timeout 10` per case (~line 60) — good.
- Live-fire `live_send_expect` (`bin/leakage-audit`, ~line 410): `out="$("$@" 2>&1)"`
  with **no** `timeout`. A hung gate/shim in live-fire hangs the audit
  indefinitely — unbounded in the most sensitive mode.

**Recommendation:** wrap live-fire invocations in `timeout 60` and treat rc=124 as
a distinct `bad()` ("live-fire send hung — investigate before re-running").
Also probe `command -v timeout` once in suite A and fail closed if missing
(portability: macOS lacks GNU timeout).

---

## F5 · MEDIUM — Vacuous-pass in the scenario coverage map

**Evidence:** `bin/leakage-audit` suite C (~lines 448–458): `map_ids` from
`references/attack-surface.md` headings; if the file has **zero** `### [A-E][0-9].`
headings, `map_ids` is empty, `unmapped` stays empty, and the audit emits
`ok "all 0 attack-surface scenarios mapped in test-matrix.md"`. The audit already
guards the corpus against 0/0 vacuous passes ("adversarial corpus is empty —
0/0 would be a vacuous pass", suite A) but the same class of bug lives one suite
later.

**Recommendation:** after computing `map_count`, `if [ "$map_count" -eq 0 ]; then
bad "no scenarios found in attack-surface.md (vacuous coverage map)" ...; fi`.
Generalize the pattern: any "all N of M mapped" check must fail when M=0.

---

## F6 · MEDIUM-LOW — Suite D parses a gate-log format the contract never pins

**Evidence:** suite D counts verdicts with `grep -c "| $v$"` for
`BLOCKED|needs-approval|approved-override` (~line 490). `references/gate-interface.md`
only says gates "Log every decision (timestamp, context, verdict)" — the
`timestamp | context | verdict` shape and the exact verdict tokens are
convention, not contract. A v2 skill that changes the log format silently breaks
suite D into misleading zeros.

**Recommendation:** pin the log line format in `gate-interface.md` v1
(e.g. `TS | context | verdict`, verdict ∈ {BLOCKED, needs-approval,
approved-override, CLEAN}), and add the format assertion to the v1 conformance
probe set (F1.5). Any format change becomes a versioned interface change.

---

## F7 · LOW — Duplicated shape regexes are drift-prone (load-bearing today)

**Evidence:** `bin/leakage-audit` suite-C `SHAPES` (ssn/card/key alternation) vs
`test/stub-memory-skill/bin/patterns.sh` `STUB_SECRET_CAND` (a longer alternation
adding `api_key=`/`password=`/`passwd=` and bare-digit shapes). The superset claim
lives only in a comment; nothing enforces it. If the audit's regex grows a shape
the stub can't extract, the fixture-purity check passes values the stub's
`build-blockset.sh` can never hash — silent coverage divergence.

**Recommendation:** absorbed by F2 (generate both from the manifest). Until then,
add a CI step asserting every alternation branch in the audit's `SHAPES` appears
in `STUB_SECRET_CAND` (mechanical subset check via a small python script).

---

## F8 · LOW — `adversarial-run` reuses one temp file: serial-only by accident

**Evidence:** `bin/adversarial-run` (~lines 50, 66): single `TMPF="$(mktemp)"`,
each case does `printf '%s' "$content" > "$TMPF"` then invokes the gate on it —
safe only because the loop is serial.

**Recommendation:** before anyone parallelizes (e.g. `xargs -P`), switch to
per-case temp files (`mktemp` inside the loop, or a per-PID temp dir). Add a
comment at the `TMPF` declaration stating the serial assumption. (Do not
parallelize yet — see F9.)

---

## F9 · LOW — Performance: fine today; add a budget before it matters

**Measured (this review, stub target):** audit 3.4 s wall (57 checks), adversarial
2.1 s wall (36 gate invocations). Per-invocation cost is dominated by process
spawn (~50–80 ms per gate call, incl. stub `memory-egress-check`'s per-candidate
`sha256sum`+`grep -qx` subprocess pair, `patterns.sh` ~line 44). Nothing
quadratic; the corpus is intentionally tiny.

**Risks and recommendations:**
1. Worst-case serial timeout exposure: suite B ≈ 29 invocations × 30 s timeout ≈
   **15 min** of hanging before completion; adversarial 36 × 10 s ≈ 6 min. Both
   fit CI's 20-min job timeout but would look like a hang. Add per-suite wall-clock
   timing (print in `end_suite`), warn if the audit exceeds 60 s, and fail with
   "exceeded time budget" past 300 s — bounded CI beats silent hangs.
2. `adversarial-run` is needlessly serial but fast enough; only parallelize after
   F8, and keep the timeout-per-case (parallelism × timeouts is how you get
   thundering-herd CI failures).
3. The denylist scan (`git ls-files -z | xargs -0 grep -lF`, suite C ~line 462)
   re-scans the entire tracked repo on every run — fine at 46 files, but scope it
   to changed files or cache it if the repos grow.
4. Stub `memory-egress-check` spawns two subprocesses per candidate token
   (hash + `grep -qx` lookup, ~line 44); a single-pass `grep -qF -f` against a
   precomputed file would be O(1) processes. Not worth changing at corpus scale —
   noted so a future corpus 10× larger doesn't get "optimized" blindly.

---

## F10 · LOW — Report/adversarial output contract nits

- **Mismatch-name inconsistency:** `bin/adversarial-run` prints TIMEOUT mismatches
  as `MISMATCH <name>:` (colon, ~line 63) but rc mismatches as `MISMATCH <name>`
  (~line 76). `bin/leakage-report`'s findings regex
  (`MISMATCH\s+(\S+)\s+want rc=...`, ~line 66) captures the colon into the case
  name for TIMEOUTs only. Normalize the runner to emit no colon in both.
- **Legacy fallback target line:** `parse_legacy`'s `target: (\S+)` (~line 128)
  captures only the first wrapped fragment of long target paths (the audit folds
  the target line at width 48). Minor fidelity loss in old-output reports only.
- **`send_expect` stdin coupling:** call sites like
  `send_expect ... -- $M send --cid '999' --text-stdin < "$FIX/clean.txt"` rely on
  the `<` redirect applying to `send_expect`'s own stdin, inherited by the inner
  `timeout` call. Works, but a future refactor that redirects inside the function
  breaks every stdin-based case silently. Prefer an explicit `--stdin-file`
  parameter.

---

## What was verified working (not findings)

- Machine sentinels (`@@@`) are the primary report path; the legacy text fallback
  was tested against current output and parses correctly (its format comments
  match the actual 2-space/4-space layout — my initial suspicion of a mismatch
  was wrong; the `1s/^/  /` re-indent in `begin_suite` produces the 4-space
  headers the fallback expects).
- `build-blockset.sh` refuses to write an empty set; `--check` is enforced in CI;
  blockset (21 hashes) is current.
- Timeout coverage exists for simulated suite B and adversarial-run; live-fire is
  the gap (F4).
- `local.env` is gitignored and untracked; CI's "refuse committed local.env"
  step is consistent with the repo state.
- The audit correctly refuses live-fire against stub targets and unsets stale
  `MOCHI_REAL_*` overrides loudly.

## Suggested iteration-5 sequencing

1. F1 (interface version validation + conformance probes) and F2 (manifest with
   M1–M5 checks) — these are the structural fixes; F6/F7 fold into them.
2. F3 (approval-isolation probe), F4 (live-fire timeout), F5 (vacuous map guard).
3. F8–F10 as time allows; F9's timing instrumentation is cheap and worth doing
   with F4.
