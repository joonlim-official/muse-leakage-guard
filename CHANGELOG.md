# Changelog

Brief per-iteration notes. Each iteration: all 10 personas review in
parallel → synthesis → one focused diff → full validation → one commit.

## Iteration 8 — Report integrity and readability

The report now tells the truth in plain language and is readable by
everyone, including keyboard and screen-reader users.

- **Badge integrity:** CLEAN requires audit CLEAN + adversarial rc 0 +
  parseable figures. A runner that exits 0 without emitting figures
  renders ATTENTION, not CLEAN.
- **Card B (gate effectiveness):** tri-state callout — N blocked outright
  · N protected through approval · N allowed normally — so rc=2
  approval-gated checks are never reported as plain green. Evidence
  grouped under 🟢/🟡/⚪ labels.
- **Card D (gate audit-log review):** gate-log context (blocked attempts,
  approval overrides) rendered as evidence, matching the card's promise.
- **Card E (known gaps):** each residual gets a plain-language gloss with
  the technical note retained underneath; "N tracked · 0 hidden".
- **Plain language:** invoked=0/1 → "real tool never called"/"delivered
  normally"; CLEAN/ATTENTION/INCOMPLETE defined under the badge; local
  time shown with UTC original; known-gap jargon glossed.
- **Adversarial card:** runner-only mismatches added as labeled drift
  rows; matrix corner "expected vs actual"; "Worst case consistent with
  these results (95% lower bound)" replaces the unexplained
  Clopper-Pearson label.
- **Accessibility:** skip link, h2-wrapped card headings, red cards
  pre-expanded server-side (no-JS fallback CSS), keyboard-focusable
  scroll regions and transcripts, unique finding link labels, focus
  styles, light/dark link colors, labeled "Overall result" total.
- **Adversarial runner:** timeout failures now count in the expected
  tier's denominator (no more disappearing from tier totals).

## Iteration 7 — Contract conformance

The stub honors its contract; the audit enforces what the contract
claims; the catalog and matrix say only what the suites enforce.

- **Stub (test/stub-memory-skill):** GWS shim gates the stdin form of raw
  MIME (was ungated fail-open); stdin bytes replayed byte-identical on
  allow; `--draft`/`--dry-run` honored only as flags, never as flag
  values (token-confusion bypass closed); drive `permissions create`
  matched positionally; canonicalized delegate resolution + self-identity
  refusal (fail closed); `+send` now gates `to` as well as subject/body;
  `memory-egress-check` operational failures exit 1 (fail closed, never
  approvable).
- **Audit (bin/leakage-audit):** Suite A enforces `interface_version` as
  the first check (mismatch → one FAIL, ATTENTION, exit 1); distinct-
  delegate assertion by canonical path identity; stub-only operational-
  failure approval isolation; suite B pins stdin-form blocked/clean,
  draft token-confusion blocked, positional drive-match; live-fire sends
  wrapped in `timeout -k 10 30`.
- **Docs:** gate-interface.md gains machine-readable `contract_version:
  1`; attack-surface.md C5 qualified (shimmed paths only), A7 marked
  POLICY-ONLY, KNOWN GAP defined; test-matrix.md Covered-by corrections;
  README residual list now all ten, matching suite E.

## Iteration 6 — CI fails honest

The CI workflow now tells the truth in both colors — a red run produces
diagnostics, not silence:

- **Fail-at-the-end.** Every component step runs even when an earlier
  component is red (`if: always()`), captures its exit code to an rc
  file, and a final assert-green step owns the job outcome. The two
  Refuse steps stay fail-fast (no `if:`) and the `always()` steps
  additionally require both refuse outcomes, so a refused run never
  executes the audit. A red audit or adversarial mismatch still yields
  logs, a written report, and an uploaded artifact; the summary names
  the red components instead of rendering an empty page.
- **Pinned CI skip set corrected (was: CI could never be green).** The
  workflow asserted exactly 2 skips; a fresh CI runner always produces
  4 (cron prompt dirs not configured; memory-audit run; no egress
  denylist; gate log not found). The pin now expects all 4, asserted
  from `@@@ CHECK SKIP` machine sentinels with each reason named.
- **Hermetic delegates.** Provisioned into `${{ runner.temp }}/delegates`
  via `$GITHUB_PATH` — no `sudo`, no `/usr/local/bin` writes. Smoke
  test uses a PATH lookup, not absolute paths.
- **Adversarial step can actually fail.** The runner's exit code is
  captured via `PIPESTATUS[0]` through `tee` (previously a failing
  suite could report a green step); `adversarial-run` emits `@@@ ADV
  MATCHED` / `@@@ ADV TIERS` / `@@@ ADV MISMATCH` machine sentinels.
- **Sentinel-based summary.** The dead `block-tier recall` grep is gone;
  every summary figure comes from an anchored `@@@` sentinel (audit
  TOTAL/VERDICT/MODE, adversarial ADV lines), with an explicit
  Outcome word (CLEAN / ATTENTION / INCOMPLETE / BLOCKED) and a
  per-component status table. A missing sentinel renders as
  "unavailable", never silently dropped.
- **Timeout hardening.** `timeout -k` on all gate invocations
  (audit `timeout -k 10 30`, adversarial-run `timeout -k 5 10`); the
  report bounds its audit/adversarial subprocesses with `timeout -k 10
  600`; per-step `timeout-minutes` on every workflow step. Also fixed:
  the report's exit-code capture after `if !` (bash reports the negated
  status in `$?`; now captured directly).
- **Report parses adversarial sentinels first**, regex fallback for
  older logs; mismatch tuples keep their `(name, want, got)` shape.

## Iteration 5 — honest green

The report now tells the truth about what green means — tri-state
verdicts, fixture-conformance language, and statistical humility:

- **Tri-state semantics.** Green = well protected (block-tier, rc=1);
  yellow = protected through approval (review-tier, rc=2); red = can
  leak. An explicit legend states this on every report. Tracked
  residuals use a neutral white treatment (never yellow), stub
  self-consistency gets its own purple card (never a green protection
  card), and a suite that ran nothing at all renders severe red
  (unknown = unprotected until proven otherwise).
- **Measurement honesty.** "Recall"/"precision" are gone — the
  adversarial summary and report now say block/review/clean *pass
  rates*, state plainly that the corpus is author-designed regression
  fixtures (not a real-world sample, not ML metrics), add a 3×3
  expected-vs-actual exit-code confusion matrix, and print exact 95%
  Clopper-Pearson lower bounds per tier (wide intervals at small n:
  19/19 → ≥0.82, 9/9 → ≥0.66, 8/8 → ≥0.63).
- **Approval isolation.** Suite B now proves a block-tier payload stays
  rc=1 even with `MOCHI_EGRESS_APPROVED=1` (gmail + messenger) —
  approval can only override the review tier, never a block verdict.
- **Report evidence split.** Suite B evidence is grouped into
  hard-block, approval-gated, and pass-through sections so the two
  protection tiers are never mixed in one undifferentiated list.
- **Stub input hardening.** Newline separators when concatenating
  fixtures (`memory-egress-check`, `build-blockset.sh`); the stub shim's
  raw-MIME decode now fails closed (refuses the send) when python3 is
  missing, the JSON is malformed, or `raw` cannot be decoded — encoded
  bytes are never gated as if clean.
- **Fixture-purity SHAPES widened** to the stub's candidate shapes: bare
  9-digit SSN, bare 16-digit card, 15-digit Amex, and
  `api_key=`/`password=`/`passwd=` value shapes (new synthetic tokens
  declared in `SYNTHETIC.txt`).
- **Known-gap markers.** Suite E now tracks compositional/chunked
  exfiltration across calls, out-of-band egress (curl, webhooks,
  unshimmed CLIs — only shimmed send paths are gated), and attachment
  inspection (B4, still open); new scenario **E3** documents the bare
  nine-digit SSN false-positive trade-off; A7's cron PATH check is now
  labeled syntactic/static.
- **License.** MIT `LICENSE` added, README carries a license section,
  and `references/attack-surface.md` + `references/test-matrix.md` join
  `CODEOWNERS`.
- **Report accessibility.** No heading inside `<button>` (span +
  `role="heading"`), transcript section with proper h2/details
  hierarchy, table captions with expected/actual exit-code headers and
  row headers, decorative glyphs `aria-hidden`, darker muted text,
  focus-visible transcript summaries, footer outside `<main>`, empty
  evidence sections and all-zero subtotals suppressed, failing cards
  auto-expanded, and every finding links to its evidence card.
- **Contributor UX.** README quickstart gains a copy-paste inert
  delegate setup with PATH-ordering notes; "36/36" replaced by "every
  corpus case matched" in general docs; `MOCHI_TEST_EMAIL` clarified as
  live-fire-only.

## Iteration 4 — CI readiness + synthetic stub skill

The harness now validates itself in public CI with no private
installation — and a green run cannot be mistaken for protection:

- **Synthetic stub skill.** `test/stub-memory-skill/` is a checked-in
  test double honoring the new interface contract
  (`references/gate-interface.md`, `interface_version=1`): stub
  `memory-egress-check`, `egress-gate`, `brief-gate`, Gmail/Drive and
  Messenger shims, synthetic fixtures, and a stub agent manual. Its
  detector extracts public token shapes and classifies by lookup in a
  declared set of synthetic block-tier tokens (`bin/blockset.txt`),
  derived from corpus want=1 cases plus declared fixtures by
  `build/build-blockset.sh` (whose `--check` CI runs). Known synthetic
  block-tier tokens → block (rc=1); other secret/figure/phone shapes →
  fail closed to review (rc=2); clean → pass (rc=0). It is a test double,
  not a protection layer — never deploy it.
- **Stub labeling + live-fire refusal.** The audit detects
  `.synthetic-stub`, prints `target-kind: SYNTHETIC STUB`, emits a
  `STUBKIND` machine sentinel, and refuses live-fire against stub
  targets (exit 2). Fixture-purity inspection covers stub fixtures; the
  synthetic `gsk_` shape replaced the AWS-shaped `aws_key` fixture.
- **Honest stub reporting.** The HTML report banners stub targets
  (banner, page title, hero line, footer), renders a "Stub consistency"
  card instead of "Detection performance", qualifies results as harness
  self-consistency, adds an accessible "match" table header and
  visually hidden status text, and redacts home paths/emails from raw
  transcripts.
- **CI.** `.github/workflows/validate.yml` runs audit + adversarial
  against the stub on PRs and pushes to `main`: `pull_request` (never
  `pull_request_target`), `contents: read`, SHA-pinned actions,
  `persist-credentials: false`, `fetch-depth: 1`, no secrets, live-fire
  variables and `local.env` refused, skip set pinned (exactly
  memory-audit + gate-log), 14-day report artifact, step summary stating
  what green does and does not prove. `CONTRIBUTING.md` and
  `.github/CODEOWNERS` added; README quickstart is stub-first.
- **Attack-surface E2.** "Stub-target validation mistaken for real
  protection" is cataloged (PROTECTED by labeling + refusal) and mapped
  in the test matrix.

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
