# Iteration-10 review — Open-source maintainer

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY; read stub README, CONTRIBUTING.md, CHANGELOG.md,
ITERATIONS.md, SKILL.md, README.md suite listings. No repo writes.

**Lens:** contributor clarity, honest public claims, and that the
test-double discipline (E2) extends to any new double.

## Verdict summary

**4 findings: 1 P2, 3 P3.** The P2 is E2 discipline for the new double;
the rest is changelog/contract hygiene for the commit.

## Findings

### OSS-1 (P2) — the new stub double must carry the E2 labeling

**What.** Scenario E2 ("stub-target validation mistaken for real
protection validation") is PROTECTED "by labeling + refusal." That
protection is per-artifact: the existing double is labeled in its header,
the stub README, the audit's `target-kind` line, and the report banner. A
new `bin/memory-guard` double must get the same treatment at creation:
header comment stating it is a test double implementing the write-time
interface section of `references/gate-interface.md`, that its verdicts
come from lookup in the declared synthetic set (not detection), and that it
must never be deployed as a protection layer; plus one paragraph in
`test/stub-memory-skill/README.md`. If the double ships without this, E2's
"PROTECTED (by labeling)" claim becomes partially false — a labeling
regression, which is exactly what E2 exists to prevent.

### OSS-2 (P3) — docs that must change in the same commit

**What.** The one-commit discipline means the commit must be
self-consistent for a public reader. Checklist for the iteration-10 commit:
- `CHANGELOG.md`: new "Iteration 10" entry (what/why/validation).
- `ITERATIONS.md`: new section 10 + move the memory-guard item off the
  backlog; record the explicitly deferred items (live-fire CI assertions,
  evasion corpus, SECURITY.md/templates) as post-loop backlog, not silent
  drops.
- `references/gate-interface.md`: additive write-time interface section
  (SYS-1); `contract_version` stays 1.
- `references/test-matrix.md`: D1/D2 coverage column — replace "not
  harness-verified where CI runs" with the suite-C probe description.
- `references/attack-surface.md`: D1/D2 details — "verified by red-team
  (suite C write-time probes)" instead of the current bare claim.
- `SKILL.md` "What it checks": extend item 3 or add item 6 for the
  write-time guard probe + allowlist exercise.
- `test/stub-memory-skill/README.md`: the double (OSS-1).
- `.github/workflows/validate.yml`: syntax-check list + `@@@ TOTAL`
  83 → 91 + the pin comment (SRE-1, SRE-4).
- `bin/leakage-report`: `tested_blurb` for C (DES-1).

### OSS-3 (P3) — public examples stay synthetic

**What.** Re-verified: the probe set uses only `bin/fixtures/*.txt`
(declared in `SYNTHETIC.txt`) and `/tmp` allowlist files containing
synthetic fixture lines. No new synthetic tokens are introduced, so
`SYNTHETIC.txt` and the fixture-purity SHAPES need no changes. The
allowlist probe must not use the real `~/.figure-allowlist` (it contains
user-reviewed literals) — the probe sets `MEMORY_FIGURE_ALLOWLIST` to a
`/tmp` file. State this in the probe's code comment; a future editor
" simplifying" the probe to the default allowlist would leak real literals
into audit logs.

### OSS-4 (P3) — CONTRIBUTING quickstart unaffected

**What.** `CONTRIBUTING.md`'s stub-first quickstart runs the audit and the
adversarial suite; both commands are unchanged by this iteration (no new
flags, no new env vars required — `MEMORY_FIGURE_ALLOWLIST` is set by the
audit itself for the probes). No doc change needed — verified, not assumed.
