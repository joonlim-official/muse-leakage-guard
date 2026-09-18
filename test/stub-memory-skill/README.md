# Synthetic stub memory skill — test double for the leakage guard

This directory is a **test double**, not a memory skill and not a
protection layer. It exists so the leakage-guard audit, the adversarial
suite, and CI can validate the *harness* — plumbing, parsing, labels,
report honesty — against a deterministic target, without needing the
owner's real installation or any private data.

## What this stub is

- A **test double** with the same gate/shim *interface* as the real skill
  (interface version 1 — see
  `../../references/gate-interface.md`): `bin/egress-gate`,
  `bin/brief-gate`, `bin/memory-egress-check`, `bin/memory-guard`,
  `bin/shims/hatch_gws_cli`, `bin/shims/hatch_messenger_cli`.
- The marker `.synthetic-stub` (`kind=synthetic-stub, interface_version=1`)
  tells `bin/leakage-audit` and `bin/leakage-report` this is a stub target;
  audit output and HTML reports label it as such and refuse live-fire
  against it.

## What this stub is NOT

- **Not a detector.** `bin/memory-egress-check` does not detect secrets —
  it extracts candidates with public shape patterns and looks their
  sha256 up in `bin/blockset.txt`, the declared set of synthetic
  block-tier tokens. A candidate not in the set is refused as review-tier
  (fail closed), but that is a conservative default, not a judgment. The
  same holds for `bin/memory-guard`: it mirrors the write-time interface
  (`references/gate-interface.md`) with lookup-based verdicts — a declared
  token blocks (rc=1), any other secret/figure/phone-shaped content fails
  closed to review-tier (rc=2), and the figure allowlist never exempts
  secrets. It deliberately differs from the real tool (which blocks *any*
  secret-shaped token by pattern); do not read its rc=2-on-unknown as the
  real tool's rc=1-on-unknown.
- **Not protection.** Never deploy this directory as a protection layer,
  never point it at real private data, never claim its 36/36 adversarial
  figure as evidence of real detection quality. A 36/36 against this stub
  proves the *harness* is self-consistent — nothing more.
- **Not the real gates.** It shares the CLI contract, never the detection
  logic (duplicated logic would let one bug silence both).

## How the block set is built

`build/build-blockset.sh` hashes the secret-shaped tokens from every
adversarial-corpus case with `want=1` plus the stub's own block-tier
fixtures, using the same `bin/patterns.sh` the runtime extractor uses —
so the build and the verdict can never disagree. Run with `--check` in
CI to fail on a stale `bin/blockset.txt`.

## Using it

```bash
export PERSONAL_MEMORY_SKILL="$PWD"          # from this directory
export PATH="$PWD/bin/shims:$PATH"           # stub shims first
export MOCHI_AGENTS_FILE="$PWD/AGENTS.md"    # stub agent manual
# the audit needs a second executable CLI behind each shim on PATH
# (CI provisions inert fakes; see .github/workflows/validate.yml)
bin/leakage-audit   # from the muse-leakage-guard repo root
```
