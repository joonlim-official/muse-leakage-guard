# Changelog

Brief per-iteration notes. Each iteration: all 10 personas review in
parallel → synthesis → one focused diff → full validation → one commit.

## Iteration 3 — Report honesty and parser hardening

The report can no longer say things the run did not prove:

- **Adversarial results are in the report.** `bin/leakage-report` now
  runs `bin/adversarial-run` alongside the audit and renders a
  "Detection performance" card: per-tier figures (block-tier recall,
  review-tier recall, clean precision) plus a per-case table (name, want
  rc, got rc — no payload content). Any mismatch forces ATTENTION and an
  auto-expanded Findings entry.
- **Machine-readable audit contract.** The audit emits `@@@`-sentinel
  lines (`SUITE`/`CHECK`/`CTX`/`ENDSUITE`/`TOTAL`/`VERDICT`/`MODE`) when
  `MOCHI_AUDIT_MACHINE=1` (set by the report; terminal output unchanged).
  The report parses sentinels first and only falls back to hardened text
  scraping for older output. Unparseable output or a missing suite
  subtotal → no HTML at all (exit 3), never a fabricated report. Unknown
  mode defaults to `UNKNOWN` (never SIMULATED).
- **No more hardcoded blurbs.** Suite B's fixed "29 payloads", suite D's
  "log not found", and suite C's fixed cron count are replaced by blurbs
  derived from actual execution evidence (counts, subtotals, mode-aware
  transport description).
- **Report privacy.** Email-shaped strings are redacted before rendering;
  fake real binaries echo an argv hash instead of full args, so failure
  evidence never carries fixture content; live-fire identity mismatches
  compare domains only.
- **Stronger red-team fidelity.** Fake binaries prove invocation with a
  per-check sentinel file (not stdout text); gate and send invocations
  time out (30s) instead of hanging; fixture SHAPES manifest gains
  `sk-…` and `AKIA…` patterns (three previously undeclared synthetic
  tokens were reviewed and declared).
- **Accessibility.** Native `<button>` accordion heads, named regions,
  real `h2`/`h3` headings, `<main>` landmark, `aria-controls`,
  `prefers-reduced-motion` guard, decorative emoji hidden from screen
  readers.
- **Operational.** Atomic HTML writes, unique filenames (seconds + PID),
  `-h|--help`, raw transcript `<details>`, `hidden_files/reports/`
  correctly gitignored (README pointed at the wrong directory).
- `bin/adversarial-run`: per-tier figures line, exit 3 for runner
  failures (missing gate/corpus, empty corpus) so callers cannot mistake
  a broken runner for 0 mismatches, per-case 10s timeout.

## Iteration 2 — Live-fire safety hardening

Closes the gaps the iteration-1 review round found in live-fire's
safety posture:

- **Email ownership is now verified.** `MOCHI_TEST_EMAIL` has no default
  (fail closed when unset) and must match the authenticated Gmail
  profile's address — checked via a read-only `getProfile` call before
  any send. Mismatch or undeterminable identity fails closed.
- **Live-fire is strictly per-invocation opt-in.** `MOCHI_LIVE_FIRE=1`
  must be set inline in the invoking environment; a value coming only
  from `local.env` is ignored with a loud warning, so a stale config
  file can never arm real sends.
- **No silent automation.** Live-fire is refused when stdin is not a TTY
  or `$CI` is set, unless `MOCHI_LIVE_FIRE_NONINTERACTIVE=1` is also set
  explicitly (exit 2).
- **Live-fire means the genuine binaries.** Any stale `MOCHI_REAL_*_CLI`
  override is unset with a warning in the live-fire branch — a run that
  claims `LIVE-FIRE` must exercise the real path, never fake delegates.
- **Stricter Messenger self-chat.** A self-chat now requires exactly one
  participant equal to the owner; a live-fire run with no owner-only chat
  is a failure (was: skip), so the run can never report CLEAN for a path
  it did not exercise.
- **10-second abort window** (TTY only) before the first real send.
- Explicit environment now wins over `local.env` in all three scripts
  (was: `local.env` silently overrode invocation env); `local.env.example`
  documents the live-fire knobs as commented placeholders.
- `-h|--help` and unknown-argument guards (`bin/leakage-audit`,
  `bin/adversarial-run`); `--out` requires a path (`bin/leakage-report`).
  Exit 2 now means usage/environment refusal, documented in SKILL.md.
- Suite B subtitle is mode-aware; failures in the report Findings carry
  their suite letter for attribution.
- Synthetic discipline: `fig_week` corpus payload `$150/week` → `$275/week`
  (the old figure coincided with a real recurring amount);
  `attacker@x.com` → `attacker@example.com` in attack-surface.md.

**Correction to iteration 1:** the changelog entry above overstated the
email safety — iteration 1 checked only that `MOCHI_TEST_EMAIL` was
nonempty, so an overridden value pointing at someone else would have
been accepted. The mechanical Gmail-identity verification in this
iteration closes that hole. Additionally, the live-fire validation on
2026-09-17 ran more full audits than the single authorized one
(approximately 6–8 synthetic emails to the owner's own inbox instead of
the intended 3); all sends were to the owner's own address, no
block-tier payload was delivered, and no sends have occurred since.
Do not re-run live-fire for validation — this iteration is validated in
simulated mode only, plus static tests of the new guards.

**Known:** the pre-purge private values remain in Git history (they were
already on the public remote's history before the purge). Working tree is
clean. History rewrite requires a force-push — flagged for the owner's
decision, not done unilaterally.

Validation: `bash -n` clean on all touched scripts; `bin/leakage-audit`
CLEAN in simulated mode; `bin/adversarial-run` 36/36; regression checks
below.

## Iteration 1 — Opt-in live-fire mode + synthetic-data purge

- **Live-fire mode** (`MOCHI_LIVE_FIRE=1`): suite B runs a small
  representative subset for real — shim → gate → genuine binaries —
  instead of the fake-binary simulation. Default stays simulated (safe
  for CI/contributors); live-fire is never the default.
- Real sends go to the owner's own accounts **only, ever**: email target
  `MOCHI_TEST_EMAIL` (default owner's own address); Messenger target is
  auto-discovered as an owner-only chat, and an explicit
  `MOCHI_TEST_MESSENGER_CID` that doesn't resolve to such a chat fails
  closed. Payloads stay synthetic. Drive share tests stay simulated.
- Block-tier assertions unchanged (exit 1, real binary never invoked);
  verified live: block-tier email refused and never arrived; clean and
  approval-tier emails delivered end-to-end.
- Audit header, summary, and HTML report label the mode
  (`SIMULATED` vs `LIVE-FIRE`); report footer is mode-aware.
- **Synthetic-data purge**: replaced a real booking confirmation number
  and a real ZIP in the public adversarial corpus with fictional values,
  and de-personalized the profile path in `local.env.example`.
- README: new "Live-fire mode" section, config table entries, corrected
  dependency line (`bash` + `python3`).

Validation: `bash -n` clean on all touched scripts; `bin/leakage-audit`
58 passed / 0 failed / 1 skipped (CLEAN) in simulated mode;
`bin/adversarial-run` 36/36; live-fire run exit 0 with arrival/non-arrival
verified in the owner's own inbox.
