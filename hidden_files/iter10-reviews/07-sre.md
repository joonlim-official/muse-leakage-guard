# Iteration-10 review — SRE (reliability, CI, operations)

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY; read `.github/workflows/validate.yml`, audit
timeout discipline, probe helpers. No repo writes; no CI runs triggered.

**Lens:** CI determinism, pin discipline, timeout hygiene, operational
failure modes of the new probes.

**Baselines:** local stub audit 86/0/1; CI-equivalent pin `@@@ TOTAL 83 0 4`
(documented in workflow); adversarial 36/36.

## Verdict summary

**4 findings: 2 P2, 2 P3.** The theme's implementation has three
mechanical obligations, all P2-or-above if missed: the composition pin
must move in the same commit, every probe needs a timeout, and the
live-fire guards remain unasserted in CI (carried as a separate theme).

## Findings

### [STATIC][P2] SRE-1 — composition pin must move 83 → 91 in the same commit

**What.** The workflow pins `@@@ TOTAL 83 0 4` with the explicit rule:
"when the harness intentionally gains or loses checks, the pin is updated
in the same commit as the check change." The probe set adds 8 checks on the
stub target in CI (2 suite-A: memory-guard present/parses; 6 suite-C:
secret→1, figure→2, phone→2, clean→0, allowlisted-figure→0,
allowlisted-secret→1) and no new skips (the stub ships the double; CI's 4
pinned skips are unaffected — verified: none of the new checks skip).
New pin: `@@@ TOTAL 91 0 4`. The `@@@ ADV MATCHED 36/36` pin is untouched
(corpus unchanged). The workflow's own comment block ("Pinned as of the
iteration that added…") must be updated to name the new iteration, or the
next reader cannot tell which change the pin belongs to.

**Verification plan (for the implementer).** After the change, run the
CI-equivalent locally: `env -i` with stub target, `CI=true`, fresh HOME,
and confirm `@@@ TOTAL 91 0 4` and exactly the 4 pinned skip reasons. The
local run (86→94 / 0 / 1) differs from CI by environment, as documented —
assert the CI-equivalent, not the local number.

### [STATIC][P2] SRE-2 — live-fire guards still unasserted in CI

**What.** Converges with SEC-3: the audit refuses live-fire against stub
targets (exit 2), refuses `MOCHI_LIVE_FIRE` from `local.env` (exit 2 with
warning), and refuses non-TTY without `MOCHI_LIVE_FIRE_NONINTERACTIVE=1`
(exit 2). CI asserts none of these. All three are CI-safe to assert (no
sends possible: the stub target refuses before any send path; the local.env
case exits before gating; the non-TTY case exits before sends). This is a
separate theme from the write-time probes — do not bundle it into the
iteration-10 commit; record it as post-loop backlog. Stating the test
shapes here so the backlog item is actionable:
`MOCHI_LIVE_FIRE=1 PERSONAL_MEMORY_SKILL=<stub> bin/leakage-audit` → exit 2;
a `local.env` containing `MOCHI_LIVE_FIRE=1` (in a /tmp skill copy) → exit 2
with the local.env warning; piped-stdin live-fire without the
noninteractive flag → exit 2.

### [STATIC][P3] SRE-3 — probe timeout discipline

**What.** New probes must run under `timeout -k` (the audit's established
pattern: `timeout -k 10 30` for gate invocations, `timeout -k 5 10` in the
adversarial runner). `memory-guard` runs `grep -rE` over its targets — with
explicit fixture paths the input is tiny, but the discipline is about the
pattern, not this instance: every external invocation in the audit is
bounded. A `guard_expect` helper mirroring `gate_expect` (timeout, rc
comparison, fail message with suggestion) keeps the pattern uniform.

### [STATIC][P3] SRE-4 — syntax-check list gains the new double

**What.** The workflow's "Syntax-check every shell script" step enumerates
files explicitly. `test/stub-memory-skill/bin/memory-guard` must be added
to that list, or a syntax error in the double ships green. Same-commit
obligation as SRE-1.
