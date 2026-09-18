# Iteration-8 review — staff systems engineer (08-systems)

Lens: INTERFACE CONTRACTS. Repo at 2243723 ("Iteration 7: contract conformance").
Method: read-only review + simulated-mode runs only. Never set
`MOCHI_LIVE_FIRE=1`; all payloads synthetic; repo untouched
(no tracked file modified); `local.env`, `~/workspace/your_files/`,
and memory files untouched. Edge cases that required mutation were
tested against copies under `/tmp/systems-review/`, never the repo.

Baseline: full `bin/leakage-audit` against the synthetic stub —
**66 passed · 0 failed · 2 skipped, exit 0** (the 2 skips are the
expected non-CI ones: no denylist, fresh gate log).

## Spot-verified working (not findings)

- **Version-mismatch fail behavior (brief's core question): correct.**
  Stub copy with `interface_version=99` → exactly **one** FAIL
  (`[A] interface version mismatch`), suites B–E fully suppressed
  (no `@@@ SUITE B/C/D/E` sentinels), summary shows only suite A,
  `VERDICT: ATTENTION`, exit 1. No misattributed checks.
  `bin/leakage-report` against that audit output refuses loudly:
  `unexpected suite sequence … refusing to write a misleading report`,
  exit 3, no HTML written. Fail behavior is right at both layers.
- **Single enforcement point holds.** `AUDIT_INTERFACE_VERSION` is
  defined once (line 72), compared once (suite A, first check), and
  `INTERFACE_OK` gates everything after suite A. No other code parses
  `.synthetic-stub`'s `interface_version`.
- **Exit-code discipline on the direct paths:** usage errors
  (`--content-file` with no arg, bare `brief-gate`, missing files)
  all exit 1 (fail closed — contract permits "block (1) or another
  nonzero"); approval isolation holds (block-tier stays rc=1 under
  `MOCHI_EGRESS_APPROVED=1`, pinned in suite B); no delegate → 127;
  self-delegate via `MOCHI_REAL_*` → 1 with a clear message, in both
  shims. The iter-7 draft token-confusion fix (N11) is still pinned
  and passing.
- **GWS raw-stdin replay is byte-identical** (verified with a
  hashing fake delegate: replayed sha256 == original sha256) — but
  see L1.

## New findings

### H1 · HIGH — Gates fail OPEN when the detector dies abnormally (rc=137)
**Files:** `test/stub-memory-skill/bin/egress-gate`,
`test/stub-memory-skill/bin/brief-gate`.
**Evidence (repo code, confirmed against a /tmp copy with a
signal-killed detector):**
```bash
if [ "$RC" -eq 1 ]; then ...; exit 1; fi
if [ "$RC" -eq 2 ] && [ "$APPROVED" -ne 1 ]; then ...; exit 2; fi
exit 0
```
Any detector exit outside {1, 2} — 137 (SIGKILL/OOM), 143, 126/127 —
falls through to `exit 0` = ALLOW. Demonstrated: detector killed with
`kill -9` → both gates return **rc=0** on a block-tier fixture.
**Why it matters:** the agent-facing contract is direct invocation —
the stub AGENTS.md mandates `bin/brief-gate --brief-file …` with
"Spawn only on exit 0". A detector that dies (OOM, signal, timeout
kill) therefore produces an *allowed* verdict and the brief spawns
ungated. This directly violates `references/gate-interface.md`:
"Non-verdict errors … must fail closed — surface as block (1) or
another nonzero code, but **NEVER as 0**". (The shim path is
accidentally safe — `gate_file` only delegates on rc==0 of the *gate*,
and the gate's 0 here is the bug — so the fail-open is fully exposed
on the mandated direct-invocation path.) This is the iter-7 deferred
"rc=137 handling" thread, still open.
**Fix:** default-deny fallthrough — treat any RC not in {0,2}
as block: e.g. `case "$RC" in 0|2) …;; *) exit 1;; esac`, or
explicitly `exit 1` instead of `exit 0` at the end. The audit's
`gate_expect`/`adversarial-run` would then surface it as a mismatch
rather than a silent allow.

### M1 · MEDIUM — Audit's delegate self-identity check disagrees with the shim (false FAIL)
**File:** `bin/leakage-audit` (suite A delegate loop) vs
`test/stub-memory-skill/bin/shims/hatch_gws_cli` (delegate scan).
**Evidence (empirical):** PATH = `aliasdir : shimdir : delegates`, where
`aliasdir/hatch_gws_cli` is a symlink to the shim itself and
`delegates/` holds a real distinct binary. The shim's own scan *skips*
the aliased-self entry and delegates correctly (clean send rc=0). The
audit **break**s at the first executable PATH match, sets `real_self=1`,
and FAILs: "delegate hatch_gws_cli resolves to the shim itself
(self-exec loop)" — whole audit exit 1 on a working configuration.
The contract says "the audit asserts distinctness the same way" — it
does not: the shim *continues* past self entries, the audit *stops* at
them. This is a misattributed check of exactly the kind the
contract-conformance work was meant to eliminate.
**Fix:** mirror the shim — `continue` past self-resolving entries and
only fail if no distinct delegate is found at all (keep a loud FAIL
when the *only* candidate is self).

### M2 · MEDIUM — Messenger stdin-echo: failure evidence can carry payload content
**Files:** `bin/leakage-audit` (`send_expect`, replay check) and the
inline fake `real-msg`.
**Evidence:** the fake delegate prints argv hashed
(`argv-sha256=…`, good) but stdin **verbatim** between
`---stdin---`/`---endstdin---`. `send_expect`'s failure evidence is
`head -3` of that stdout, so on a mismatch — precisely the case where
a send that should have been stopped *reached* the delegate — the
payload's first line lands in the report evidence and the HTML
transcript. Demonstrated: approved clean send → delegate stdout
contains the full message body, and the `head -3 | tr '\n' '|'`
rendering embeds it. (All synthetic here, but the mechanism is the
point — and in live-fire, `live_send_expect` quotes `head -3` of the
*real* CLI's stdout the same way.) This is the deferred
"messenger stdin-echo hashing" thread.
**Fix:** fake `real-msg` should print `stdin-sha256=` instead of
echoing; the replay-integrity check should compare hashes rather than
extracting full content. Same treatment for `real-gws` if it ever
echoes stdin.

### M3 · MEDIUM — `contract_version` in gate-interface.md is prose; nothing parses it
**Evidence:** `grep -rn contract_version bin/ test/ .github/` → zero
code hits. Enforcement compares the stub's `interface_version`
against the hardcoded `AUDIT_INTERFACE_VERSION="1"`. The document's
own machine-readable field (added for iter-7 N12) and the code
constant can drift silently — bumping the doc to 2 without touching
the audit changes nothing, and nothing checks they agree.
**Fix:** one suite-A self-consistency check: parse
`contract_version:` from `references/gate-interface.md` and require
equality with `AUDIT_INTERFACE_VERSION` (fail the audit's own
preconditions otherwise). That makes the doc the single source of
truth instead of a decorative duplicate.

### L1 · LOW — GWS raw-stdin byte-identical replay is unasserted
The contract promises "the original stdin bytes are replayed to the
delegate byte-identical" for the stdin form. The audit pins this for
Messenger ("messenger stdin replayed byte-identical on allow") but
never for `gmail users messages send < stdin` — the fake `real-gws`
only prints `argv-sha256`, so replay integrity on that path is
untested. (Implementation is correct today — verified by hash
comparison — but a contract clause with no check is a regression
waiting to happen.)

### L2 · LOW — Report tri-state grouping still ignores failure evidence (N16 open)
`tri_state_groups` in `bin/leakage-report` regexes `rc=(\d)` over
`c["text"]` only. Failed checks' text is `"[B] <name>"` (no rc); the
want/got rc lives in `c["ev"][0]`. So exactly the checks that matter
most land under "Other evidence", defeating the card's stated purpose
("never mixes the two protection tiers in one undifferentiated
list"). One-line fix as proposed in iter-7.

### L3 · LOW — Yellow semantics are dead (legend promises, no card delivers)
The report legend defines 🟡 "protected through approval —
review-tier: refused without explicit approval (rc=2)", but card
classes are only `red/stub/ok/skip` and no callout ever emits 🟡.
A suite-B card where every check passed *as review-tier-gated* renders
green "ok" — indistinguishable at card level from "everything
hard-blocked". Either use yellow for approval-gated-dominant suites
or drop it from the legend. (Deferred "yellow-semantics consistency".)

### L4 · LOW — SHAPES drift vs patterns.sh persists (N13 open)
The audit's inline `SHAPES` (fixture-purity check) is still narrower
than `test/stub-memory-skill/bin/patterns.sh`: amex-with-separators
(`3[47]…([- ]?…){2}`) and the `\b`-anchored 16-digit group form exist
only in `patterns.sh`. A fixture containing an undeclared
separator-form token would pass the purity check while the detector
(and blockset builder, which uses `patterns.sh`) treats it as
block-tier — the purity gate has a blind spot. Manifest the shapes in
one place, as iter-7 proposed.

### L5 · LOW — Drive `permissions create` ignores the `--approved` flag form
`gate-interface.md`: "Approval override: `MOCHI_EGRESS_APPROVED=1`
(or `--approved)`". The shim's drive branch honors only the env var;
`drive permissions create --approved` → refused rc=2 (verified).
Fail-closed direction, so no leak — but the flag form is silently
ignored where the contract advertises it. Either honor it or narrow
the contract wording for the shim path.

### L6 · LOW — Messenger shim: combined `--text` + stdin is not byte-identical replay
With both `--text TEXTPART` and piped stdin, the delegate receives
`stdin + "\n" + text + "\n"` (verified), not the original stdin bytes.
Contract: "on allow, stdin is replayed to the delegate byte-identical."
Edge case (real delegates read `--text` anyway), but the contract
overstates.

### L7 · LOW — No CI negative test for the version-mismatch path
Iter-7's N12 design proposed a CI negative test (stub copy with
`interface_version=99` → exactly one FAIL, B–E skipped, exit 1). The
behavior is correct (verified above), but `validate.yml` never
exercises it — the single most important fail-closed branch of the
audit is unpinned in CI.

### L8 · LOW — Blockset `--check` conflates "stale" with "tooling broken"
`build-blockset.sh --check` exits 2 when the corpus is missing; the
audit reports any nonzero as "stub blockset.txt is stale" with a
"rebuild it" suggestion — but rebuilding would fail the same way.
Distinguish the suggestion (or surface exit 2 distinctly).

## Carried-forward / re-verified (still as reported, not new)
- N13 (SHAPES manifest) and N16 (tier-split ignores evidence) from
  iter-7 remain open — restated above as L4/L2 since they sit squarely
  in this lens (contract-shaped check inputs; report tier coherence).
- N11 (draft token-confusion), N17 (live-fire timeout), N18 (blockset
  currency), N19 (positional drive matching): fixes holding, pinned by
  checks that pass.

## Suggested sequencing
1. H1 (fail-open on detector death) — the only finding where the
   mandated agent workflow can proceed ungated; one-line fallthrough
   fix in both stub gates.
2. M1 (audit/shim identity parity) + M2 (stdin hashing) — both are
   "the harness must not misreport or re-expose," same diff area
   (suite A + suite B fake binaries).
3. M3 (parse `contract_version`) + L7 (CI negative test) — lock the
   version contract in code and in CI together.
4. L2/L3 (report tier coherence) + L1 (GWS replay assertion) —
   report-design iteration territory.
5. L4/L5/L6/L8 — small polish.

**Finding count: 12** (1 high, 3 medium, 8 low). No regressions found
in iter-7's fixes; baseline audit green at 66/0/2.
