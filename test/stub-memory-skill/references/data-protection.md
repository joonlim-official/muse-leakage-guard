# Data protection (SYNTHETIC STUB)

This is a test double for the leakage-guard harness self-consistency
checks — it is not a real memory skill and not a protection layer.

## Free-share zones

Within this stub's synthetic world, the free-share zones are: the stub's
own fixtures directory, the harness working directory, and the agent's
chat transcript. Everything else is default-deny and must pass
`bin/egress-gate` before any send.

## Rules

- `bin/egress-gate --content-file <file> --context <ctx>` — exit 1 (block)
  never sends; exit 2 (review) needs `MOCHI_EGRESS_APPROVED=1`.
- Approval is only ever granted by the harness operator for declared
  synthetic payloads, never by a scheduled worker.
- Every gate decision is appended to the stub's gate log
  (`$MOCHI_EGRESS_LOG`, default `~/.stub-egress.log`).
