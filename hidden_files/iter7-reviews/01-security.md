# Iteration-7 review — Senior security engineer

Target: `~/workspace/skills/muse-leakage-guard`, HEAD `e20a819` ("Iteration 6: CI fails honest").
Mode: REVIEW-ONLY, simulated. No live-fire, no `local.env` touched, all payloads synthetic.
Method: full-repo read + empirical probing of the bundled stub in simulated mode
(fake delegates, `MOCHI_REAL_*` overrides, synthetic fixtures only).

## Verdict summary

8 findings: **2 High, 4 Medium, 2 Low** (2 of the Mediums and both Lows are
still-open carryovers from the iter-6 security round, re-verified against HEAD —
they are listed so they don't get silently dropped, but they are not new).
All three empirically confirmed findings reproduce deterministically.

The iteration-7 focus areas were all probed directly; results are inline
below and in "Focus-area verification" at the end.

---

## HIGH

### H1 — Stub GWS shim does not gate the stdin form of raw MIME: secret in encoded payload reaches the delegate ungated

- **Evidence:**
  - Contract: `references/gate-interface.md:69` — "Raw API path (`gmail users
    messages send` with `{"raw": "<base64url>"}` **on stdin**): the MIME is
    base64-decoded and gated before delegation."
  - Stub: `test/stub-memory-skill/bin/shims/hatch_gws_cli:83–128` — the
    `users) messages send` branch extracts the payload only from argv
    (`--json=`/`--params=`). When the payload arrives via stdin, `payload`
    stays empty and the shim gates the literal string `(no payload captured)`
    (`:128`), which is clean — then `gate_file` delegates `"$@"` with the
    shim's stdin inherited untouched by the delegate.
  - Audit coverage: `bin/leakage-audit` tests only the argv form
    ("raw messages.send with card in MIME blocked" passes `--params`); no
    check exercises the stdin form. `references/test-matrix.md` section B
    maps A4 to the argv-form row only.
- **Reproduction (simulated, synthetic fixtures):** with a fake delegate
  recording argv+stdin, `echo '{"raw":"<base64(card.txt)>"}' | hatch_gws_cli
  gmail users messages send` → rc=0, delegate invoked, raw JSON (containing
  the card fixture's base64) delivered to the delegate byte-identical.
  The argv form of the same payload is correctly blocked (rc=1). Deterministic.
- **Recommendation:** implement the stdin form in the stub shim per the
  contract (drain stdin, decode `raw`, gate the MIME, replay to the delegate
  on allow — mirroring the messenger shim's stdin-replay pattern), and add a
  red-team case for the stdin form so CI would go red on a regression.
- **Residual if not fixed:** A4's "PROTECTED" verdict is verified only for the
  argv form. The contract's stdin form is a documented-but-ungated bypass in
  the test double, and CI is green only because the form is untested — the
  exact failure mode this harness exists to prevent (an unexamined path).

### H2 — Stub `die()` exits 2 (review-tier): operational failures are approvable, and one is fail-open

- **Evidence:**
  - `test/stub-memory-skill/bin/memory-egress-check:31` —
    `die() { ...; exit 2; }`, used for operational failures: missing
    `blockset.txt` (`:32`) and unreadable input file (`:39`).
  - `test/stub-memory-skill/bin/egress-gate:25–33` — `RC=1` → block;
    `RC=2 && !APPROVED` → review; otherwise allow. A `die()` rc=2 is
    therefore *approval-overridable*, and with `MOCHI_EGRESS_APPROVED=1`
    set it becomes rc=0.
  - Related instance: `test/stub-memory-skill/bin/brief-gate:18` — missing
    required `--brief-file` exits 2, i.e. a usage error is labeled with the
    review-tier verdict code (it exits before the approval check, so it
    can't be approved to 0, but an operator/agent reading rc=2 sees
    "needs approval for figures/PII", not "you forgot the required argument").
- **Reproduction (simulated):** stub copy without `blockset.txt`;
  `MOCHI_EGRESS_APPROVED=1 egress-gate --content-file payload.txt` → rc=0.
  An operational failure ("I cannot evaluate this at all") is approved
  through as if the content were clean. Deterministic.
- **Consequence through the audit's verdict logic** (`bin/leakage-audit`,
  `gate_expect`): with a broken blockset, a block-tier fixture yields
  "want rc=1, got rc=2" plus the suggestion *"block-tier payload passed the
  gate. Tighten SECRET_RE/BLOCK_RE …"* — the payload did not pass; the gate
  failed closed on a missing data file, and the suggestion misdiagnoses it
  as a detection-pattern problem. A clean fixture yields "want rc=0, got
  rc=2" with *"benign content was gated (rc=2). Narrow the over-matching
  pattern"* — again wrong: nothing was over-matched. Every downstream
  diagnosis points the operator at patterns instead of at the broken
  installation.
- **Recommendation:** operational/usage errors in gates must exit block-tier
  (1) — never approvable — or a dedicated error code outside the 0/1/2
  verdict contract (the audit itself already uses exit 2 for CLI usage
  errors, which is fine for a CLI but wrong for a gate verdict). `die()`
  → `exit 1`; brief-gate's missing-arg → `exit 1` (or a distinct code the
  contract reserves for errors). Then add one audit case: gate with an
  unreadable blockset must refuse with rc=1 even under approval.
- **Residual if not fixed:** the harness's own approval-isolation property
  ("approval never downgrades block-tier") is void the moment the detector's
  data file is missing and approval is set — a fail-open path in the very
  mechanism that is supposed to prove fail-closedness, plus systematically
  misleading remediation advice in the audit output.

---

## MEDIUM

### M1 — Delegate resolution can self-exec: no canonicalization, no self-guard (confirmed infinite loop)

- **Evidence:** both stub shims resolve the delegate by scanning PATH with a
  string comparison `[ "$d" = "$SHIM_DIR" ]`
  (`test/stub-memory-skill/bin/shims/hatch_gws_cli:17–26`,
  `hatch_messenger_cli:17–26`). `SHIM_DIR` is a logical `pwd` (symlinks not
  resolved), PATH entries are compared verbatim, and nothing verifies the
  resolved delegate differs from the shim itself.
- **Reproduction (simulated):** (a) CWD = shim dir with a relative `.` in
  PATH → `./hatch_gws_cli` resolves as the delegate → infinite self-exec
  (had to be SIGKILLed; `timeout -k` reported rc=124). (b)
  `MOCHI_REAL_HATCH_GWS_CLI=<the shim itself>` → same infinite loop
  (rc=124). Deterministic.
- **Recommendation:** canonicalize both sides (`realpath`/`readlink -f`,
  with a portable fallback) before comparing, and add a self-identity guard:
  refuse (fail closed, distinct message) when the resolved delegate is the
  shim itself — by canonical path or by device+inode.
- **Residual if not fixed:** a plausible agent context (relative PATH entry,
  symlinked skill dir, stale env override) turns every send through that
  context into an infinite process-replacement loop — a local DoS that, in a
  real deployment, hangs the agent rather than failing closed. In the audit,
  the `timeout -k` wrapper converts it to rc=124 → a finding, so the harness
  itself is protected; the pattern it blesses is not.

### M2 — Contract claims "the audit asserts" a distinct delegate executable; no such assertion exists

- **Evidence:** `references/gate-interface.md:79` — "The delegate must be a
  second, distinct executable — **the audit asserts this** so a shim can
  never be 'tested' against itself." `grep -rn "distinct" bin/ references/
  .github/` finds only the contract sentence and a workflow comment; nothing
  in `bin/leakage-audit` compares the resolved delegate (via `MOCHI_REAL_*`
  or PATH scan) against the shim path.
- **Why it matters:** suite B's whole meaning rests on the fake "real"
  binary being genuinely behind the shim. Today that holds only because the
  script sets `MOCHI_REAL_*` to fresh temp files — an operator-supplied or
  stale `MOCHI_REAL_HATCH_GWS_CLI` pointing at the shim itself (cf. M1)
  would make suite B test the shim against itself and report green.
  (Live-fire mode already unsets stale `MOCHI_REAL_*` loudly — good — but
  simulated mode overwrites them silently.)
- **Recommendation:** in suite B (simulated), after provisioning the fake
  binaries, assert each delegate's canonical path differs from the shim's
  (fail the suite otherwise). One check, in the audit, making the contract
  sentence true.
- **Residual if not fixed:** the contract overstates what is enforced; a
  misconfigured delegate turns the red-team suite into a self-consistency
  theater with green output.

### M3 — `live_send_expect` has no timeout: a hung live-fire send hangs the whole audit

- **Evidence:** `bin/leakage-audit:430–438` — `out="$("$@" 2>&1)"; rc=$?`
  with no `timeout` wrapper. Every simulated path in the same file uses
  `timeout -k 10 30` (`gate_expect:339,341`, `send_expect:363`), and
  `adversarial-run` uses `timeout -k 5 10`. The live-fire path — the real
  network path, where hangs are *most* likely — is the one place without a
  bound. (The post-suite stdin-replay check at `:423` is likewise
  unwrapped; minor.)
- **Recommendation:** wrap live-fire invocations in the same
  `timeout -k 10 <N>` idiom with an rc=124 → finding path, so a hung real
  send is reported rather than hanging the operator's terminal forever.
- **Residual if not fixed:** a wedged real CLI during a live-fire run
  blocks the audit indefinitely; the operator gets no verdict at all.

### M4 — `interface_version=1` declared but never enforced (carryover, still open)

- **Evidence:** declared in `references/gate-interface.md:1,6` and
  `test/stub-memory-skill/.synthetic-stub` (`interface_version=1`); nothing
  in `bin/leakage-audit` reads or compares it. First reported as iter-6 P2;
  re-verified: still no enforcement at HEAD.
- **Recommendation:** suite A should read the target's declared interface
  version and fail fast with one clean "interface version mismatch" verdict
  instead of N confusing per-check FAILs with pattern-tightening suggestions.
- **Residual if not fixed:** a v2 target (changed CLI, new exit codes)
  produces misleading per-check failures; the operator debugs patterns
  instead of noticing the contract changed.

---

## LOW

### L1 — C5 still overclaims: "the send would still hit the egress gate" is false for out-of-band sends (carryover, still open)

- **Evidence:** `references/attack-surface.md:189–196` (C5, PROTECTED "in
  depth"): *"Even if an agent were steered, the send would still hit the
  egress gate (A1–A4: secrets blocked, figures need approval)"*. The same
  document lists out-of-band egress — curl, webhooks, unshimmed CLIs — as
  OPEN (`references/attack-surface.md`, residual summary; suite E restates
  it every run). A prompt-injected agent steered to `curl -X POST` an
  attacker webhook never touches any shimmed path, so the defense-in-depth
  claim holds only for steered actions that happen to use shimmed CLIs —
  precisely the assumption an injection tries to violate. First reported as
  iter-6 P2; re-verified: wording unchanged at HEAD.
- **Recommendation:** qualify the C5 verdict (PROTECTED-in-depth *for
  shimmed send paths*; the out-of-band variant is OPEN, cross-referenced to
  the residual), so the catalog doesn't contradict itself.
- **Residual if not fixed:** the catalog simultaneously promises C5 is
  PROTECTED and admits the bypass is OPEN — a reader (or a future control)
  can cite the wrong half.

### L2 — Contract "body/to" vs stub gating subject+body only (carryover, still open)

- **Evidence:** `references/gate-interface.md` shim contract says
  "+send/+reply/+forward: **body/to** pass `egress-gate`"; the stub gates
  `subject + body` and puts `to` only in the context label
  (`test/stub-memory-skill/bin/shims/hatch_gws_cli`, `+send` branch).
  First reported as iter-6 P2; re-verified: unchanged at HEAD.
- **Recommendation:** align the contract wording with what is actually
  gated (or gate `to` too, if recipient allowlisting is intended).
- **Residual if not fixed:** minor — a denylisted literal in a recipient
  address would not be caught by the stub; mainly a contract-hygiene issue.

---

## Focus-area verification (explicitly requested)

1. **Stub stdin-form raw MIME (focus 1):** CONFIRMED BYPASS — see H1.
   Empirically: card fixture inside base64 MIME via stdin → rc=0, delegate
   invoked, stdin delivered ungated.
2. **`die()` exit 2 vs contract exit 1 (focus 2):** CONFIRMED — see H2.
   Operational failures are review-tier, approvable, and fail-open under
   approval; the audit's remediation suggestions misdiagnose them as
   pattern problems.
3. **Delegate self-exec loop (focus 3):** CONFIRMED — see M1. Two vectors
   (relative PATH entry with CWD=shim dir; `MOCHI_REAL_*` self-reference),
   both infinite loops requiring SIGKILL. No canonicalization, no
   self-guard.
4. **`interface_version` enforcement (focus 4):** CONFIRMED ABSENT — see M4
   (carryover from iter-6, still open).
5. **Iteration-6 fail-at-the-end (focus 5):** VERIFIED SOUND. Every
   component step writes its exit code to a rc file and `exit 0`; the
   final `assert-green` step is the sole owner of the job outcome (plus the
   two fail-fast Refuse preconditions, by design, with downstream
   `always()` steps additionally gated on their success). No silent
   `|| true` drops on any outcome path — the `|| true` occurrences are
   confined to informational greps inside command substitutions whose
   absence is reported as "unavailable"/"not-run" (and "not-run" ≠ "0"
   fails assert-green). No unanchored prose greps in the outcome path:
   skip-pin uses `^@@@ CHECK SKIP`, summary uses `^@@@ TOTAL/VERDICT/MODE`
   and `^@@@ ADV MATCHED/TIERS`; the one prose grep (`SYNTHETIC STUB
   TARGET`) runs over the generated report HTML, not attacker-influenced
   input.
6. **Timeout rc=124 handling (focus 6):** VERIFIED SOUND — a timeout is
   always a failure, never a pass: `gate_expect` and `send_expect` check
   rc=124 first and `bad()`+return before evaluating invocation;
   `adversarial-run` records TIMEOUT as a mismatch; `leakage-report`
   maps ADV rc=124 → 3 ("runner failed"). Fake-binary fidelity under forced
   timeouts: the 124 check short-circuits before the invocation sentinel is
   read, so a binary killed mid-`touch` cannot produce a false pass.
7. **Out-of-band egress / C5 (focus 7):** the catalog *does* cover
   curl/webhook/non-shimmed CLI paths — as OPEN/residual, restated by suite
   E every run. The problem is not coverage but the C5 verdict contradicting
   it (see L1). The catalog's own coverage discipline ("a path with no
   scenario is an unexamined path") is satisfied; its verdict consistency
   is not.

## Notes (non-findings)

- **Adversarial sentinel forgery was probed and holds.** `adversarial-run`
  interpolates corpus case names into `@@@ ADV MISMATCH` lines, but corpus
  rows are line-based (`IFS='|' read`), so a name cannot contain a newline
  and cannot forge a new `^@@@ ADV ` sentinel line. A crafted corpus was
  tested: the injected line was parsed as a (malformed) corpus row, not as
  a sentinel. `leakage-audit`'s `msent` additionally strips newlines and
  rewrites `@@@`. No finding.
- **Scope discipline held:** all proposed remediations are validation-side
  (stub conformance, audit assertions, timeouts, verdict codes) — nothing
  here asks the guard to patch other systems.
- **Not re-reported in full:** iter-6 P2 "A7 PROTECTED (by audit) overstates
  a static string check" was re-verified and remains accurate (the check is
  syntactic; the residual note in suite E says so), but it was already
  litigated in iter-6 and the E-residual restatement is the agreed
  mitigation — no new evidence, so not duplicated as a finding.
