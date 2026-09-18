# Iteration-6 synthesis — "CI fails honest" (HEAD 5ff8950 → iteration 6)

10/10 persona reviews read (hidden_files/iter6-reviews/01–10). 77 findings
total. Deduplicated below; conflicts resolved; one focused theme chosen.

## Chosen theme: CI fails honest

The CI workflow must tell the truth in both colors. 7+ personas converged
on the CI failure experience; it holds the only P0 (CI cannot be green at
HEAD: the skip pin expects 2, CI reality is 4). This also completes the
iteration-5 synthesis item #1 (CI fail-at-the-end) that iteration 5 never
implemented.

### In scope (iteration 6)
1. **Skip pin recalibrated to CI reality (P0)** — SRE, OSS, PM, DS.
   Pin 4 skips: "cron prompt dirs not configured", "memory-audit run",
   "no egress denylist", "gate log not found". Verified by fresh-HOME
   simulation: 57 passed · 0 failed · 4 skipped.
2. **Fail-at-the-end (P1)** — SRE, OSS, PM, designer.
   Every component step runs even when red (`if: always()` guarded by the
   two refuse-step outcomes so safety preconditions still fail fast);
   each captures its exit code to an rc file; a final assert-green step
   owns the job outcome; upload is conditional on the file existing.
3. **Hermetic delegates (P1)** — SRE, security, OSS.
   Provision into `${{ runner.temp }}/delegates` via `$GITHUB_PATH`; no
   sudo, no /usr/local/bin writes.
4. **Adversarial step can actually fail (P1)** — security.
   Missing `set -o pipefail` meant a red suite reported a green step.
5. **Sentinel-based summary (P1/P2)** — 8/10 personas named the dead
   'block-tier recall' grep. `adversarial-run` emits `@@@ ADV …`
   sentinels; the summary parses `@@@` lines (anchored), never prose;
   per-component status table; explicit outcome word; no `|| true`
   silent drops.
6. **Timeout hardening (P1/P2)** — SRE, security.
   `timeout -k` on all gate invocations (audit + adversarial-run);
   report wraps its audit/adversarial subprocesses in `timeout -k 10 600`;
   per-step `timeout-minutes` in the workflow.

### Deferred to iteration 7 (contract conformance)
- Systems N1 HIGH: stub GWS shim doesn't gate the stdin form of raw MIME
  (contract documents the stdin form; audit tests only the argv form).
- Systems N4 / AI R11: stub `die()` exits 2 (review-tier) — should be 1.
- Systems N2: delegate resolution self-exec loop (canonicalize + self-guard).
- interface_version declared never enforced (systems F1, security, DS).
- C5/A7/E3 catalog corrections (security, privacy, AI researcher).

### Deferred to iteration 8 (report redaction + red-path polish)
- Privacy P1: `scrub()` is email-only; secret-shaped tokens reach the
  HTML via the fake Messenger delegate's stdin echo and D-suite gate-log
  echo. Fix: secret-shaped redaction pass reusing the audit's SHAPES set;
  make the fake delegate hash stdin.
- Designer red-path bugs: tri-state groups collapse on red (rc= only in
  evidence); "[B] [B]" duplication; F-card "Detection performance" on
  stub runs; confusion-matrix off-diagonal shading + explanation;
  CI-bounds plain-language gloss; F-card subtotal framing.
- PM P1: badge collapses tri-state into red (amber ATTENTION).

### Deferred to iteration 9 (measurement + near-miss traps)
- Supplemental near-miss corpus input (privacy P2, AI R1/R2).
- MALFORMED itemization, two-sided CI label (DS P3).
- Blockset anchored to SYNTHETIC.txt declarations (DS P3).
- Corpus-integrity guards: duplicate names, `|` in content (DS P4).

### Deferred to iteration 10 (final polish)
- a11y: link colors, transcript/tablewrap keyboard access, no-JS
  progressive enhancement, matrix corner header wording.
- Docs: B18/B19 catalog rows, README residual-table sync (9 rows,
  E-numbering), README tagline qualification, CONTRIBUTING inert-delegate
  block, SECURITY.md, exit-code docs, E3 trilemma resolution.

## Conflicts resolved
- SRE recommended fabricating CI scaffolding (stub denylist) to get back
  to 2 skips — rejected; both SRE and OSS agree: pin the honest 4.
- SRE's fail-at-the-end sketch omitted the refuse-step guard — fixed:
  `always()` steps are additionally gated on both refuse outcomes.
- DS suggested configuring CI with a synthetic denylist + cron fixture
  dir so checks run instead of skip — rejected in favor of pinning the
  honest skips (less scaffolding, tests the skip paths themselves).
- PM verified the remaining "36/36" literals are specific enough — kept.
