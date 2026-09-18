# Iteration 10 synthesis — write-time protection is verified, not catalogued
Date: 2026-09-17 PDT · HEAD `653bdd9` · All 10 personas reviewed
(in-house; spawning was unavailable at depth 2, so the coordinator
conducted each persona review directly under the brief's read-only
constraints: no repo writes, no sends, synthetic fixtures and fake
delegates only, shim-PATH shell contexts).

Baselines (measured pre-review): stub audit 86/0/1 CLEAN (`@@@ TOTAL
86 0 1`); real audit 82/0/5 CLEAN (`@@@ TOTAL 82 0 5`); adversarial 36/36
both targets (block 19/19, review 9/9, clean 8/8).

## Convergent finding (9 of 10 personas)

`bin/memory-guard` — the write-time control behind catalog claims D1
("secrets written into memory files — PROTECTED at write time") and D2
("financial figures written into memory — APPROVAL-GATED") — is never
invoked by the audit. `references/test-matrix.md` (lines 123–124) admits
it: "Vacuous against stub targets … not harness-verified where CI runs."
The skill's own coverage discipline ("a path with no scenario is an
unexamined path — that is the failure mode this skill exists to prevent")
is violated at exactly one control: the control exists, the claim exists,
the test does not. The write plane is the highest-frequency plane (the
daily refresh writes memory every morning) and the least-examined one.

Persona angles on the same gap: security (unexamined control, P1),
privacy (write-time privacy control with zero coverage; probe design must
never scan the real tree, P1), PM (CLEAN certifies an unexercised control
— a promise-keeping defect of the kind iterations 3/5/8 fixed in their own
planes, P1), data science (the write-time classifier's three operating
points are unmeasured; no Clopper-Pearson — conformance checks, not a
sampled evaluation, P1), AI researcher (CI needs a stub double with the
same five-rule fidelity contract as the egress-check double, P1), systems
(the write-time interface must be named in the contract before probes are
contract-shaped, P1), SRE (pin must move 83 → 91 in-commit; probes need
`timeout -k`, P2), designer (suite-C rename + `tested_blurb` update or the
report lies about what ran, P2), OSS (E2 labeling for the new double;
one-commit doc checklist, P2/P3), accessibility (no new a11y surface;
standard screenshot QA, P3).

## Theme choice — iteration 10

**"Write-time protection is verified, not catalogued."** One coherent
improvement: the write-time guard gets the same fixture-conformance
treatment iteration 9 gave the send plane — (1) suite-A presence/parses
checks for `bin/memory-guard`, (2) six behavioral probes in suite C
(secret→rc=1, figure→rc=2, phone/PII→rc=2, clean→rc=0, allowlisted
figure→rc=0, allowlisted secret→rc=1), (3) a stub `memory-guard` test
double so CI exercises the probes, (4) an additive write-time interface
section in `references/gate-interface.md` (version stays 1), (5) the
report's suite-C blurb updated to describe what ran, (6) CI pin 83 → 91
and syntax-check list updated in the same commit, (7) docs converged
(attack-surface D1/D2, test-matrix D1/D2, SKILL.md, CHANGELOG.md,
ITERATIONS.md, stub README). This directly serves the skill's stated
purpose and answers the strongest convergent demand across personas.

## Conflict resolution

1. *New suite letter vs report's suite-sequence assertion.* The report
   hard-fails (`die`, exit 3) unless suites are exactly `["A","B","C","D",
   "E"]`. Resolution: probes go in suite C, which per SKILL.md already is
   "verifies each path's stated control is actually in place." Suite C is
   renamed "Attack-surface coverage (controls verified in place)" and its
   `tested_blurb` updated — no new letter, no report structural change.

2. *Skip-on-stub vs stub double.* Skipping the probes on stub targets
   would preserve the exact vacuity the test-matrix documents ("not
   harness-verified where CI runs") and leave CI blind to the probes'
   own wiring. Resolution: the stub ships a `memory-guard` double under
   the existing five-rule fidelity contract (same CLI, lookup-based
   verdicts, undeclared secret-shaped → rc=2 fail-closed, missing blockset
   → rc=1, labeled non-protection everywhere). CI then exercises the full
   probe set; the pin moves to `@@@ TOTAL 91 0 4`.

3. *Probe privacy.* Probing `memory-guard` with default arguments would
   scan the real memory tree and print real content into logs.
   Resolution: probes always pass explicit fixture paths and set
   `MEMORY_FIGURE_ALLOWLIST` to a `/tmp` file; stdout is discarded and
   only the exit code is compared. Stated in code comments (OSS-3) so a
   future edit cannot "simplify" it into an incident.

4. *Scope: live-fire CI assertions (SEC-3/SRE-2) and evasion corpus
   (SEC-2/DS-2) are real but separate themes.* Resolution: explicitly
   deferred to post-loop backlog in ITERATIONS.md (PM-4). The iteration-10
   commit stays single-theme and reviewable. The residual-source-of-truth
   idea (SEC-4) is likewise backlog.

5. *`tested_blurb` derivation.* DES-1 asks for derived, not hardcoded,
   probe/static counts in the card-C blurb. Resolution: the audit tags
   probe check names with the stable prefix "memory-guard: "; the report
   counts them from the machine sentinels. (Implemented below.)

6. *No Clopper-Pearson on n=6.* DS-1: the six probes are conformance
   checks like the rest of suite C, not a sampled evaluation. No bounds
   are computed or displayed.

## Implementation plan (one commit, no push)

1. `test/stub-memory-skill/bin/memory-guard` (new): lookup-based double
   per AR-1; `+x`; header documents the five-rule fidelity contract and
   the deliberate difference from the real tool (AR-2).
2. `bin/leakage-audit`: suite-A loops gain `bin/memory-guard`
   (present/executable, parses); suite C renamed; new `guard_expect`
   helper (`timeout -k 10 30`, rc comparison, suggestion on mismatch);
   six probes with `MEMORY_FIGURE_ALLOWLIST` pointed at `/tmp` files;
   probe names prefixed `memory-guard: `.
3. `references/gate-interface.md`: additive "Write-time interface
   (memory-guard)" section; `contract_version` stays 1.
4. `references/attack-surface.md` D1/D2: "verified by red-team (suite C
   write-time probes)".
5. `references/test-matrix.md` D1/D2 coverage column: replace the
   "vacuous" note with the probe description.
6. `bin/leakage-report`: `tested_blurb` for C — derive static vs probe
   counts from check-name prefixes; mention the write-time probes and the
   allowlist exercise.
7. `.github/workflows/validate.yml`: syntax-check list + the new double;
   `@@@ TOTAL 83 0 4` → `@@@ TOTAL 91 0 4`; pin comment updated.
8. `SKILL.md` "What it checks": write-time guard item.
9. `test/stub-memory-skill/README.md`: double paragraph (E2 labeling).
10. `CHANGELOG.md` + `ITERATIONS.md`: iteration-10 entry; backlog updated
    (memory-guard item moved off; live-fire CI assertions, evasion corpus,
    residual source-of-truth, SECURITY.md/templates recorded as post-loop).

## Validation bar

- `bash -n` on every touched/new script.
- Stub: `bin/leakage-audit` CLEAN (`@@@ TOTAL 91 0 4` in CI-equivalent
  env), `bin/adversarial-run` 36/36, `build-blockset.sh --check` current.
- Real: `bin/leakage-audit` CLEAN, `bin/adversarial-run` 36/36.
- Report regenerated; desktop + mobile screenshot QA in local headless
  Chrome; card C blurb verified against the run.
- One commit: "Iteration 10: verify the write-time guard (memory-guard probes)". No push.
- Public examples stay synthetic (no new tokens; allowlist fixtures are
  synthetic fixture lines in /tmp).
