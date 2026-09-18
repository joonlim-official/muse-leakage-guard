# Iteration-6 review — staff systems engineer (08-systems)

Repo: `~/workspace/skills/muse-leakage-guard`, HEAD `5ff8950` ("Iteration 5:
honest green"). Read-only review; no repo files modified. Scope: full
repository, unlimited — `bin/leakage-audit`, `bin/leakage-report`,
`bin/adversarial-run`, `test/stub-memory-skill/bin/*` (patterns.sh,
memory-egress-check, egress-gate, brief-gate, shims ×2,
build/build-blockset.sh), `references/gate-interface.md`,
`references/attack-surface.md`, `references/test-matrix.md`,
`.github/workflows/validate.yml`, fixtures, corpus (36 cases, pinned).

Method: full read of all scripts + references, cross-checked against the
iter5 systems review (`hidden_files/iter5-reviews/08-systems.md`) to separate
new findings from carried-forward open items. No live run (read-only static
review; all claims verified by reading the code, not by executing it).

New findings first (N1–N10), then carried-forward still-open iter5 items with
fresh verification, then what was verified working.

---

## N1 · HIGH — Stub GWS shim does not gate the stdin form of raw MIME; the contract documents exactly that form

**Evidence:**
- `references/gate-interface.md`, "Shim interception contract": "Raw API path
  (`gmail users messages send` with `{"raw": "<base64url>"}` **on stdin**): the
  MIME is base64-decoded and gated before delegation."
- `test/stub-memory-skill/bin/shims/hatch_gws_cli`, `users)` branch (line 83):
  the payload is extracted only from `--json=` / `--params=` **argv** forms
  (lines ~90–99). Stdin is never read in this branch.
- Same file, line 128: when no argv payload is found, the shim writes the
  literal marker `(no payload captured)` to the temp file, gates *that* (clean),
  then `gate_file` → `pass_through "$@"` — which inherits the caller's real
  stdin. The actual raw JSON bytes on stdin flow to the delegate **unexamined**.
- `bin/leakage-audit` suite B tests only the argv form:
  `send_expect "raw messages.send with card in MIME blocked" 1 0 -- $G gmail
  users messages send --params "{\"raw\":\"$RAW_MIME\"}"`. The stdin form has
  zero coverage.

**Why it matters:** the documented interception contract names the stdin form;
the reference implementation (the stub — the thing real-shim authors read to
learn the contract) implements only the argv form; and the audit's red-team
suite only probes the argv form. A real shim written to match the stub would
leave the stdin raw-send path ungated while the harness reports green. This is
the one place in the repo where a *documented* attack path is neither
implemented by the reference double nor tested by the audit.

**Recommendation:** (a) teach the stub's `users` branch to read stdin when no
`--json`/`--params` payload is present (and gate the decoded-or-raw bytes,
fail closed if undecodable — same policy as the argv path); (b) add a suite-B
case piping the raw JSON via stdin (`... users messages send < payload.json`,
expect rc=1, delegate uninvoked); (c) pin both invocation forms in
`references/test-matrix.md` section B. No corpus change needed (this is a
transport-form test, not a detector case).

**Residual if not fixed:** the harness cannot claim the raw-MIME interception
contract holds for the stdin form — the exact form the contract documents. Any
"raw sends are gated" statement is true only for the argv form.

---

## N2 · MEDIUM — Delegate resolution by string comparison: the shim can resolve to itself (infinite exec loop)

**Evidence:**
- `test/stub-memory-skill/bin/shims/hatch_gws_cli` line 23 and
  `test/stub-memory-skill/bin/shims/hatch_messenger_cli` line 22:
  `[ "$d" = "$SHIM_DIR" ] && continue` — skips only the byte-identical PATH
  entry.
- `SHIM_DIR` is computed via `cd … && pwd` (canonical, no trailing slash). A
  PATH entry naming the same directory via symlink (`~/workspace/...` vs
  `/home/hatch/workspace/...`), with a trailing slash (`…/bin/shims/`), or in
  relative form will *not* string-match, so `[ -x "$d/hatch_gws_cli" ]`
  succeeds on the shim itself → `REAL` = the shim → `exec "$REAL" "$@"`
  re-enters the shim with identical argv/PATH → unbounded exec recursion
  (constant memory, 100% CPU; the audit's `timeout 30` in `send_expect` turns
  it into a hang finding, but a production agent context has no such timeout).
- Same flaw in the other direction: nothing stops
  `MOCHI_REAL_HATCH_GWS_CLI=<shimdir>/hatch_gws_cli` (e.g. a stale
  `local.env`), which bypasses the PATH scan entirely and self-execs.
- `bin/leakage-audit` suite A ("real $cli discoverable behind shim") uses the
  identical string comparison, so it would *pass* a trailing-slash self-entry
  as a valid delegate.

**Recommendation:** canonicalize before comparing — `realpath`/`readlink -f`
each PATH dir and `SHIM_DIR` (fall back to inode comparison via
`stat -c '%d:%i'` where realpath is unavailable), and add an explicit
self-guard: if the resolved delegate is the shim's own file, exit 127 with a
diagnostic instead of exec'ing. Mirror the canonicalization in suite A's
discoverability check so the audit can't bless a self-delegate.

**Residual if not fixed:** a plausible PATH misconfiguration (symlinked home,
trailing slash — both common in hand-written shell profiles) turns every
gated send into an infinite exec spin instead of a clean 127. Fail-closed in
theory, hang in practice.

---

## N3 · MEDIUM — CI summary greps a dead phrase; adversarial-run emits zero machine sentinels

**Evidence:**
- `.github/workflows/validate.yml`, "Summarize the validation" step
  (line 156): `grep -aE 'block-tier recall' "${{ runner.temp }}/adversarial.log"`.
  `bin/adversarial-run` no longer prints "block-tier recall" — it prints
  `adversarial-run: block-tier pass N/M · review-tier pass N/M · clean pass
  N/M`. The grep matches nothing; the `|| true` masks it, so the step-summary
  silently drops the tier breakdown it was meant to carry.
- `grep -c '@@@' bin/adversarial-run` → **0**. The audit emits `@@@`
  sentinels under `MOCHI_AUDIT_MACHINE=1` (TS, TARGET, STUBKIND, MODE, SUITE,
  CHECK, CTX, ENDSUITE, TOTAL, VERDICT) and `bin/leakage-report` parses those
  first — but the adversarial half of the report is parsed from human text
  with regexes (`adversarial-run: (\d+)/(\d+) cases matched`, the tier line,
  `MISMATCH…` lines). Any wording drift in the runner silently degrades the
  F card to "runner failed" (fail-closed, but lossy).
- Sentinel coverage assessment: CI's skip-set assertion *already* parses
  sentinels (`grep -a '^@@@ CHECK SKIP'`, line 119 — good). The summary step
  could parse `@@@ TOTAL …` / `@@@ VERDICT …` instead of human text. Missing
  sentinels: everything adversarial (matched/total, per-tier figures,
  mismatch list); also no sentinel for the audit's own refusal paths
  (exit 2 is text-only).

**Recommendation:** (a) fix the summary grep to the real tier line
(`block-tier pass`), or better, parse `@@@` sentinels; (b) have
`adversarial-run` emit `@@@ ADV MATCHED n/total`, `@@@ ADV TIERS b1/b2 r1/r2
c1/c2`, `@@@ ADV MISMATCH <name> want got` lines and make `leakage-report`
parse those first with the regexes as fallback (same primary/fallback shape
as the audit-output parsing); (c) keep the human text unchanged (it is the
fallback).

**Residual if not fixed:** the report's adversarial figures and the CI summary
rest on regexes over human prose — a well-meaning wording tweak in the runner
silently empties both, with no failure anywhere to notice.

---

## N4 · MEDIUM — Stub detector maps internal errors to review-tier (2): undecided content becomes approval-downgradeable

**Evidence:**
- `test/stub-memory-skill/bin/memory-egress-check` line 31:
  `die() { …; exit 2; }` — missing `blockset.txt`, or a non-file argument,
  exits **2** (review-tier).
- Stub gates (`bin/egress-gate`, `bin/brief-gate`): RC=2 +
  `MOCHI_EGRESS_APPROVED=1` → exit 0 → send/brief proceeds.
- Combined: a corrupted installation (blockset deleted) plus a stale
  `MOCHI_EGRESS_APPROVED=1` in the environment (long-lived shell, exported
  once and forgotten) = content the detector could not evaluate is **allowed**.
  The contract's tier semantics ("review-tier: refused *unless approved*")
  assume the gate actually reached a verdict; an internal error is not a
  verdict.
- `bin/leakage-audit` suite A checks the detector binary is executable but
  never asserts `blockset.txt` exists — a missing blockset is caught only
  indirectly (block-tier fixtures then score rc=2 → loud FAILs, correctly,
  but the *mechanism* — error→review-tier — is never asserted).

**Recommendation:** `die()` should exit **1** (block-tier: hard block, never
downgraded by approval). Undecidable input must be the strictest tier, never
the downgradeable one. Add a suite-A check that `bin/blockset.txt` exists and
is non-empty for stub targets (the harness owns the stub; exactness is cheap).

**Residual if not fixed:** the approval-isolation property the audit proves
("block-tier is never downgraded") holds for verdicts but not for detector
failures — the one case where fail-closed matters most.

---

## N5 · MEDIUM — The gate-logging contract clause is never verified; the stub gates don't implement it

**Evidence:**
- `references/gate-interface.md`: gates "Log every decision (timestamp,
  context, verdict) to `$MOCHI_EGRESS_LOG`".
- `test/stub-memory-skill/bin/egress-gate` and `bin/brief-gate`: **zero log
  writes** (verified by grep — no `$MOCHI_EGRESS_LOG`, no `>>`).
- `bin/leakage-audit` suite D only *reviews* a pre-existing log; in simulated
  mode it exports `MOCHI_EGRESS_LOG="$T/gate.log"` (temp) and never asserts
  that the gated sends in suite B appended anything. A real target that
  silently drops all logging passes the audit — suite D just skips ("gate log
  not found").
- Related: the stub shims' fail-closed paths (python3 missing, undecodable
  MIME — `hatch_gws_cli` lines 103–115) exit 1 *without* a gate decision, so
  even a logging target would have no record of the refused send.

**Recommendation:** after suite B in simulated mode, assert the temp gate log
is non-empty and that its line count is consistent with the number of gated
invocations (fail closed on zero lines). Add the log-line shape to the v1
conformance probe set (this also resolves iter5 F6 — the format must be
pinned in `gate-interface.md` first: `TS | context | verdict`, verdict ∈
{BLOCKED, needs-approval, approved-override, CLEAN}). For the stub, implement
the logging clause — the stub is the executable reference for the contract.

**Residual if not fixed:** "every decision is logged" is a contract MUST the
harness never checks — a target with dead logging (no audit trail of blocked
sends or approval overrides) is indistinguishable from a compliant one.

---

## N6 · LOW — `build-blockset.sh` writes `blockset.txt` non-atomically

**Evidence:** `test/stub-memory-skill/build/build-blockset.sh`: final write is
`cp "$tmp.hashes" "$OUT"`. A concurrent audit (or `--check`) reading
`blockset.txt` mid-copy sees a truncated hash set → the stub detector either
`die()`s (missing-hash reads still work on a partial file — worse: candidates
hash-miss and fall to review-tier) or misclassifies block-tier tokens as
review-tier. `bin/leakage-report` already does the right thing
(`tmp + os.replace`, atomic); the build script doesn't.

**Recommendation:** write to `$OUT.tmp.$$` and `mv` into place (same
directory, atomic rename). One-line change, same `--check` semantics.

**Residual if not fixed:** rare, self-inflicted (build concurrent with audit),
and loud when it hits (block-tier fixtures score rc=2 → FAILs). Benign but
inconsistent with the repo's own atomic-write standard.

---

## N7 · LOW — Stub GWS shim gates subject+body but not `--to`; contract says "body/to pass egress-gate"

**Evidence:** `references/gate-interface.md`: "Gmail `+send`, `+reply`,
`+forward`: body/to pass `egress-gate`." The stub shim
(`hatch_gws_cli`, `+send|+reply|+forward` branch) builds the gated file as
`printf 'subject: %s\n\n%s\n' "$subject" "$body"` — the recipient goes only
into the context label (`"gmail $sub to ${to:-unknown} (stub)"`), never into
the gated content.

**Recommendation:** either include the recipient in the gated content (it is
arguably content — a sensitive address in `--to` is exactly what the
messenger shim's `--to` handling implies matters) or tighten the contract
wording to "subject/body" if recipient-gating is intentionally out of scope.
The contract text and the reference implementation should not disagree.

**Residual if not fixed:** none for leakage *of message content*; a
recipient-address policy (if one is ever intended) has no enforcement point.

---

## N8 · LOW — Messenger shim's "byte-identical replay" is relative to gated content, not original stdin

**Evidence:** `test/stub-memory-skill/bin/shims/hatch_messenger_cli`,
`send|edit` branch: tmp = original stdin + `"\n$text\n"`; gate sees tmp; on
allow, `"$REAL" "$@" < "$tmp"`. When `--text` was passed *without* stdin, the
delegate receives the flag `--text <text>` **and** `"\n<text>\n"` on stdin —
the gated combination, not the original stdin (which was empty). The
contract's "stdin is replayed to the delegate byte-identical" holds only for
the `--text-stdin`-only path, which is all the audit's replay check covers
(`send_expect … --text-stdin < clean.txt`).

**Recommendation:** on allow, replay exactly what the gate saw *and* drop the
`--text`/`--text-stdin` duplication ambiguity: either strip `--text*` flags
when replaying tmp on stdin, or document that the replay unit is
(gated-content), not (original-stdin). Add an audit case for
`--text "…"` without stdin asserting no duplication at the delegate.

**Residual if not fixed:** a real CLI that honors both `--text` and piped
stdin could double-deliver the message text on allowed sends. Fail-open in
fidelity, not in leakage — low.

---

## N9 · LOW — `--approved` on the shim CLI is silently ignored (env-only approval)

**Evidence:** the contract documents `--approved` as an approval mechanism for
`bin/egress-gate` / `bin/brief-gate`, and both stub gates parse it. The shims,
however, never translate a `--approved` argv flag into `MOCHI_EGRESS_APPROVED`
for the gate invocation — approval flows only via the environment. A caller
following the contract's `--approved` phrasing against the *shim* gets a
refusal (rc=2) with no diagnostic that the flag was ignored. Fail-closed
direction, so not a leak — but a silent contract-form mismatch.

**Recommendation:** either have the shims map `--approved` → env for the gate
call (consuming the flag so it isn't passed to the delegate), or state in
`gate-interface.md` that `--approved` is a gate-CLI-only form and shim
callers must use the env var. Prefer the explicit statement; flag-plumbing
through two exec layers is where silent drops breed.

**Residual if not fixed:** occasional operator confusion; refusals where
approval was intended. No leakage path.

---

## N10 · LOW — Stub brief-gate conflates usage error with review-tier (exit 2)

**Evidence:** `test/stub-memory-skill/bin/brief-gate`: missing `--brief-file`
→ `exit 2` — the same code as "review-tier: needs approval". A harness or
operator reading rc=2 as "brief needs approval" will misdiagnose a malformed
invocation. (`bin/leakage-audit`'s own exit-2 means "usage error" — the stub
gate overloads the code the opposite way.)

**Recommendation:** exit 3 (or 2 with a distinct, grep-able diagnostic —
already has the message; the code is the issue) for usage errors, reserving
0/1/2 for verdicts. Contract should pin "non-verdict errors never reuse
0/1/2".

**Residual if not fixed:** misdiagnosed failures; no protection impact.

---

## Carried forward — iter5 findings still open (re-verified at HEAD 5ff8950)

- **F1 · HIGH — interface version declared, never validated.** `grep -rn
  interface_version bin/` → no hits. The audit still only tests
  `[ -f "$MEM_SKILL/.synthetic-stub" ]` for stubkind. The full F1
  recommendation (machine-readable version header, target declaration,
  mismatch-is-a-verdict, version-keyed probes, CI negative test) stands
  unchanged. N1/N5 above are concrete instances of the missing probe set.
- **F2 · HIGH — no SHAPES manifest.** The audit's suite-C `SHAPES` regex and
  the stub's `STUB_SECRET_CAND` remain two hand-written regexes joined by a
  comment's promise. (One new datum: the audit comment claims alignment with
  `patterns.sh`, but the stub additionally extracts spaced/dashed Amex
  (`\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b`) which the audit's
  `SHAPES` would not flag — the "superset" direction actually runs
  stub ⊋ audit here, so an undeclared spaced-Amex fixture passes purity while
  the stub fail-closes it to review-tier. The drift F2/F7 predicted is
  already observable.)
- **F4 · MEDIUM — live-fire `live_send_expect` has no timeout** (verified:
  `bin/leakage-audit` line 427ff, `out="$("$@" 2>&1)"`, zero `timeout`
  invocations in the function). Unbounded hang in the most sensitive mode.
- **F5 · MEDIUM — vacuous coverage map.** No `map_count -eq 0` guard added;
  zero `### [A-E][0-9].` headings still yields `ok "all 0 attack-surface
  scenarios mapped in test-matrix.md"`.
- **F6 · MEDIUM-LOW — gate-log line format unpinned by the contract** (see N5:
  the missing verification makes the unpinned format load-bearing and
  untested).
- **F7 · LOW — regex drift** (see F2 note above — now observed, not just
  predicted).
- **F8 · LOW — `adversarial-run` single serial `TMPF`** (unchanged).
- **F10 leftovers · LOW — `parse_legacy`'s `target: (\S+)` captures only the
  first wrapped fragment; `send_expect` stdin coupling** (`<` redirect
  inherited through the function — still the mechanism for all stdin cases).

**Iter5 items verified fixed at this HEAD:** F3 (approval-isolation probes
present in suite B for both gmail and messenger), F10-mismatch-colon
(adversarial-run's TIMEOUT line no longer carries the colon).

---

## Verified working (not findings)

- Sentinel forgery neutralization: `msent` strips newlines and rewrites
  `@@@` in check names/evidence, so hostile fixture content cannot forge
  machine lines; the report's primary path is sentinels with a hardened
  legacy fallback.
- Report fail-closed behavior: unparseable/crashed audit output → no HTML
  (exit 3); adversarial non-zero → badge can never read CLEAN; unknown mode
  → "MODE UNKNOWN" bar.
- Report write path: mktemp capture files, default OUT unique per
  (second, PID), tmp-file + `os.replace` atomic publish — concurrent
  `--out`-distinct runs are safe; same-`--out` concurrent runs are
  last-writer-wins with a complete file (benign).
- Adversarial corpus still exactly 36 cases (pinned count unchanged);
  `adversarial-run` fails closed (exit 3) on empty/corrupt corpus; per-case
  `timeout 10`.
- Live-fire refusal against stub targets; stale `MOCHI_REAL_*` unset loudly
  in live-fire; `local.env`-sourced `MOCHI_LIVE_FIRE=1` ignored with warning
  (explicit-env-wins snapshot logic verified by reading).
- `local.env` present but gitignored; CI refuses a committed `local.env` and
  refuses live-fire variables.
- CI pins the expected skip set (2) via `@@@ CHECK SKIP` sentinels — new
  skips fail the run.
- `build-blockset.sh --check` enforced in CI; refuses to write an empty set.

---

## Suggested sequencing for the iteration-6 diff

1. N1 (stdin raw-MIME: stub + audit case) — the only HIGH; it is also the
   cheapest probe-shaped fix.
2. N4 (`die()` → exit 1) + N5 (gate-log assertion + pin the format) — both
   are fail-closed-semantics fixes in the same tier/error-handling area.
3. N3 (adversarial sentinels + CI summary grep) — observability; unblocks
   honest CI summaries.
4. N2 (canonicalized delegate resolution + self-guard) — robustness; pair
   with the exit-127 probe iter5 F1.5 already specified.
5. Then the carried-forward structural items F1/F2, which subsume F6/F7.
