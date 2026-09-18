# Iteration-10 review — AI researcher (test-double fidelity)

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY; read stub `memory-egress-check`, `patterns.sh`,
`build-blockset.sh`, stub README, `references/gate-interface.md`. No repo
writes.

**Lens:** fidelity of the synthetic test double — where it must mirror the
real interface, where it must deliberately differ, and that the difference
is labeled.

## Verdict summary

**3 findings: 1 P1, 2 P3.** The P1 is the constructive half of the
convergent theme: CI cannot verify write-time probing without a stub
`memory-guard` double, and the double must follow the same fidelity
contract as the existing one. The design is fully specified below.

## Findings

### AR-1 (P1) — stub needs a `memory-guard` double with the same fidelity contract

**What.** The existing stub `memory-egress-check` follows a documented
fidelity contract: (1) same CLI interface as the real binary (file args or
stdin); (2) verdicts by lookup in a declared synthetic set, never by
detection; (3) undeclared secret-shaped input fails closed to review-tier
(rc=2), never auto-allowed; (4) operational failure (missing blockset)
fails closed to rc=1; (5) labeled everywhere as a test double, never
protection. A stub `bin/memory-guard` must follow the same five rules:
`memory-guard [path ...]` → rc=1 if any secret candidate (per
`STUB_SECRET_CAND`) hashes into `blockset.txt`; rc=2 if any other
secret-shaped, figure-shaped (`STUB_FIGURE_CAND`), or phone-shaped
(`STUB_PHONE_CAND`) content is present; rc=0 if clean; honor
`MEMORY_FIGURE_ALLOWLIST` for figure/phone-shaped matches only (fixed-string
exclusion, mirroring the real tool) — never for secrets; missing blockset →
die with rc=1 (fail closed). Source `patterns.sh` so extractor and builder
cannot disagree (the same invariant the egress-check double maintains).

**Why a double and not "skip on stub".** The test-matrix already documents
D1/D2 as "vacuous against stub targets — not harness-verified where CI
runs." Skipping on stub would preserve that vacuity and leave CI blind to
the new probes' own wiring (a broken probe that always passes would stay
green in CI). The double makes the probes self-testing in CI, exactly as
the egress-check double does for suite B.

### AR-2 (P3) — deliberate difference from the real tool, documented

**What.** The real `memory-guard` blocks *any* `SECRET_RE`-shaped token
(pattern-based); the double blocks only *declared* tokens (lookup-based)
and fail-closes the rest to rc=2. That difference is intentional — a test
double must not become a detector — but it must be stated in the double's
header comment and the stub README, the same way `memory-egress-check`'s
header states it. A reader who mistakes the double's rc=2-on-unknown for
the real tool's rc=1-on-unknown would misjudge real protection. One
paragraph in each place.

### AR-3 (P3) — contract section, no version bump

**What.** `references/gate-interface.md` (`contract_version: 1`) documents
the gate/shim interface the audit's contract-shaped probes assume. The
write-time probes assume a second, smaller interface: `memory-guard [path
...]`, exit 0/1/2, `MEMORY_FIGURE_ALLOWLIST` honored for figure/PII only.
Add it as an additive "Write-time interface" section — additive sections do
not break conformance, so the version stays 1 and the suite-A version check
is unaffected. If a future change alters these semantics, that is when the
version bumps.
