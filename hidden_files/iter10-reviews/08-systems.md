# Iteration-10 review — Staff systems engineer (contracts, interfaces)

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY; read `references/gate-interface.md`, suite-A
contract check, stub layout, audit suite structure. No repo writes.

**Lens:** interface contracts, conformance checking, layering (what the
harness may assume about the target).

## Verdict summary

**3 findings: 1 P1, 2 P3.** The P1 is the contract half of the convergent
theme: the audit may only probe what the contract names, so the write-time
interface must be named in `references/gate-interface.md` before the probes
are contract-shaped.

## Findings

### SYS-1 (P1) — the write-time interface is not in the contract

**What.** `bin/leakage-audit`'s probes are "contract-shaped": suite A
establishes `interface_version` conformance before any contract-shaped
probe runs, precisely so version skew is not misattributed as broken gates.
The memory-guard probes would be the first probes shaped by an interface
the contract does not name. Per the contract's own discipline, add an
additive "Write-time interface (memory-guard)" section to
`references/gate-interface.md`: CLI shape `memory-guard [path ...]`,
exit 0 = clean / 1 = secret block-tier / 2 = figure-or-personal-data
review-tier, `MEMORY_FIGURE_ALLOWLIST` honored for figure/PII matches only
(never secrets), `-h|--help` usage. Additive → `contract_version` stays 1
→ the suite-A version gate is unaffected. The stub's double implements this
section; the real `memory-guard` is the reference implementation.

### SYS-2 (P3) — suite A should cover the new binary

**What.** Suite A ("Installation integrity") asserts every gate binary is
present, executable, and parse-clean — currently `egress-gate`,
`brief-gate`, `memory-egress-check` in the presence loop and those plus
both shims in the `bash -n` loop. `bin/memory-guard` belongs in both loops
the moment suite C probes it; otherwise suite C could fail on a target
whose suite A was green, which breaks the suite's contract ("establish the
binaries before probing them"). +2 checks, both targets, no skips.

### SYS-3 (P3) — crash-probe copies inherit the double automatically

**What.** Non-issue verification: the suite-A fail-closed probes (`rc=3`/
`rc=137` detectors) operate on `/tmp` copies of the target and replace only
`bin/memory-egress-check`. A stub `bin/memory-guard` rides along in the
copy harmlessly; the crash probes do not touch it. No changes needed —
recorded so the interaction is explicitly considered, not overlooked.
