# Gate/shim interface contract — version 1

This document pins the CLI contract that `muse-leakage-guard` validates.
Any memory skill — the real one, or the synthetic stub in
`test/stub-memory-skill/` — must honor it for the audit to mean anything.
`test/stub-memory-skill/.synthetic-stub` declares `interface_version=1`.

## Binaries

| Binary | Path in the skill |
|---|---|
| Egress gate | `bin/egress-gate` |
| Brief gate | `bin/brief-gate` |
| Detector | `bin/memory-egress-check` |
| Gmail/Drive shim | `bin/shims/hatch_gws_cli` |
| Messenger shim | `bin/shims/hatch_messenger_cli` |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | clean — allowed |
| 1 | block-tier (secrets, credentials, SSN, card numbers) — hard block, never sends |
| 2 | review-tier (figures, phone numbers, denylisted literals) — refused unless approved |

Approval override: `MOCHI_EGRESS_APPROVED=1` (or `--approved`) turns a
review-tier 2 into 0. It must NEVER turn a block-tier 1 into 0.

## `bin/egress-gate`

```
bin/egress-gate --content-file <file> --context <label> [--approved]
```

- `--content-file <file>` or stdin: the payload to scan.
- `--context <label>`: short label for the gate log (e.g. `gmail +send`).
- `--approved` or `MOCHI_EGRESS_APPROVED=1`: approve review-tier only.
- Logs every decision (timestamp, context, verdict) to
  `$MOCHI_EGRESS_LOG` (default `~/workspace/memory-sync/egress-gate.log`).

## `bin/brief-gate`

```
bin/brief-gate --brief-file <file> --task <description> [--approved]
```

Same exit-code contract as `egress-gate`, applied to subagent briefs.
`--brief-file` is required.

## `bin/memory-egress-check`

```
bin/memory-egress-check [file ...]
... | bin/memory-egress-check
```

Scans files, or stdin when no files are given. Same 0/1/2 contract.

## Shim interception contract

The shims must sit FIRST on `PATH` so they shadow the real CLIs:

```
export PATH="<skill>/bin/shims:$PATH"
```

- Gmail `+send`, `+reply`, `+forward`: body/to pass `egress-gate`.
- `--draft` / `--dry-run`: pass through UNGATED (never leave the account).
- Raw API path (`gmail users messages send` with `{"raw": "<base64url>"}` on
  stdin): the MIME is base64-decoded and gated before delegation.
- `drive permissions create`: refused (rc=2) unless approved — sharing with
  others is never a free-share zone.
- Messenger `send` / `edit`: the message (flag or stdin) passes
  `egress-gate`; on allow, stdin is replayed to the delegate byte-identical.
- Delegation: the shim execs the next same-named binary on `PATH` after
  its own directory, or `$MOCHI_REAL_HATCH_GWS_CLI` /
  `$MOCHI_REAL_HATCH_MESSENGER_CLI` when set. No delegate → exit 127
  (fail closed, never silently drop).
- The delegate must be a second, distinct executable — the audit asserts
  this so a shim can never be "tested" against itself.

## What the audit does NOT promise

- A 36/36 adversarial figure against the synthetic stub proves harness
  self-consistency (the plumbing, parsing, and labels work), NOT detector
  quality. Only a run against the real installation speaks to protection.
- The stub detector (`test/stub-memory-skill/bin/memory-egress-check`)
  classifies by lookup in a declared set of synthetic tokens; it is a test
  double and must never be deployed as a protection layer.
