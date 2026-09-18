# Iteration-10 review — Privacy engineer

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY (this review file only); no live-fire; no sends;
synthetic fixtures only; every shell context began with the shim PATH
export. Spawning was unavailable in this session; this review was conducted
in-house under the brief's read-only constraints.

**Lens:** data minimization in the validator itself (does the harness
republish what it detects?), correctness of the write-time privacy
control, and exemption-path discipline.

**Baselines:** stub audit 86/0/1 CLEAN; real audit 82/0/5 CLEAN; adversarial
36/36 both targets (measured this session).

**Severity rubric:** P1 = privacy control claimed but unverified, or the
validator amplifying a leak. P2 = exemption path without a test. P3 =
hygiene/doc.

## Verdict summary

**5 findings: 1 P1, 2 P2, 2 P3.** The P1 converges with the security
review: the write-time control (`memory-guard`, D1/D2) is the only
protection-plane control with *zero* harness coverage. Everything the
validator republishes is properly minimized (iter-9's counts-only hygiene
holds — I re-verified suite C/D evidence paths and the report's
`plain_evidence`/`scrub` pipeline). The remaining privacy work is
exemption-path discipline: both allowlists (`.egress-allowlist`,
`.figure-allowlist`) have semantics the audit never exercises.

## Findings

### [EXEC][P1] PRI-1 — the write-time privacy control is never validated

**What.** D1 ("secrets written into memory files — PROTECTED at write
time") and D2 ("financial figures written into memory — APPROVAL-GATED")
rest on `bin/memory-guard`, which the audit never invokes. The daily memory
refresh writes to the memory tree every morning (~9:19 AM), so the write
path is the highest-frequency privacy control in the system — and the only
one with no probe. I confirmed `memory-guard` is safely probe-able: with
explicit fixture paths and a controlled `MEMORY_FIGURE_ALLOWLIST`, it
returns rc=1 (secrets), rc=2 (figures/PII), rc=0 (clean), and rc=0 for an
allowlisted figure, without touching the real memory tree or the real
allowlist. Probing must keep those two properties (explicit paths,
controlled allowlist) or the probe itself becomes a privacy incident —
scanning the default tree would print real memory content into audit logs.

**Recommendation.** Same as SEC-1: suite-C probes + suite-A presence
checks + stub double + contract section. The probe design must be
privacy-reviewed: fixtures only, `/tmp` allowlist, stdout discarded, rc
compared.

### [STATIC][P2] PRI-2 — `.figure-allowlist` never-exempts-secrets rule is untested

**What.** The real `memory-guard` applies the allowlist only to the figure
and PII sections; secrets hard-block regardless. The audit never asserts
this. A regression (or a well-meaning "improvement") that extended the
allowlist to secrets would silently downgrade the write-time block tier to
an exemption list — the exact shape of a quiet privacy regression. The
allowlisted-secret probe (expect rc=1) in the SEC-1/PRI-1 probe set covers
this directly.

### [STATIC][P2] PRI-3 — `.egress-allowlist` block-tier immunity is untested

**What.** The send-plane allowlist (`MEMORY_EGRESS_ALLOWLIST` in the real
`memory-egress-check`) is digit-normalized and ≥7 digits. The audit's only
reference is a suggestion string. If the allowlist were ever applied to
block-tier verdicts, the send plane's hard block would become bypassable by
anyone who can write the allowlist file — and nothing in the harness would
notice. Recommend a probe: allowlisted secret-shaped token must still
return rc=1. (Secondary to PRI-1/PRI-2; the send plane at least has probes.)

### [STATIC][P3] PRI-4 — evidence hygiene re-verified, holds

**What.** Positive confirmation, not a gap: I re-read the suite-C
memory-audit path (counts only, no verbatim findings), suite-D contexts
(channel + verdict counts, contexts withheld), the report's `scrub()` email
redaction and `plain_evidence()` invoked=0/1 replacements, and the fake
delegates' argv-sha256 evidence. No private-data republication path found.
The one residual: `send_expect` failure evidence prints `head -3` of the
fake binary's stdout — the fake binaries are designed to hash argv, but a
*future* fake delegate that echoed argv would leak fixture content into
failure logs. Recommend a code comment on the fake delegates ("never echo
argv; hash only") — cheap insurance.

### [STATIC][P3] PRI-5 — fixture-purity SHAPES vs memory-guard PII_RE

**What.** The audit's fixture-purity SHAPES manifest is "aligned with the
stub's candidate shapes" (comment in `bin/leakage-audit`). The real
`memory-guard`'s PII_RE includes bare 16-digit card and 15-digit Amex
shapes that the write-time probes would exercise via `card.txt`. The
purity check already covers those shapes (verified: `card_bare`,
`amex_15` in SHAPES). No action — recorded so the alignment is explicit
when the probe set lands.

## Not findings

- Suite E's residual list, browser-task VM, transcript inheritance: already
  catalogued; the validator correctly reports rather than hides them.
- The stub double's "never auto-allow an undeclared shape" philosophy is
  the privacy-safe default for a test double; keep it.
