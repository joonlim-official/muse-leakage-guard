# Attack surface — private memory leakage paths

Every path by which private data could leave the user's private surfaces,
the control that covers it, and how `bin/leakage-audit` verifies it.
Free-share zones (no gate needed): the user's Google Drive, their Notion
notes, and within the Muse account (chat, memory, dashboard).

## Gated paths (technical enforcement)

| # | Path | Control | Verified by |
|---|------|---------|-------------|
| 1 | Gmail `+send` / `+reply` / `+forward` | `bin/shims/hatch_gws_cli` → `egress-gate` (subject+body) | red-team: secret/ssn/figure/clean via shim; fake real binary must not fire on block |
| 2 | Gmail raw `users messages send` | shim decodes base64 `raw` MIME, then gates | red-team: SSN inside encoded MIME → blocked |
| 3 | Gmail `--draft` / `--dry-run` | intentionally NOT gated (never leaves the account) | passthrough test: gated content with `--draft` still reaches the real binary |
| 4 | Messenger `send` / `edit` | `bin/shims/hatch_messenger_cli` → `egress-gate` (stdin text) | red-team via `--text-stdin`; stdin replay verified on allow |
| 5 | Drive `permissions create` (sharing with others) | shim refuses unless `MOCHI_EGRESS_APPROVED=1` | red-team: refused (2) without approval, passes with it |
| 6 | Other Drive ops (read/write own files) | free-share zone, pass through | passthrough test |
| 7 | Subagent / browser-task briefs | `bin/brief-gate` before spawning (mandate) | red-team on brief-gate; static check that the mandate exists in AGENTS.md |
| 8 | Public skill commits | `memory-egress-check` + `memory-audit` check | audit run green; static check of audit wiring |

## Policy-covered paths (no technical choke point)

| # | Path | Control | Verified by |
|---|------|---------|-------------|
| 9 | Browser-task sends (separate VM, shims can't reach) | brief carries egress rule + stop-and-ask paragraph; skill send-approval rule | static: briefing reference exists; reported as residual every run |
| 10 | Absolute-path bypass (`/opt/hatch/bin/hatch_gws_cli …`) | forbidden by AGENTS.md mandate | reported as residual; cannot be technically prevented without moving system binaries (out of scope) |
| 11 | Voice calls (phone tool) | per-call confirmation flow | documented; out of text-gate scope |
| 12 | Shared artifacts / pasted content | manual `memory-egress-check` before sharing | documented workflow |

## In-account paths (free-share zones, must NOT be gated)

| # | Path | Why free |
|---|------|----------|
| 13 | Chat with the user | within the Muse account |
| 14 | Memory files (`MEMORY.md`, topics, trace) | within the Muse account; guarded at write time by `memory-guard` |
| 15 | Finance dashboard (local) | within the Muse account; private local surface |
| 16 | Google Drive writes, Notion writes | user's own surfaces |

## What "comprehensive" means here

A new exfiltration path is handled by: (1) adding a row to this table,
(2) adding the control (gate or policy), (3) adding the corresponding
test to `bin/leakage-audit` and the expectation to
`references/test-matrix.md`. A path with no row is an unexamined path —
that is the failure mode this skill exists to prevent.
