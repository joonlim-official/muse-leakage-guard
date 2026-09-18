# Iteration-10 review — Product designer (report UX)

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY; read the report generator (`bin/leakage-report`,
851 lines) and a generated report (`hidden_files/reports/
leakage-validation-20260917-204438-9012.html`); no repo writes.

**Lens:** plain-language honesty of the HTML report; what changes when
suite C gains behavioral probes.

## Verdict summary

**3 findings: 1 P2, 2 P3.** No new visual defects found — iterations 5 and
8 did their work (tri-state callouts, skip link, red-card pre-expansion,
focus styles all present in the generated HTML). The findings are all about
keeping the report honest *through* the iteration-10 change.

## Findings

### [STATIC][P2] DES-1 — suite C's "Checked:" blurb becomes false when probes land

**What.** `tested_blurb()` for letter C currently renders: "N static checks
on the protection wiring (agent-manual mandates, briefing policy, cron
shim-PATH wiring, scenario coverage map, public-repo denylist scan, fixture
purity) — N passed." The moment write-time probes join suite C, "static
checks" is wrong and the parenthetical enumeration is incomplete. The
report's core promise ("every blurb derived from the actual run") requires
this string to change in the same commit: e.g. "N checks on the protection
wiring (agent-manual mandates, briefing policy, cron shim-PATH wiring,
scenario coverage map, public-repo denylist scan, fixture purity) plus
M write-time guard probes over synthetic fixtures (secret/figure content
scanned by bin/memory-guard; allowlist exemption exercised)". The counts
should be derived (len of probe checks vs static checks), not hardcoded —
the audit can tag probe check names with a stable prefix like
"memory-guard: " and the report can count them from the sentinels.

### [STATIC][P3] DES-2 — suite C rename

**What.** Same as PM-2 from the design side: "Attack-surface coverage
(static checks)" → "Attack-surface coverage (controls verified in place)".
The card heading is the user's mental model of what ran; a mixed
static+behavioral suite under a "static" heading is a small lie of exactly
the kind this repo polices. One-line change in `begin_suite`, zero visual
impact.

### [STATIC][P3] DES-3 — new checks reuse the existing card; verify visually

**What.** The six new suite-C checks render inside the existing card C
disclosure — no new interactive surface, no new a11y semantics. The only
design risk is evidence-line length: probe check names must stay short
enough to wrap cleanly at 48 columns in the terminal audit too
(`wcheck` folds at WIDTH-4, so long names wrap rather than break — safe,
but keep names terse). Recommend the standard screenshot QA (desktop +
mobile) on the regenerated report to confirm card C still reads cleanly
with the longer evidence list.

## Not findings

- Tri-state callout for C ("N of M green") handles mixed static+probe
  checks without change — no tri-state grouping needed outside suite B.
- No new glossary terms introduced by the probe set ("write-time guard" is
  plain language already used in D1/D2).
