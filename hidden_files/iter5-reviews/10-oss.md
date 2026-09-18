# Iteration-5 review — Open-source community maintainer perspective

Repo: `~/workspace/skills/muse-leakage-guard` · HEAD `e4b2af1`
Reviewer role: open-source community maintainer. Read-only review; no files modified.
Method: mentally cloned the repo (fresh `git archive` of HEAD into `/tmp/walk`,
no `local.env`, no real CLIs provisioned by hand) and followed
`CONTRIBUTING.md`'s quickstart verbatim; read the stub README, gate-interface
contract, CI workflow, CODEOWNERS, and the audit's enforcement checks.

**Privacy note:** this review uses only repo facts. The working tree's
untracked `local.env` (owner's private paths) was not used and is not quoted
here — it is gitignored and absent from the fresh clone, as intended.

## What's strong (keep)

- Stub-first contribution model genuinely works: a stranger can validate the
  whole harness with zero private setup, and the audit's `SYNTHETIC STUB`
  banners plus live-fire refusal make the trust boundary legible.
- CI safety shape is exemplary for outsiders: `pull_request` (not
  `pull_request_target`), `contents: read`, SHA-pinned actions, shallow
  checkout, live-fire variable refusal, and a committed-`local.env` refusal.
- The reviewed-first fixture workflow (`SYNTHETIC.txt` add → review → use)
  is the right discipline; the fixture-purity check is real enforcement.
- Suite B keeps validation out of the real gate log
  (`MOCHI_EGRESS_LOG="$T/gate.log"`), so a contributor's run touches nothing
  in their real home — good.
- CODEOWNERS puts `bin/`, `test/stub-memory-skill/`, `.github/`, and the
  gate-interface contract under the maintainer — a human gate on every
  trust-relevant change.

---

## Findings

### HIGH-1 · No LICENSE file — forking is legally unsafe
**Evidence:** no `LICENSE` file exists in the repo, and the words
license/MIT/Apache/GPL appear in none of `README.md`, `CONTRIBUTING.md`,
`SKILL.md`, `CHANGELOG.md`, `ITERATIONS.md`, or
`references/gate-interface.md` (verified by grep). The repo is public on
GitHub and actively solicits PRs and forks ("Contributors validating a
fork should stay in simulated mode", `README.md`), but without a license
the default on GitHub is all-rights-reserved: a stranger cannot legally
fork or reuse the harness.
**Recommendation:** add a `LICENSE` file (MIT or Apache-2.0 are the usual
fits for a validation harness; maintainer's choice) and a short "License"
section in the README stating the reuse terms explicitly.

### HIGH-2 · Quickstart step 2 is not copy-pasteable; verbatim run fails on a newcomer machine
**Evidence:** `CONTRIBUTING.md` quickstart step 2 says: "The audit needs a
second executable CLI behind each shim on PATH. (In CI these are inert
fakes; locally any second executable works …)" — but gives no command.
The `README.md` quickstart omits the requirement entirely. In `/tmp/walk`
with a PATH containing no real CLIs, `bin/leakage-audit` failed with
exit 1: `✗ [A] real hatch_gws_cli not found on PATH — shim has nothing
to delegate to` (same for `hatch_messenger_cli`). The failure's suggested
remediation ("install the real CLI …") is wrong for stub validation — a
newcomer is pointed at installing real CLIs instead of provisioning inert
fakes like CI does (`.github/workflows/validate.yml`, "Provision inert
delegate CLIs"). Note: CI's provisioning needs `sudo`; nothing shows the
sudo-less local equivalent.
**Recommendation:** add a copy-paste snippet to both quickstarts that
provisions inert fakes in a temp dir without sudo, e.g.:

```bash
mkdir -p "$PWD/.delegates"   # or a mktemp dir; gitignored
for c in hatch_gws_cli hatch_messenger_cli; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$PWD/.delegates/$c"
  chmod +x "$PWD/.delegates/$c"
done
export PATH="$PERSONAL_MEMORY_SKILL/bin/shims:$PWD/.delegates:$PATH"
```

and align the README quickstart with CONTRIBUTING's (both must mention
the delegate step).

### HIGH-3 · The strongest "no real literals" check silently skips for every external contributor
**Evidence:** `bin/leakage-audit` lines 551–566: the B2/B3 denylist check
("no denylisted literals in public repo tracked files") reads the owner's
*private* denylist at `$PERSONAL_MEMORY_ROOT/memory/.egress-denylist`. In
the fresh-home run (`HOME=/tmp/fakehome`) it printed
`@@@ CHECK SKIP no egress denylist [~/memory/.egress-denylist missing or
empty]` and moved on. For any outsider — every GitHub contributor — this
enforcement is simply absent, while the repo's narrative asks them to
trust that "synthetic fixtures only" is enforced. The check that *does*
run for outsiders is the fixture-purity check, whose scope is narrow
(see MEDIUM-1).
**Recommendation:** add a self-contained public check that needs no
private input: verify each `SYNTHETIC.txt` token belongs to a documented
reserved/fictional range (555-01xx numbers are reserved for fiction,
`123-45-6789` is SSA-reserved-never-issued, `4111…` PANs are standard
test ranges, `sk_test_…`/`sk_live_4eC39HqLyjWDarjtT1z` are Stripe's
published documentation examples, `gsk_f4k3…` is visibly synthetic).
Document the provenance *per token* in the `SYNTHETIC.txt` header so a
security-minded stranger can independently confirm "belongs to nobody"
without trusting the maintainer's word — and note in the docs which
checks skip for external contributors vs. the owner.

### MEDIUM-1 · Fixture-purity check's enforced scope is narrower than the repo's hygiene
**Evidence:** the purity check (`bin/leakage-audit`, lines 571–582) scans
only three path patterns: `bin/fixtures/*.txt`,
`bin/adversarial-corpus.txt`, and
`test/stub-memory-skill/bin/fixtures/*.txt`. Illustrations in `README.md`,
`SKILL.md`, `references/attack-surface.md`, `references/test-matrix.md`,
and any future carrier file are unenforced. I scanned every tracked file
against the same `SHAPES` regex: today's hygiene is clean (all tokens are
declared in `SYNTHETIC.txt`), but the *guarantee* doesn't cover those
paths — a well-meaning contributor adding a new illustration to
`references/attack-surface.md` with a fresh token would pass the audit.
**Recommendation:** widen the scan to all `git ls-files` (excluding
`SYNTHETIC.txt` itself and `blockset.txt`, whose lines are sha256 hex),
and have the audit print the enforced scope in the check's evidence so an
outsider knows exactly what "enforced" means rather than inferring it.

### MEDIUM-2 · No documented "extend the stub" workflow
**Evidence:** the stub README explains what the stub *is/isn't*, and
`references/gate-interface.md` pins the contract — but nothing maps the
extension path. A contributor adding a new gate, a new fixture shape, or
a new shim behavior must discover and sequence: `patterns.sh`,
`build/build-blockset.sh` + `--check`, `bin/blockset.txt`,
`SYNTHETIC.txt` (add-first-reviewed), `bin/adversarial-corpus.txt`,
`bin/fixtures/` (guard) vs `test/stub-memory-skill/bin/fixtures/`
(stub), `references/attack-surface.md`, `references/test-matrix.md`,
`bin/leakage-audit` expectations, and the CI pinned skip-count assertion
(`validate.yml` asserts exactly 2 skips). Grep for
extend/contribute/"new gate"/"new shape" across `CONTRIBUTING.md`, the
stub README, and the gate-interface doc returns nothing.
**Recommendation:** add an "Extending the stub" section to
`test/stub-memory-skill/README.md` with the file-dependency graph and
rebuild order, plus the invariants (interface version bump policy,
`--check` in CI, fail-closed default on unlisted shapes). This is the
documented contribution surface the stub needs.

### MEDIUM-3 · No automated guardrail against the stub becoming a real detector
**Evidence:** the design resists drift (lookup-only verdicts, fail-closed
review-tier on unlisted shapes, "Not a detector / Not protection" in two
READMEs and the gate-interface doc). But nothing in CI distinguishes "new
synthetic fixture" from "new detection heuristics in the stub's
`patterns.sh` / `memory-egress-check`". CODEOWNERS does route all of
`test/stub-memory-skill/` to the maintainer — a good *human* gate — but
there is no machine-readable rule or review cue for the specific
anti-pattern the docs forbid ("well-meaning contributor turns the stub
into a real detector").
**Recommendation:** add a lightweight CI assertion or PR-checklist item:
changes to stub logic files (`bin/egress-gate`, `bin/brief-gate`,
`bin/memory-egress-check`, `bin/patterns.sh`) must either (a) be
accompanied by a corpus/blockset/fixture change and the `--check` pass,
or (b) carry an explicit reviewer note that the change is test-double
only. Even a labeled checklist item ("stub logic changes stay
test-double-only; no new detection heuristics") makes the boundary
reviewable.

### MEDIUM-4 · Hardcoded "36/36" in 7+ doc locations will drift
**Evidence:** `README.md:110`, `CONTRIBUTING.md:32,62`,
`SKILL.md:116`, `references/attack-surface.md:254`,
`references/gate-interface.md:84`, `test/stub-memory-skill/README.md:29-30`,
plus `CHANGELOG.md`/`ITERATIONS.md` history. The corpus is 36 cases today
(the audit itself prints "adversarial corpus has 36 cases"), but the
iteration backlog already lists "Adversarial encoding/Unicode/multiline
expansion" — the count will change and every one of these will be stale.
**Recommendation:** replace hardcoded counts with "expect all cases to
pass (`bin/adversarial-run` prints N/N)" or derive the number
dynamically in docs that can (e.g., point at the audit's corpus-count
line). One source of truth for the number.

### LOW-1 · `MOCHI_TEST_EMAIL` "required" reads as a quickstart prerequisite
**Evidence:** `README.md` Configuration table: `MOCHI_TEST_EMAIL` —
"live-fire email recipient — owner's own address only …" — default column:
"**required** (no default)". It's in the general Configuration table, so
a newcomer scanning requirements may think the quickstart needs an email
address; it's only required for opt-in live-fire.
**Recommendation:** change the default cell to "(live-fire only —
required there, unset otherwise)".

### LOW-2 · Docs/repo mismatch: attack-surface scenario count vs README wording
**Evidence:** `README.md` section E table lists 4 residual scenarios and
the audit prints 4 residuals; consistent. But `references/test-matrix.md`
section F is referenced as "the coverage map" by both README ("Adding a
new exfiltration path" step 3) and CONTRIBUTING ("Adding an
attack-surface scenario" step 3) with slightly different section
references ("section F" vs no section) — trivial, but two docs describing
the same contribution step with different detail is where drift starts.
**Recommendation:** make the two "add a scenario" recipes identical
(one canonical recipe, the other links to it).

### LOW-3 · CODEOWNERS gap on scenario docs
**Evidence:** `.github/CODEOWNERS` covers `references/gate-interface.md`
but not `references/attack-surface.md` or `references/test-matrix.md`.
A docs-only scenario addition could merge without maintainer review.
(Mitigated: any *meaningful* scenario change touches `bin/leakage-audit`,
which is covered.)
**Recommendation:** add `references/attack-surface.md` and
`references/test-matrix.md` to the CODEOWNERS maintainer line, since the
coverage map is trust-relevant.

---

## Summary of verification runs (evidence for the above)

- Fresh-clone simulation (`git archive HEAD` → `/tmp/walk`, no `local.env`):
  `bash -n` on all three scripts OK; `bin/leakage-audit` CLEAN (57 passed,
  2 skipped) and `bin/adversarial-run` 36/36 (block 19/19, review 9/9,
  clean 8/8) **only after** a delegate CLI existed on PATH — this VM has
  real CLIs in `/opt/hatch/bin`, which masked HIGH-2 locally.
- With no delegate on PATH: A-suite failures, exit 1 — the failure a true
  newcomer hits.
- With `HOME=/tmp/fakehome`: denylist check skips (`@@@ CHECK SKIP`),
  purity check still passes — basis for HIGH-3.
- Full tracked-tree scan against the audit's `SHAPES` regex: every token
  is declared in `SYNTHETIC.txt` today — hygiene is clean; enforcement
  scope is the gap (MEDIUM-1).
- `bin/leakage-report --out` wrote a valid HTML report containing the
  `SYNTHETIC STUB TARGET` banner (CI's grep assertion holds).

Recommended iteration-5 priority order: HIGH-1 (license) → HIGH-2
(delegate snippet) → HIGH-3 (public syntheticity proof) → MEDIUM-2
(extend-the-stub doc) → MEDIUM-1 (purity scope) → MEDIUM-3 (stub-drift
guardrail) → MEDIUM-4 (de-hardcode 36) → LOW items.
