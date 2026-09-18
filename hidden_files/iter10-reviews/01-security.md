# Iteration-10 review — Senior security engineer

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`
("Iteration 9: fail-closed gates + red-team coverage of critical send paths"),
branch `main` (not pushed).
**Mode:** REVIEW-ONLY. No writes to the repo tree (only this review file);
no git operations beyond read-only `log`/`status`; no live-fire; no network
sends. Every shell context started with the shim PATH export; all probes
used synthetic fixtures or fake delegates; nothing was ever really sent.
Spawning was unavailable in this session, so this review was conducted
in-house under the same read-only constraints the brief imposes on
reviewers.

**Method:** full read of `bin/leakage-audit` (815 lines), `bin/adversarial-run`,
`bin/leakage-report` (851 lines), `.github/workflows/validate.yml`,
`bin/adversarial-corpus.txt`, `references/attack-surface.md`,
`references/gate-interface.md`, `references/test-matrix.md`, stub gates/shims/
`patterns.sh`/`build-blockset.sh`; behavioral probes of the real
`memory-guard` (`~/workspace/skills/personal-memory-system/bin/memory-guard`)
against repo fixtures with `MEMORY_FIGURE_ALLOWLIST=/dev/null`.

**Baselines measured this session (pre-review):** stub audit 86/0/1 CLEAN
(`@@@ TOTAL 86 0 1`); stub adversarial 36/36; real audit 82/0/5 CLEAN
(`@@@ TOTAL 82 0 5`); real adversarial 36/36. All green, matching iter-9.

**Severity rubric:** P0 = confirmed bypass or validation certifying a
bypass as clean. P1 = uncatalogued exfil path, contract violation, or
harness blind spot with a short chain. P2 = measurement-integrity hole
(green output not meaning what it claims) or conditional bypass.
P3 = diagnostic accuracy / doc errors. P4 = nits.

## Verdict summary

**7 findings: 1 P1, 3 P2, 3 P3.** No P0: iteration 9 closed the confirmed
send-path bypasses and the fail-open detector exits, and I found no new
bypass in the send plane. The single P1 is the write plane:
**`bin/memory-guard` — the write-time control behind catalog claims D1
(PROTECTED) and D2 (APPROVAL-GATED) — is never invoked by the audit.**
`references/test-matrix.md` lines 123–124 admit this outright ("Vacuous
against stub targets … not harness-verified where CI runs"). The skill's
own coverage discipline ("a path with no scenario is an unexamined path")
is violated in the one place the catalog claims a control: the control
exists, the claim exists, the test does not. The write plane is also the
highest-frequency plane — the daily refresh writes memory every morning —
so this is the least-examined *and* most-exercised control.

## Findings

### [EXEC][P1] SEC-1 — memory-guard is catalogued but never probed

**What.** `references/attack-surface.md` D1: "Secrets written into memory
files — PROTECTED (at write time) — `bin/memory-guard` scans new content
before writing; secrets are a hard block." D2: figures "APPROVAL-GATED (by
policy) — memory-guard flags figures for the user's review." The audit
(`bin/leakage-audit`) never executes `memory-guard` — grep for
`memory-guard` in the audit returns only a suggestion string (line 466).
Suite C's "scenario coverage map" check (attack-surface ↔ test-matrix) is
satisfied because both documents *mention* the control; nothing verifies
the binary exists, parses, or behaves. A regression that deleted
`memory-guard` from the real installation (or broke its SECRET_RE) would
still audit CLEAN. I confirmed the binary is probe-able and deterministic
on repo fixtures: `secret.txt`/`secret2.txt` → rc=1, `figure.txt`/
`phone.txt`/`ssn.txt`/`card.txt` → rc=2, `clean.txt` → rc=0, and a
`MEMORY_FIGURE_ALLOWLIST` entry demotes a figure to rc=0 — all with explicit
fixture paths, so probing never scans the real memory tree.

**Why it matters.** This is exactly the failure mode the skill exists to
prevent ("the unexamined path"). Iteration 9's theme was "every way a send
could dodge the gate is now closed, tested, and pinned" — the write plane
was not in that set.

**Recommendation.** Add write-time probes to the audit (suite C, which is
"verifies each path's stated control is actually in place"): secret → rc=1,
figure → rc=2, phone/PII → rc=2, clean → rc=0, allowlisted figure → rc=0,
allowlisted secret → still rc=1. Suite A should assert `bin/memory-guard`
present/executable/parses. The stub needs a `memory-guard` test double
(lookup-based, like `memory-egress-check`, documented as non-protection) so
CI exercises the probes; `gate-interface.md` gains an additive write-time
interface section (no version bump). Probes must pass explicit paths and a
controlled `MEMORY_FIGURE_ALLOWLIST`, never scan the default tree.

### [STATIC][P2] SEC-2 — corpus has no evasion variants

**What.** `bin/adversarial-corpus.txt` (36 cases) contains no case
variants (`SK_LIVE_…`, `API_KEY=`), no whitespace-inside-token variants, no
punctuation-adjacent variants, no multi-tier payloads (secret + figure in
one input). The block tier is 19/19 against tokens in the exact shapes the
author wrote. A detector regression that became case-sensitive would still
score 36/36. The stub double cannot distinguish this (undeclared
secret-shaped → review-tier by design), so evasion cases would need corpus
+ blockset + CI-pin updates together — noted as implementation cost, not a
reason to skip.

### [STATIC][P2] SEC-3 — live-fire guards have no CI assertions

**What.** The audit's live-fire safety (exit 2 on stub targets, exit 2 when
`MOCHI_LIVE_FIRE` came only from `local.env`, non-TTY refusal) is enforced
in `bin/leakage-audit` but asserted nowhere in CI. `.github/workflows/
validate.yml` only refuses the *variables* in the environment. A regression
that silently dropped the stub-refusal would not fail CI — the most
dangerous failure mode of an opt-in real-send path. The iter-9 backlog
listed this ("live-fire guard CI steps beyond exit-2"); it did not land.

### [STATIC][P2] SEC-4 — residual enumeration lives in three places

**What.** Suite E residuals are hardcoded `printf` lines in
`bin/leakage-audit`, a prose list in `references/attack-surface.md`
("Residual risk summary"), and another list in `README.md`. No mechanical
check asserts they agree. They agree today (verified by reading all three),
but the next edit to one will silently desync the others — the exact drift
the machine-readable sentinels were built to prevent elsewhere.

### [STATIC][P3] SEC-5 — B2/B3 scan HEAD only, not history

**What.** The denylist check (`git ls-files | xargs grep`) scans tracked
files at HEAD. `ITERATIONS.md` documents that pre-purge private values
remain in public history near `918e243`. A private literal introduced and
later removed would pass the check while remaining in history. Scoped as
P3, not P2, because history scanning risks *surfacing* those values into
CI logs — the cure is worse than the disease without a redaction design.

### [STATIC][P3] SEC-6 — `.egress-allowlist` semantics never exercised

**What.** The real `memory-egress-check` honors `MEMORY_EGRESS_ALLOWLIST`
(digit-normalized, ≥7 digits). The audit never probes that the allowlist
cannot exempt block-tier shapes — the only mention is a suggestion string.
A regression that applied the allowlist to block-tier verdicts would audit
CLEAN. Lower severity than SEC-1 (the send path itself is probed; this is
the exemption path), but the same "claim without a test" shape.

### [STATIC][P3] SEC-7 — probe timeouts for any new guard probes

**What.** Design note for SEC-1's implementation: every new probe must run
under `timeout -k` like `gate_expect`/`send_expect`. A hung `memory-guard`
(dropped NFS handle, pathological regex) must fail the audit, not wedge it.

## Out of scope / not findings

- `import`/`insert`, chat/calendar, attachments, chunked exfiltration,
  out-of-band egress, browser-task VM, absolute-path bypass: already
  catalogued as OPEN/POLICY-ONLY and re-reported by suite E. No change.
- The stub's undeclared-secret-shaped → rc=2 fail-closed design is
  intentional and documented; not a finding.
