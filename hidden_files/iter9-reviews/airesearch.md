# Iteration-9 review — Senior AI researcher (threat-model completeness)

**Date:** 2026-09-17 · HEAD `e35c1bc` ("Iteration 8: report integrity and readability"), branch `main`
**Method:** read-only review + simulated-mode probing only. No file modified,
no git operations, no `MOCHI_LIVE_FIRE`, no network sends. All payloads
synthetic (the repo's own fixtures). Shim behavior was probed empirically
with fake delegate binaries in `/tmp` (`MOCHI_REAL_HATCH_GWS_CLI` /
`MOCHI_REAL_HATCH_MESSENGER_CLI` pointed at inert stubs) — nothing was sent
anywhere. Detector regexes were probed via the real
`personal-memory-system/bin/memory-egress-check` on synthetic strings.
Every shell context began with the shim-PATH export per the brief.
**Scope note:** the gates/shims under test live in the memory skill
(`~/workspace/skills/personal-memory-system/bin/`); this repo validates
them. Findings are ranked for the *validation* — what the leakage-guard
fails to cover, claim, or catch — with the underlying protection gap
stated so the memory skill can fix it. Each finding carries a concrete
suggested remediation, per the skill's own rule.
**Legend:** **[EXEC]** = confirmed by execution in this review (simulated,
synthetic). **[STATIC]** = established by code/document reading.

**Headline:** iteration 8 polished the *report*. The *protection* did not
move: every P0/P1 bypass from the iter-8 AI-researcher review re-verifies
as still open at this HEAD, and this round found a new fail-OPEN bug class
the validator structurally cannot see — `egress-gate` returns rc=0
("clean", logged as clean) when its detector binary is missing or
non-executable, while the audit's only operational-failure test runs
against the stub. The validator's green therefore coexists with (a)
unshimmed send paths, (b) a fail-open gate, and (c) an obfuscation surface
the corpus never touches.

---

## P0 — critical

### P0-1 [EXEC] — Real `egress-gate` fails OPEN when the detector fails; the audit's fail-closed test is stub-only
- **What:** `personal-memory-system/bin/egress-gate` lines 49–69: `verdict="clean"; rc=0`
  is set *before* invoking the detector, and only `grc` 1 or 2 change it.
  If `memory-egress-check` is missing (grc=127), non-executable (grc=126),
  or killed (grc=137), execution falls through with verdict `clean`,
  rc=0 — and line 68 logs `| clean` to the audit log. A send carrying a
  block-tier secret is **allowed and logged as clean**.
- **Where:** `~/workspace/skills/personal-memory-system/bin/egress-gate:49-69`.
  Contract violated: `muse-leakage-guard/references/gate-interface.md:42`
  ("Non-verdict errors … must fail closed … NEVER as 0 (allow)").
- **Confirmed:** copied the real `egress-gate` to `/tmp`, removed/unchmodded
  the detector copy, ran with the repo's `secret.txt` fixture → rc=0 both
  times; the gate log recorded `probe:detector-broken | clean`.
- **Why it matters:** this is the exact failure class the contract was
  written for, and the validator has a test for it — but the test
  (`bin/leakage-audit:323`, "operational failure (missing blockset) fails
  closed") runs **only against the synthetic stub** (`:331` explicitly
  skips it for real targets). The real gate was never probed this way,
  and it fails open. A green suite A therefore attests to a property the
  real installation does not have. The stub's own `egress-gate`
  (`test/stub-memory-skill/bin/egress-gate:33`, `exit 0` fall-through)
  fails open on a missing detector binary too — the stub test only
  removes `blockset.txt` (detector present, `die()` → rc=1), so even the
  stub's failure modes are under-tested.
- **Remediation (validation):** extend the operational-failure probe to
  real targets: copy `$MEM_SKILL` to a temp dir (as the stub test already
  does), break the detector copy three ways (missing, non-executable,
  and — via a wrapper — killed/SIGKILL to produce grc=137), run
  `egress-gate` with a block-tier fixture under `MOCHI_EGRESS_APPROVED=1`,
  and require rc=1 in all three. File a memory-skill fix: treat any
  `grc` outside {0,1,2} as block (rc=1). Until the fix lands, this new
  suite-A case goes red — which is the validation loop working.

### P0-2 [EXEC] — Iter-8's unshimmed-subcommand bypasses are all still open at this HEAD
- **What:** re-verified with fake delegates (rc=0, delegate invoked, secret
  fixture in argv/stdin — would have left the machine against a real
  delegate): `gmail +reply-all` with a block-tier secret body;
  `gmail users drafts send` (the A5 two-step bypass: `+draft` is ungated
  by design, `drafts send` completes the exfil and no gate ever sees the
  content); `gmail users settings updateAutoForwarding` (persistent
  mailbox-wide forwarding, no gate, no approval); `chat +send`;
  `calendar +insert` with secret in `--description`; messenger
  `marketplace initiate --text-stdin` (public listing surface);
  `drive files update`; `drive comments create`.
- **Where:** shim match logic `personal-memory-system/bin/shims/hatch_gws_cli:54`
  (`+send|+reply|+forward` only) and the `users` branch (requires both
  `messages` and `send` tokens); `hatch_messenger_cli` (`send|edit` only).
- **Why it matters:** iteration 8 was report-only (`git log 2243723..HEAD`
  touches `bin/leakage-report`, `bin/adversarial-run`, docs). The
  protection surface is byte-identical to what iter-8 reviewed, so its
  P0-1/P0-2/P0-3 and P1-1…P1-4 stand unmitigated, and the catalog's A1
  ("PROTECTED"), A5 ("drafts never leave the account"), and B1
  conclusions remain false for these paths. The validator still has zero
  cases for any of them — suite B's "all send subcommands are covered"
  claim in `test-matrix.md` is still false (`+forward` is routed but
  untested; `+reply-all` is not even routed).
- **Remediation (validation):** add the red suite-B `send_expect` cases
  now (they fail until the memory skill extends the shims — correct
  behavior for the loop); add catalog scenarios A9–A14/B5 with verdicts;
  add the CLI-surface census check (parse the real CLI's `--help` for
  send/publish/mutate verbs; fail when a verb has no test). Do not defer
  this a third iteration: every green report published while these are
  untested is a misleading artifact.

### P0-3 [EXEC] — Shim self-delegate exec loop via symlinked PATH spelling; contract claim is false and the audit's check masks it
- **What:** both shims resolve their delegate with a *string* comparison
  (`[ "$d" = "$SHIM_DIR" ] && continue` —
  `personal-memory-system/bin/shims/hatch_gws_cli:20`,
  `hatch_messenger_cli:20`). When the shim dir appears on PATH only via a
  symlinked spelling *after* the canonical dir (e.g.
  `PATH=$REALSHIM:/tmp/shims-alias:…`), the shim execs itself forever.
- **Confirmed:** `PATH=$REALSHIM:$T/shims-alias:/usr/bin:/bin
  hatch_gws_cli gmail +triage --max 1` → rc=124 (timeout SIGKILLed the
  loop); control without the alias → rc=127 immediately (no delegate).
  Every send through that context wedges instead of completing — a
  self-inflicted DoS of the whole gated surface.
- **Where the validator lies:** `references/gate-interface.md:101` states
  "the shim resolves both paths canonically (symlinked/aliased spellings
  included) and refuses a delegate that is itself" — false for the real
  shims. Worse, `bin/leakage-audit`'s suite-A delegate check
  *canonicalizes* before comparing, so the audit asserts a stronger
  property than the shim implements at runtime: the check can be green
  while the shim loop forever in the same PATH layout.
- **Why it matters:** the audit is testing its own model of the shim,
  not the shim. Any PATH with an aliased spelling (dotfile managers,
  Nix-style store paths, and `command -v` vs logical-`pwd` disagreements
  all produce these) turns every gated send into a hang, and the audit
  will report it only as "send timed out" — misattributed to the gate.
- **Remediation (validation):** (1) fix the contract text to match
  reality until the shim is fixed; (2) add a runtime (not static) probe:
  in a temp PATH containing a symlinked spelling of the shim dir, invoke
  the shim and assert it does not self-exec (bounded timeout; expect the
  127 no-delegate path or the real delegate, never a hang); (3) memory
  skill: canonicalize (`realpath -m`) in the shim's own resolution loop.

---

## P1 — high

### P1-1 [EXEC] — Base64-encoded secret in `+send --body` passes ungated; A4's decode covers only the raw API path
- **What:** `hatch_gws_cli gmail +send --to … --body "data: <base64-of-secret>"` →
  rc=0, delegate invoked. The shim gates the literal body text; the
  base64 blob is not decoded anywhere on the `+send/+reply/+forward`
  path. A4 documents single-decode only for `users messages send`.
- **Where:** `personal-memory-system/bin/shims/hatch_gws_cli` `+send` branch
  (no decode step); no suite-B case; no catalog row.
- **Confirmed:** synthetic `api_key: REDACTED_CREDENTIALS` base64-encoded in
  `--body` → rc=0 invoked=1 with fake delegate.
- **Why it matters:** the most natural place an agent (or injected
  instruction, C5) hides a payload — the compose helpers, not the raw
  API — has no encoding inspection at all, and the validation never
  exercises it. The recipient trivially decodes it.
- **Remediation (validation):** suite-B case: base64 blob of a block-tier
  fixture in `+send --body` must be blocked (red until the memory skill
  adds a decode-and-rescan step or documents the residual); catalog row
  under A4/A5 family. Note the failure-mode subtlety for the memory
  skill: naive "decode anything base64-looking" creates false positives;
  the validation should pin the agreed behavior either way.

### P1-2 [EXEC] — Double-base64 `raw` envelope defeats the single decode
- **What:** `users messages send --params '{"raw":"<b64(JSON with inner b64 secret)>"}'` →
  rc=0, delegate invoked. The shim decodes the outer layer once; the
  resulting JSON still contains a base64 blob, which is gated as opaque
  text. Control (single-b64 secret) correctly blocks (rc=1).
- **Where:** `personal-memory-system/bin/shims/hatch_gws_cli` python decode
  block (single pass); suite E documents "nested base64 MIME *part*"
  but not a doubly-wrapped *envelope*.
- **Why it matters:** the documented residual is narrower than the real
  one — an attacker (or just an agent that base64-encodes twice by
  habit) walks past the A4 control the catalog calls PROTECTED.
- **Remediation (validation):** suite-B case for the double-wrapped
  envelope (expect block; red until fixed or the residual is widened in
  the catalog + suite E + test-matrix A4 row). The catalog's A4
  "PROTECTED (single encoding layer)" wording should say exactly how
  many layers are decoded (one) and what the second layer costs.

### P1-3 [EXEC] — Zero-width characters defeat block-tier detection outright
- **What:** inserting U+200B / U+200C / U+200D into a block-tier token
  (`sk_\u200btest_…`, `1\u200b23-45-6789`) → rc=0 from the real
  `memory-egress-check`. No normalization layer exists before the
  regexes.
- **Where:** `personal-memory-system/bin/memory-egress-check` (regexes
  applied to raw input); corpus has zero obfuscation cases.
- **Why it matters:** this is the cheapest possible detector evasion —
  invisible in most renderings, one character, no tooling needed — and
  the 36-case "adversarial" corpus contains nothing in this class, so a
  36/36 report actively implies coverage where there is none.
- **Remediation (validation):** add normalization-probe cases (at minimum
  as KNOWN-GAP probes per the probe-first methodology — but note P2-9:
  the probe-corpus artifact still doesn't exist, so today these results
  have nowhere to live). Memory skill: NFKC-normalize + strip
  default-ignorable code points before matching (cheap, high-yield).

### P1-4 [EXEC] — Shapeless variants all return rc=0: spaced/dotted SSN, fullwidth digits, spelled-out figures/phones
- **What (all synthetic, real detector):** `123 45 6789` → 0; `123.45.6789`
  → 0; fullwidth `１２３-４５-６７８９` → 0; digit-per-digit spaced SSN →
  0; dotted 16-digit card → 0; "the budget is twelve thousand five
  hundred dollars" → 0 (not even review-tier); spelled-out phone → 0.
- **Where:** `BLOCK_RE`/`FIGURE_RE`/`PHONE_RE` in
  `personal-memory-system/bin/memory-egress-check`; corpus covers
  syntax variants only (dash/space/bare/plus-1).
- **Why it matters:** the corpus is a *shape* regression set, not an
  adversarial one. The threat model names "shapeless leakage" explicitly
  in this review's brief, and the validator has no case class for it.
  Word-form figures are particularly load-bearing: a finance dashboard
  figure quoted in words ("forty-three thousand") is review-tier by
  policy but invisible to the gate.
- **Remediation (validation):** new corpus family with documented
  expectations (block / review / known-gap-probe); the probe-first
  artifact (P2-9) is the prerequisite — without it, adding these as
  pass/fail cases either fails CI spuriously or silently drops them.

### P1-5 [STATIC] — A7 cron-PATH check and memory-audit are skipped by default; the check that "once caught a real gap" doesn't run
- **What:** `MOCHI_CRON_PROMPT_DIRS` defaults to empty → suite C emits
  `skip "cron prompt dirs not configured"`; `MOCHI_MEMORY_AUDIT` defaults
  to 0 → `skip "memory-audit run"`. D1/D2 (secrets/figures written to
  memory) are therefore never mechanically tested in a default run, and
  `test-matrix.md` admits they are "not harness-verified where CI runs."
- **Where:** `bin/leakage-audit` suite C; `SKILL.md` usage.
- **Why it matters:** the highest-realistic bypass class (a scheduled
  worker without the shim on PATH — the one that *actually happened*)
  is verified only when the operator remembers to configure it. A
  default-run CLEAN badge implies coverage of A7 that was never
  performed. Skips are reported honestly, but the badge doesn't
  distinguish "clean because checked" from "clean because skipped" for
  the two checks that matter most operationally.
- **Remediation (validation):** (1) make the report's suite-C callout
  name the skipped checks explicitly when A7/memory-audit skip (the
  callout already special-cases skips — extend it); (2) add a CI-side
  synthetic cron-prompt fixture so the A7 *logic* is tested even though
  the real dirs are absent; (3) consider failing (not skipping) when
  `MOCHI_CRON_PROMPT_DIRS` is unset on a non-stub target — "I didn't
  configure the check" should not read as clean.

---

## P2 — medium

### P2-1 [STATIC+EXEC] — Deployed patterns with zero corpus coverage: JWT (`eyJ`) and `AKIA` (iter-8 P2-1, still open)
- **What:** `grep -c "eyJ\|AKIA" bin/adversarial-corpus.txt` → 0. The real
  `SECRET_RE` contains both (`eyJ[A-Za-z0-9_.-]{20,}`, `AKIA[0-9A-Z]{16}`);
  verified the gate fires on synthetic JWT (rc=1). No regression case
  pins either branch — a future edit breaking one stays green.
- **Where:** `bin/adversarial-corpus.txt`; `test/stub-memory-skill/bin/patterns.sh`
  also still lacks `eyJ` (iter-8 P2-2 unaddressed — adding a JWT corpus
  case today would produce a *harness* mismatch on the stub, misattributed
  to detection).
- **Remediation:** add `jwt_compact` + `aws_akia` corpus cases (want=1,
  synthetic); add `eyJ` to `STUB_SECRET_CAND`; add the mechanical
  branch-coverage check (every `SECRET_RE`/`BLOCK_RE` alternation
  exercised by ≥1 corpus case, or a documented mapping).

### P2-2 [EXEC] — Attachments via `-a/--attach` are never inspected — not even parsed — on either send path
- **What:** the real CLI's `+send --help` documents `-a, --attach <PATH>`
  (multiple, up to 25MB); messenger `send --help` documents `--attach`.
  The `+send` arg parser has no `-a`/`--attach` case — the flag and its
  path fall through the `*)` arm and are never read. B4 documents
  "binary attachment payloads are not deeply inspected," but the shim
  doesn't inspect *filenames* either (a path like
  `/home/user/tax-2026.pdf` is itself informative), and suite B has no
  attachment case at all — the OPEN GAP is declared but never exercised,
  so a future "we now scan attachments" claim would have no test.
- **Remediation (validation):** suite-B case with a synthetic file
  attachment (fake delegate; assert current behavior is pinned as
  pass-through, or refusal once the memory skill acts); catalog B4 row
  updated to name the `-a/--attach` flags explicitly.

### P2-3 [STATIC] — Corpus total unpinned; duplicate names undetected; rc=137/timeout asymmetry (iter-8 P2-4/P3-1/P3-2/P3-3, all still open)
- **What:** 36 cases (19/9/8) today, enforced nowhere — deleting half the
  corpus keeps CI green. Nothing asserts unique case names. `timeout -k 5 10`
  in `adversarial-run` vs `timeout -k 10 30` in the audit's
  `gate_expect`/`send_expect` judge "fast enough" differently; rc=137
  (SIGKILL after TERM-trap) falls into the generic mismatch message in
  both harnesses, misdirecting ("tighten SECRET_RE…" for a hang).
- **Remediation:** pin the corpus total + per-tier totals as data (CI
  assertion on `@@@ ADV MATCHED`); unique-name check in `adversarial-run`
  (exit 3); one documented timeout budget; explicit 137-as-timeout
  handling in both runners.

### P2-4 [STATIC] — Probe-first methodology still has no artifact (iter-8 P3-7, still open — now load-bearing)
- **What:** no `bin/probe-corpus.txt`, no `references/known-gaps.md`, no
  runner mode. This review's probes (P1-3, P1-4, plus paraphrase and
  aggregates from iter-8) return rc=0 and have nowhere to live: adding
  them to the pass corpus fails CI; omitting them is unexamined silence —
  the exact failure mode the catalog's "Coverage discipline" section
  exists to prevent.
- **Remediation:** `bin/probe-corpus.txt` (`name|observed_rc|gap_id|content`),
  `references/known-gaps.md` (one entry per unblockable shape with probe
  evidence and rationale), runner reports `PROBE-CONFIRMED-GAP`
  (informational) and fails only when a probe *stops* missing (a good
  failure — routes to closing the gap entry). Wire into `leakage-report`
  as its own card.

### P2-5 [STATIC] — Residual-list drift and prose residuals without scenario numbers (iter-8 P2-5, still open)
- **What:** suite E prints a longer residual list than the catalog's
  "Residual risk summary" (voice calls, brief-gate-on-mandate, A7
  static/syntactic caveat, attachment inspection, nested MIME encodings
  appear only in suite E). Chunked exfiltration, out-of-band egress, and
  voice calls have no `### XN.` numbers, so suite C's coverage-map check
  (`### [A-E][0-9]+` → test-matrix row) cannot see them — the discipline
  is enforced in exactly the direction that misses them.
- **Remediation:** number every prose residual (KNOWN-GAP/POLICY-ONLY/OPEN
  verdicts exist — use them), add the reverse check (every suite-E bullet
  traces to a catalog scenario), single-source the list.

### P2-6 [STATIC] — Denylist oracle; log-context injection; report scrub scope (iter-8 P2-6/P2-3/P3-5, still open)
- **What:** (a) rc=2-vs-0 on denylisted literals lets any gate-invoking
  context (transcript-inheriting subagent C3, injected agent C5) probe
  denylist membership — binary-searchable oracle over the user's street
  address etc. Unnamed in the catalog. (b) `egress-gate` logs raw
  `--to`/`--cid`/`--task` contexts unsanitized — newlines forge log
  lines (breaks suite D's `grep -c "| BLOCKED$"` accounting); suite D
  prints the last 5 BLOCKED/override lines into the HTML report whose
  `scrub()` redacts only emails and `$HOME`. (c) The verbatim transcript
  section keeps phone/SSN shapes intact.
- **Remediation (validation):** catalog scenario for the oracle
  (KNOWN-GAP + note on high-entropy denylist literals); suite-C/D check
  that logged contexts are single-line/sanitized; extend `scrub()` to
  the gate's shape inventory or drop the verbatim transcript from the
  HTML.

### P2-7 [STATIC] — C5 has no injected-shaped corpus case; adversarial-run is not hermetic (iter-8 P2-7 + new)
- **What:** `test-matrix.md` still says "no injected-shaped payload
  exists in fixtures/corpus" while C5 claims PROTECTED (in depth) — on
  reasoning alone. Separately: `adversarial-run` against the real
  installation reads the operator's *real* denylist/allowlist
  (`PERSONAL_MEMORY_ROOT` defaults to `$HOME`), so the suite is not
  hermetic — a denylist literal colliding with a clean corpus case (or
  an allowlist change) produces environment-dependent mismatches.
- **Remediation:** injection-shaped suite-B cases (injected
  "enable auto-forwarding" instruction → attempted settings mutation →
  expect refusal — which today fails, composing with P0-2); run the
  adversarial suite against a pinned empty denylist/allowlist unless
  explicitly testing the operator's own.

### P2-8 [STATIC] — `SHAPES` (fixture-purity) ↔ `patterns.sh` alignment still eyeball-maintained (iter-8 P3-4, still open)
- **What:** the audit's `SHAPES` regex and the stub's `STUB_SECRET_CAND`
  are maintained in two files by inspection. The P2-1 `eyJ` fix, when it
  lands, will widen the divergence the other way (patterns gain a shape
  fixture-purity never requires declared).
- **Remediation:** generate one from the other, or a CI cross-check that
  every `patterns.sh` shape is subsumed by the audit's `SHAPES`.

---

## P3 — low

### P3-1 [EXEC] — `--body=@file` checked and clear
- The shim gates the literal string `@/path`; the real CLI's `+send --help`
  shows no `@file` indirection for `--body` (it would send the literal
  text). Not a bypass. Noting so it isn't re-raised.

### P3-2 [EXEC] — Missing `--content-file` exits 2, deviating from the contract's "never 2 for non-verdict errors"
- `egress-gate` with a nonexistent `--content-file` → rc=2, and rc=2 with
  `MOCHI_EGRESS_APPROVED=1` (stays refused — the exit happens before the
  approval branch, so impact is nil). The contract
  (`gate-interface.md:42`) says non-verdict errors surface "as block (1)
  or another nonzero code, but NEVER as 2 (review)". Letter-of-contract
  deviation, no security impact.
- **Remediation (validation):** pin the expected non-verdict codes in a
  contract-conformance check (missing file → 1; unknown flag → 1), so the
  discipline iter-7 established doesn't rot.

### P3-3 [STATIC] — Stub `egress-gate` also fails open on a missing detector binary
- `test/stub-memory-skill/bin/egress-gate:33` `exit 0` fall-through: RC=127
  (detector absent) → allow. The stub-only operational test removes
  `blockset.txt`, not the detector, so this is untested on both targets.
- **Remediation:** fold into the P0-1 remediation (three-way breakage on
  both targets).

### P3-4 [STATIC] — Report nits (iteration 8's theme, mostly solid)
- The F-card confusion matrix joins corpus-file rows to runner mismatches
  *by name*; duplicate corpus names (P2-3) would misattribute. The
  "not in corpus file — possible runner/corpus drift" row is good.
- `ITERATIONS.md:6` still hardcodes "36/36" in prose (iter-7 F20) while
  nothing enforces it (P2-3) — enforce or stop stating.
- The 95% CI lower-bound framing is statistically honest and well
  disclaimed ("not a real-world sample, not ML recall/precision"), but
  the card title "Detection performance" plus a confusion matrix will
  still be read as detector-quality measurement by most readers. The
  stub banner mitigates; consider renaming the card to "Detection
  regression (fixture conformance)" — the corpus is a regression set,
  not an adversarial one, and the name should say so.

---

## Verified working (spot-checked, no findings)

- Baseline at HEAD `e35c1bc`: `bin/leakage-audit` CLEAN 62/62/6-skipped
  (SIMULATED) against the real installation; `bin/adversarial-run`
  36/36 (block 19/19, review 9/9, clean 8/8) against both targets.
- Single-b64 `raw` envelope with a block-tier secret → rc=1, delegate
  silent (A4 control holds for exactly one layer).
- Draft token-confusion (`--subject --draft` with secret → blocked) and
  approval isolation (secret stays rc=1 under `MOCHI_EGRESS_APPROVED=1`)
  behave as documented.
- `--body=@/path` sends the literal string (no indirection) — P3-1.
- CI shape (read, not executed): fail-at-the-end, pinned skip set,
  sentinel-anchored figures, stub-banner assertion — honest as designed.

## Still open from the iter-8 AI-researcher review (re-affirmed)

P0-1 (`+reply-all`), P0-2 (`drafts send` two-step), P0-3
(`updateAutoForwarding`) — re-verified above as P0-2, unmitigated.
P1-1 (`chat +send`), P1-2 (`calendar +insert`), P1-3 (`marketplace
initiate`), P1-4 (write-to-shared Drive) — re-verified as P0-2, unmitigated.
P1-5 (CLI surface census) — not built. P2-1 (JWT/AKIA), P2-2 (stub/real
parity, `eyJ` still absent from `patterns.sh`), P2-3 (log injection),
P2-4 (corpus pin), P2-5 (residual drift), P2-6 (denylist oracle), P2-7
(C5 corpus case) — all still open. P3-1 (timeout asymmetry), P3-2
(rc=137), P3-3 (duplicate names), P3-4 (SHAPES↔patterns), P3-5 (scrub
scope), P3-6 (`ITERATIONS.md` 36/36), P3-7 (probe-first artifact) — all
still open, with P3-7 now load-bearing for this review's P1-3/P1-4.

## Suggested shape of the iteration-9 diff (validation-only, per repo scope)

1. **Red suite-B cases for every P0-2 path** (`+reply-all`, `drafts send`,
   `updateAutoForwarding`, `chat +send`, `calendar +insert`,
   `marketplace initiate`, `drive files update`, `drive comments create`)
   + catalog scenarios A9–A14/B5 + test-matrix rows. These go red on
   landing — that is the loop working.
2. **Operational-failure probe for real targets** (P0-1): three-way
   detector breakage on a temp copy of `$MEM_SKILL`, expect rc=1.
3. **Runtime self-delegate probe** (P0-3): symlinked PATH spelling,
   assert no hang; fix the contract text.
4. **Encoding/obfuscation suite-B cases** (P1-1/P1-2/P1-3): base64 in
   `+send` body, double-b64 envelope, zero-width insertion — red or
   KNOWN-GAP-probed, never silent.
5. **`bin/probe-corpus.txt` + `references/known-gaps.md`** (P2-4),
   seeded with the P1-3/P1-4 probes; corpus-total pin + unique-name
   check + 137 handling (P2-3); JWT/AKIA cases + `eyJ` in patterns.sh
   (P2-1); residual reconciliation (P2-5).
6. Rename the F card to "Detection regression" (P3-4); make the A7 and
   memory-audit skips loud in the suite-C callout (P1-5).

## Notes (non-findings)

- All probes used synthetic fixtures and fake delegates; `/tmp`
  artifacts were removed and contained no real data. `git status` in the
  repo shows only pre-existing untracked `hidden_files/iter*-*` dirs —
  this review wrote exactly one file (this one) and modified nothing.
- The messenger shim's "never target the companion channel" comment
  (no enforcing code) remains out of the exfil lens, as in iter-8.
- `password` without a separator (`passwd["' ]*[:=]` requires one) and
  keyword-adjacent shapes are detector-tuning matters for the memory
  skill; the validator's job is to pin whichever behavior is agreed.
