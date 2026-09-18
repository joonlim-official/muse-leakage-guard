# Gate/shim interface contract — version 1

```yaml
contract_version: 1
```

This document pins the CLI contract that `muse-leakage-guard` validates.
Any memory skill — the real one, or the synthetic stub in
`test/stub-memory-skill/` — must honor it for the audit to mean anything.
A target declares the version it implements: the synthetic stub via
`test/stub-memory-skill/.synthetic-stub` (`interface_version=1`); for real
skills the contract names no declaration point yet (TBD — until one is
named, the audit skips the version check for real targets rather than
pretending to enforce it). The audit (`bin/leakage-audit`,
`AUDIT_INTERFACE_VERSION`) enforces the declared version as its first
suite-A check: a mismatch yields one FAIL and no contract-shaped check
runs, because results against the wrong contract are meaningless.

## Binaries

| Binary | Path in the skill |
|---|---|
| Egress gate | `bin/egress-gate` |
| Brief gate | `bin/brief-gate` |
| Detector | `bin/memory-egress-check` |
| Write-time guard | `bin/memory-guard` |
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

Non-verdict errors are not verdicts: usage errors, missing inputs,
undecodable payloads, and missing interpreters must fail closed — surface
as block (1) or another nonzero code, but NEVER as 0 (allow) and NEVER as
2 (review), because approval can downgrade a 2 to 0 and a broken detector
must not be approvable.

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

## Write-time interface (memory-guard)

```
bin/memory-guard [path ...]
bin/memory-guard -h|--help
```

Pre-write / audit scan for memory content. Same 0/1/2 contract as the
detector: 0 = clean, 1 = secret block-tier (hard block — the write is
refused until fixed), 2 = figure- or personal-data-shaped content flagged
for human review. Env: `MEMORY_FIGURE_ALLOWLIST` (default
`<memory-root>/memory/.figure-allowlist`) holds installation-specific
fixed-string patterns, one per line; figure- and personal-data matches
containing any pattern are excluded from the review flag. **The allowlist
never exempts secrets** — a secret-shaped match is block-tier regardless
of the allowlist. Operational failures (no paths given where the
implementation requires them, unreadable inputs) fail closed: nonzero,
never 0. This section is additive: it extends the contract without
changing any existing semantics, so `contract_version` stays 1.

## Shim interception contract

The shims must sit FIRST on `PATH` so they shadow the real CLIs:

```
export PATH="<skill>/bin/shims:$PATH"
```

- Gmail `+send`, `+reply`, `+reply-all`, `+forward`: subject/body/to pass
  `egress-gate`.
- `--draft` / `--dry-run` as flags pass through UNGATED (never leave the
  account); as flag values (e.g. `--subject --draft`) they are gated content —
  a flag-looking value must not skip the gate.
- A literal `--` ends option parsing but does not end gating: positionals
  after `--` are collected as message content and gated like any body.
- Raw API path (`gmail users messages send` with `{"raw": "<base64url>"}` on
  stdin, or `--params`/`--json` carrying it): the MIME is base64-decoded and
  gated before delegation. If the payload is malformed, undecodable, or no
  Python interpreter is available to decode it, the shim refuses (nonzero,
  never 0/2) — gating opaque bytes is not an option.
- `gmail users drafts send`: draft creation is ungated by design (never
  leaves the account), but the send step fetches the draft read-only,
  base64-decodes its body, and gates the decoded content. A draft that
  cannot be fetched refuses closed.
- `gmail users settings` mutations (`updateAutoForwarding`, delegates,
  filters, sendAs): refused (rc=2) unless approved — they redirect where
  mail goes. Read-only settings gets pass through.
- `drive permissions create` (positional subcommand): refused (rc=2) unless
  approved — sharing with others is never a free-share zone.
- Messenger `send` / `edit`: the message (flag or stdin) passes
  `egress-gate`; on allow, stdin is replayed to the delegate byte-identical.
  The `--` end-of-options rule applies here too.
- Abnormal detector exits (anything outside {0,1,2}: crash, kill, missing
  binary) fail closed: the gates surface rc=1 (blocked), never 0 and never
  2 (a broken detector must not be approvable).
- Delegation: the shim execs the next same-named binary on `PATH` after
  its own directory, or `$MOCHI_REAL_HATCH_GWS_CLI` /
  `$MOCHI_REAL_HATCH_MESSENGER_CLI` when set. No delegate → exit 127
  (fail closed, never silently drop).
- The delegate must be a second, distinct executable — the shim resolves
  both paths canonically (symlinked/aliased spellings included) and refuses
  a delegate that is itself (fail closed: a self-delegate would exec-loop);
  the audit asserts distinctness the same way.

## What the audit does NOT promise

- A 36/36 adversarial figure against the synthetic stub proves harness
  self-consistency (the plumbing, parsing, and labels work), NOT detector
  quality. Only a run against the real installation speaks to protection.
- The stub detector (`test/stub-memory-skill/bin/memory-egress-check`)
  classifies by lookup in a declared set of synthetic tokens; it is a test
  double and must never be deployed as a protection layer. The same holds
  for the stub write-time guard (`test/stub-memory-skill/bin/memory-guard`),
  which mirrors the write-time interface above with lookup-based verdicts.
