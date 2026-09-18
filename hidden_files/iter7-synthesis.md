# Iteration-7 synthesis — Contract conformance

**Date:** 2026-09-17 · HEAD `e20a819` · All 10 persona reviews read in full:
`01-security.md`, `02-privacy.md`, `03-pm.md`, `04-designer.md`,
`05-datascientist.md`, `06-airesearcher.md`, `07-sre.md`, `08-systems.md`,
`09-a11y.md`, `10-oss.md` (in `hidden_files/iter7-reviews/`).

## Deduped finding clusters (persona attribution)

### Cluster 1 — Fail-open/bypass gaps in the stub GWS shim (empirically confirmed)
- **sec H1 / sys N1**: stdin form of raw MIME (`gmail users messages send` with
  `{"raw":...}` on stdin) is not gated — `rc=0`, delegate invoked, MIME never examined.
- **sys N11 (HIGH, new)**: `--draft`/`--dry-run` token-confusion — the draft scan
  matches any argv token, including flag values: `+send --subject --draft --body <secret>`
  → `rc=0` ungated. Zero suite-B coverage of either form.
- **sys N19 (LOW)**: Drive `permissions create` refusal matches any two tokens anywhere,
  not the subcommand position — fail-closed false positive + fragile.
- **Related (sec M1 / sys N2, MEDIUM)**: delegate resolution has no canonicalization
  and no self-identity guard — `MOCHI_REAL_HATCH_GWS_CLI=<shim itself>` → infinite
  self-exec loop; the audit's "distinct executable" assertion is string-equality on
  PATH dirs, defeated by symlinked/aliased spellings.

### Cluster 2 — Operational failures are approval-downgradeable (fail-open)
- **sec H2 / sys N4**: stub `memory-egress-check` `die()` exits 2 (review tier);
  with `MOCHI_EGRESS_APPROVED=1` it becomes `rc=0` (allow) — a broken detector is
  approvable. Contract's exit-code section never pins "non-verdict errors must not
  reuse 0/1/2".
- **sec H2 / sys N10**: stub `brief-gate` conflates usage error (missing `--brief-file`)
  with review-tier `rc=2`.

### Cluster 3 — interface_version declared, enforced nowhere
- **sys N12 / sec M4 / DS P3**: `gate-interface.md` says "version 1" in prose;
  `.synthetic-stub` declares `interface_version=1`; nothing parses either.
  Systems delivered a concrete design: machine-readable `contract_version`,
  single suite-A enforcement point, one FAIL + skip-the-rest on mismatch,
  CI negative test. Real skills have no declared declaration point at all.

### Cluster 4 — Catalog/test-matrix overstate what the suites enforce
- **privacy M1 / sec L1 / AI F8**: C5 "shim interception verified" overstates —
  PATH-shadowing is verified, shim *interception itself* (an absolute-path call
  would bypass) is not.
- **privacy M2 / AI F9**: A7 "Covered by" overstates — the check is static/syntactic
  (mandate text in prompt files), not runtime proof; residual E-bullet says so,
  but the mapping doesn't.
- **privacy M3 / OSS / sys N14**: "KNOWN GAP" used in the audit's verdict key but
  never defined there; README residual table (E1–E4) is a stale subset of the 9
  residuals the audit prints, and its E/B numbering collides with the attack-surface
  catalog's B1–B4/E1–E3 (README B1 ≠ catalog B1).
- **AI F4/F6/F7**: test-matrix "Covered by" rows wrong — D1/D2 (gate exit codes map to
  brief-gate's, not the audit's), B3 (A4/A5 are direct-gate, not shim-path), B row
  "injected payloads" (nothing injected in B; fixtures passed literally).

### Cluster 5 — Small conformance-adjacent hardening
- **sec M3 / sys N17**: `live_send_expect` has no timeout — the simulated path has
  `timeout -k 10 30`; the live path relies on the outer 600s bound.
- **sys N18**: suite A never runs `build-blockset.sh --check` (CI does); a locally
  stale `blockset.txt` isn't named by the audit.
- **sec L2**: contract says "body/to pass egress-gate" but the stub gates subject+body,
  not `--to`.

### Conflicts resolved
- N12 proposed skipping suites B–F on version mismatch; the audit has no skip-suite
  machinery, so a mismatch instead records the single FAIL in suite A and exits
  after the summary (no contract-shaped check runs, so nothing is misattributed).
- Privacy M1 said the suite-B PATH-shadowing check is "not a shim-interception
  test" — the systems parity runs confirm the plumbing check is exactly what it
  claims to be; resolution: keep the check, fix the *label* (C5 qualified in the
  catalog, not the check deleted).
- Systems suggested SHAPES-as-manifest (N13); data scientist suggested a CI
  cross-check (P2). Both are measurement-integrity work, larger than one focused
  diff → deferred together to iteration 8.

## Iteration-7 theme: **Contract conformance**

The stub honors its contract; the audit enforces what the contract claims;
the catalog and matrix say only what the suites enforce. Deferred by iteration 6
as "interface_version + contract conformance"; now the empirically-confirmed
fail-opens (stdin MIME, draft token-confusion) make it the sharpest theme.

### In scope (single diff)
**Stub** (`test/stub-memory-skill/`):
- S1 gate stdin-form raw MIME + replay original bytes (H1/N1)
- S2 flag-aware `--draft`/`--dry-run` (N11)
- S3 drive `permissions create` positional match (N19)
- S4 canonicalized delegate resolution + self-identity guard in both shims (M1/N2)
- S5 `memory-egress-check` `die()` → exit 1 (H2/N4)
- S6 `brief-gate` missing-arg → exit 1 (H2/N10)

**Audit** (`bin/leakage-audit`):
- A1 suite-A interface_version check — first check; stub-enforced; mismatch → one
  FAIL, no contract-shaped checks run, ATTENTION, exit 1; real targets skip with
  reason (contract names no declaration point for real skills yet) (N12/M4/P3)
- A2 suite-B distinct-delegate assertion via canonical paths (M2)
- A3 suite-B red-team: stdin-form blocked + clean passes; `--subject --draft`
  confusion blocked (H1/N11)
- A4 suite-A stub-only operational-failure approval-isolation: stub copy without
  `blockset.txt`, approved gate call on clean fixture → `rc=1` (H2)
- A5 suite-A stub-only `build-blockset.sh --check` (N18)
- A6 `live_send_expect` wrapped in `timeout -k 10 30` with rc=124 fail-closed (M3/N17)

**Docs**:
- D1 `gate-interface.md`: machine-readable `contract_version: 1`; body/to vs
  subject+body alignment; real-skill version declaration point documented as TBD;
  pin "non-verdict errors never reuse 0/1/2" (N12/L2/N4)
- D2 `attack-surface.md`: C5 qualified; A7 → POLICY-ONLY; KNOWN GAP defined in the
  verdict key (M1/M2/M3/L1 + AI F8/F9)
- D3 `test-matrix.md`: "Covered by" corrections (B injected-payloads, A7, D1/D2, B3);
  new B cases pinned (AI F4/F6/F7, privacy M1/M2, N11)
- D4 README: residual table un-numbered, all nine residuals, tagline "proves"→"audits"
  (privacy M4, OSS, sys N14)

### Explicitly deferred
- **Iteration 8 — measurement integrity + red-path polish**: exact pass-total /
  adversarial-total assertions; duplicate corpus-name detection; rc=137 handling;
  slow/hanging/flaky stub fault variants; timeout-budget asymmetry (30s vs 10s);
  SHAPES manifest or fixture-purity cross-check; near-miss/probe-first methodology;
  report tri-state fallback to `ev[0]` (sys N16 / designer H2); `[B] [B]` prefix
  duplication; "Detection performance" mislabel; messenger stdin-echo hashing;
  HTML redaction beyond email addresses; yellow-semantics consistency; brief-gate
  doc count.
- **Iteration 9 — accessibility + contributor docs**: no-JS card evidence access
  (a11y HIGH); keyboard-focusable transcripts; skip link; matrix corner header;
  skip-card styling; CONTRIBUTING verbatim copy-paste quickstart + inert-delegate
  block; corpus-case proposal methodology; false-positive reporting path;
  issue/PR templates; SECURITY.md (responsible-disclosure path); exit-code docs
  consolidation (rc=124); SKILL.md exit-3 wording.
- **Iteration 10 — threat-model extensions + residual honesty**: scenario rows for
  shapeless leakage (spelled-out figures, fullwidth digits, nested encoding,
  paraphrase, aggregates, oracle), chunked/compositional and out-of-band
  exfiltration as catalog scenarios; probe-first corpus-expansion methodology;
  stub/real parity boundary doc; approval-isolation methodology doc;
  README↔catalog numbering (if not fully resolved); real-skill interface-version
  declaration point (requires the other repo — document only).

## Validation plan
- `bash -n` on every touched shell script
- `bin/leakage-audit` CLEAN against stub AND real installation
- `bin/adversarial-run` 36/36 against stub AND real installation
- Targeted regressions: stdin-form blocked/clean; `--subject --draft` blocked;
  genuine `--draft` still passes; `MOCHI_REAL_*`=self refused; missing blockset +
  approval → rc=1; version mismatch (temp stub copy, interface_version=99) → one
  FAIL, exit 1, no B–F checks
- Never commit red; `local.env` untouched; synthetic fixtures only
