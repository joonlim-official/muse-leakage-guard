# Test matrix — what each check proves

Every check in `bin/leakage-audit` maps to an attack-surface row
(`references/attack-surface.md`). Fixtures are synthetic by design
(`bin/fixtures/`): `123-45-6789`, `4111-1111-1111-1111`,
`sk-testfakekey…`, `415-555-0132` — shaped to trip the detectors,
belonging to nobody.

## A. Installation integrity

| Check | Proves |
|-------|--------|
| gates + shims exist and are executable | the protection layer is installed, not just documented |
| `bash -n` on all scripts | no syntax rot; the gate that can't parse can't protect |
| shim dir resolves first for `hatch_gws_cli` / `hatch_messenger_cli` | interception actually happens (PATH order is the mechanism) |
| real binary discoverable behind the shim | the shim can delegate after allowing; a shim that can't find its target fails closed or breaks sends |

## B. Gate effectiveness (red team, fake real binaries — nothing is ever sent)

| Payload → target | Expected | Proves |
|---|---|---|
| secret/ssn/card → `egress-gate` | exit 1 | block-tier detection fires on direct gate use |
| figure/phone → `egress-gate` | exit 2 | review-tier detection fires; nothing auto-allows |
| clean → `egress-gate` | exit 0 | no false positives on ordinary text |
| same six → `brief-gate` | 1/1/1/2/2/0 | briefs are held to the same bar as sends |
| secret body → gmail `+send` shim | blocked, real binary silent | interception + gate compose correctly |
| figure body → gmail `+send` shim | refused (2); allowed with `MOCHI_EGRESS_APPROVED=1` | approval override path works and is the *only* way through |
| ssn → gmail `+reply` shim | blocked | all send subcommands are covered, not just `+send` |
| card inside base64 MIME → raw `users messages send` | blocked | encoded payloads are decoded before the check |
| secret → gmail `+send --draft` | passes through | drafts (never leave the account) are correctly NOT gated |
| secret → messenger `send` via stdin | blocked, real binary silent | stdin capture + gate compose correctly |
| clean → messenger `send` | allowed, stdin replayed byte-identical | the gate doesn't corrupt legitimate sends |
| drive `permissions create` | refused (2); allowed with approval | sharing with others is never a free-share zone |
| drive `files list`, gmail `+triage` | pass through | reads and own-Drive ops are untouched |

## C. Coverage gaps (static checks)

| Check | Proves |
|-------|--------|
| agent manual mentions shims + brief-gate | the mandate exists where every agent reads it |
| `references/subagent-briefing.md` exists with the standard paragraph | the need-to-know policy is documented and copy-paste ready |
| `references/data-protection.md` defines free-share zones | the boundary (what's free vs. gated) is written down |
| cron prompt dirs contain the shim PATH export | scheduled workers inherit interception |
| `memory-audit` green (opt-in via `MOCHI_MEMORY_AUDIT=1`) | no private data already sitting where it shouldn't |

## D. Audit-log review

| Check | Proves |
|-------|--------|
| recent `BLOCKED` entries listed | block-tier attempts are visible (something tried) |
| `approved-override` entries listed | every override is surfaced for human review — overrides are the highest-risk events |
| verdict distribution | the gate is actually being exercised, not bypassed |

## E. Known residuals (reported every run, never silent)

Browser-task sends, absolute-path bypass, voice calls, and the
mandate-based (not syscall-intercepted) brief-gate step are restated on
every run so they can't quietly become assumed-safe.

## F. Scenario coverage map

Every scenario in `references/attack-surface.md` (`### XN.`) must have a
row here. The audit (suite C) fails if a scenario is missing — a scenario
without a mapped check is a finding, not an oversight.

| Scenario | Verdict | Covered by |
|---|---|---|
| A1 email send with secret | PROTECTED | B: secret → egress-gate exit 1; gmail `+send` shim blocked, real binary silent |
| A2 email send with SSN/card | PROTECTED | B: ssn → egress-gate exit 1; gmail `+reply` shim blocked |
| A3 email send with figure/phone | APPROVAL-GATED | B: figure/phone → egress-gate exit 2; approval override is the only way through |
| A4 raw Gmail API send (MIME) | PROTECTED | B: card inside base64 MIME → raw `messages.send` blocked |
| A5 Gmail draft with private data | correctly ungated | B: `--draft` with secret passes through (drafts never leave the account) |
| A6 Messenger send/edit | APPROVAL-GATED | B: messenger send secret blocked; clean passes; stdin replayed byte-identical |
| A7 cron job without shim PATH | PROTECTED | C: cron prompt dirs must wire the shim PATH export |
| A8 absolute-path shim bypass | POLICY-ONLY | E: restated as residual every run |
| B1 Drive file shared externally | APPROVAL-GATED | B: `drive permissions create` refused w/o approval, allowed with it; `drive files list` passes (free zone) |
| B2 public Git push with private data | POLICY-ONLY | C: tracked files of both public repos scanned against the egress denylist |
| B3 shared artifact with private data | POLICY-ONLY | C: same denylist scan (public repo content) |
| B4 attachment carrying private content | OPEN GAP | E: restated as residual; suggested remediation: attachment-path inspection in `egress-gate` |
| C1 subagent brief with secrets | PROTECTED | B: the six payloads through `brief-gate` → 1/1/1/2/2/0 |
| C2 subagent brief with figures/PII | APPROVAL-GATED | B: same brief-gate run |
| C3 transcript inheritance | POLICY-ONLY | C: brief-gate mandate in agent manual; E: restated as residual |
| C4 browser task outside shim reach | POLICY-ONLY | E: restated as residual |
| C5 prompt injection toward exfiltration | PROTECTED (in depth) | B: gate red-team over injected-shaped payloads; C: brief-gate + shim mandates |
| D1 secrets written to memory | PROTECTED | C: memory-audit opt-in; `memory-guard` pre-write scan |
| D2 figures written to memory | APPROVAL-GATED | C: memory-audit opt-in; `memory-guard` flags figures for review |
| D3 memory read by unauthorized party | PROTECTED (platform) | platform boundary — no in-repo mechanical test possible; documented here |
| E1 public info treated as private | anti-over-gating | B: clean → exit 0; adversarial-run false-positive traps; public-number allowlist |
