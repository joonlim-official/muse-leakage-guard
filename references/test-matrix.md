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
