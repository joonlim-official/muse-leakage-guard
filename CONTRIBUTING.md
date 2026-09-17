# Contributing to muse-leakage-guard

Thanks for helping harden the leakage guard. This repo is small on purpose —
please keep it that way.

## Ground rules

- **Validation-only.** This skill audits controls and suggests remediation.
  It never patches another system, and it never sends real data anywhere.
- **Synthetic fixtures only.** Every secret-shaped value in `bin/fixtures/`,
  `bin/adversarial-corpus.txt`, and `test/stub-memory-skill/bin/fixtures/`
  must be a declared synthetic value in `bin/fixtures/SYNTHETIC.txt`
  (belonging to nobody). The audit's fixture-purity check enforces this —
  add the token to `SYNTHETIC.txt` *first*, get it reviewed, then use it.
- **No real installation needed.** CI and local validation run against the
  synthetic stub (`test/stub-memory-skill/`) — see "Quickstart" below.
  Never commit `local.env`, credentials, or private literals.

## Quickstart (stub-first, no private setup)

```bash
# 1. Point the harness at the synthetic stub
export PERSONAL_MEMORY_SKILL="$PWD/test/stub-memory-skill"
export MOCHI_AGENTS_FILE="$PWD/test/stub-memory-skill/AGENTS.md"
export PATH="$PERSONAL_MEMORY_SKILL/bin/shims:$PATH"
# 2. The audit needs a second executable CLI behind each shim on PATH.
#    (In CI these are inert fakes; locally any second executable works —
#    it is never invoked with real data in simulated mode.)
# 3. Run the full loop
bash -n bin/leakage-audit && bash -n bin/leakage-report && bash -n bin/adversarial-run
bin/leakage-audit          # expect CLEAN
bin/adversarial-run        # expect every corpus case matched
bin/leakage-report         # writes hidden_files/reports/*.html (gitignored)
```

To validate your **own** installation instead, point
`PERSONAL_MEMORY_SKILL` at it (and `MOCHI_AGENTS_FILE` at your agent
manual). The audit labels stub targets as `SYNTHETIC STUB` and refuses
live-fire against them.

## What CI green means

`.github/workflows/validate.yml` runs the audit + adversarial suite
against the synthetic stub. Green proves **harness self-consistency**
(plumbing, parsing, labels, report honesty) — it does **not** prove any
real installation is protected. The HTML report says this on its face.

## Adding an attack-surface scenario

Follow the coverage discipline in `references/attack-surface.md`:

1. Add the scenario (`### X9. ...`) with its verdict.
2. Add the control (gate or policy).
3. Add the test to `bin/leakage-audit` and the expectation row to
   `references/test-matrix.md` — the audit fails if any scenario is
   unmapped.

## PR checklist

- [ ] `bash -n` on every touched shell script
- [ ] `bin/leakage-audit` CLEAN against the stub (and your install, if touched)
- [ ] `bin/adversarial-run` — every corpus case matched
- [ ] `test/stub-memory-skill/build/build-blockset.sh --check` passes
      (if you touched the corpus or stub fixtures)
- [ ] New fixtures declared in `bin/fixtures/SYNTHETIC.txt`
- [ ] No private literals, no `local.env`, no real send targets
