# Agent manual (SYNTHETIC STUB)

This directory is a test double for the leakage-guard harness
self-consistency checks — it is not a real memory skill.

Every agent shell context that targets this stub must start with:

    export PATH="<stub>/bin/shims:$PATH"

so that `hatch_gws_cli` / `hatch_messenger_cli` resolve to the stub shims
first. Never invoke a delegate binary by absolute path to dodge the gate.

Every subagent brief must pass the brief gate before spawning:

    bin/brief-gate --brief-file <brief> --task "<desc>"

Spawn only on exit 0.
