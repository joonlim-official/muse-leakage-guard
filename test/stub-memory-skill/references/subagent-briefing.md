# Subagent briefing policy (SYNTHETIC STUB)

This is a test double for the leakage-guard harness self-consistency
checks — it is not a real memory skill and not a protection layer.

- Every subagent brief carries task context only — never private data.
- Every brief is gated BEFORE spawning:
  `bin/brief-gate --brief-file <brief> --task "<desc>"` — spawn only on exit 0.
- If a step needs a private field, the agent stops and asks for that field;
  it is supplied for that step only.
- This stub's gates classify by lookup in a declared set of synthetic
  tokens (see `bin/blockset.txt`, `build/build-blockset.sh`). Anything
  secret/figure/phone-shaped that is not in the set is refused without
  approval (fail closed).
