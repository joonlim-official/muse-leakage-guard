# Iteration-7 review — Senior AI researcher

Repository: `~/workspace/skills/muse-leakage-guard`, HEAD `e20a819`
("Iteration 6: CI fails honest"). Full-repo, unlimited-scope, READ-ONLY
review; no repo files modified, no live-fire (`MOCHI_LIVE_FIRE` never
set), `local.env` untouched. All payload values probed below are the
repo's own synthetic fixtures or trivial synthetic shapes (belonging to
nobody); probes ran against the real installed gate only in read/scan
mode (exit-code observation, nothing sent).

Scope note: centered on the six briefed focus areas (compositional
exfiltration, suite/catalog divergence, approval isolation, threat-model
completeness, out-of-band egress, corpus methodology) plus a full-repo
sweep. Iteration 6 was CI/reporting-only, so all ten open items from the
iter6 AI-researcher review (R1–R7, R9–R11; R8 was fixed) were re-verified
at HEAD — their status is recorded below rather than re-argued.

Headline: approval isolation is real in every code path I could find
(stub gates, real gate, both shims), and the out-of-band residual is
honestly worded. The serious problems are (1) a whole exfiltration
family — *information* disclosure without *shaped tokens* — that the
threat model does not contain at all, and I verified three live
single-send evasions against the real gate (spelled-out figures,
fullwidth-digit SSN, double-base64 key, all rc=0); (2) the two most
important residuals (chunked exfiltration, out-of-band egress) have no
catalog scenario rows, so they evade the repo's own coverage discipline
and its mechanical scenario-mapping check; (3) five test-matrix "Covered
by" claims that exceed what the suites actually enforce.

## Verified working (no findings)

- **Approval isolation is real and complete across code paths.** Stub
  `egress-gate` and `brief-gate` exit 1 on block-tier *before* consulting
  the approval flag/env; the real `egress-gate` only enters the
  `APPROVED` branch under `grc -eq 2`
  (`~/workspace/skills/personal-memory-system/bin/egress-gate:55-70`).
  Both shims pass `--approved` solely from `MOCHI_EGRESS_APPROVED=1`.
  Live probes against the stub: block-tier+approval → rc=1 (twice),
  review-tier+approval → rc=0, review-tier → rc=2 — all as contracted.
  The audit's conformance cases (audit:406-407) exercise this on the
  egress paths. One gap remains: brief-gate+approval has no conformance
  case (F11).
- **Subject/body field-splitting within one send is handled.** The real
  shim concatenates `subject:` + body into one gated blob before calling
  the gate (shim:60-80), so splitting a token across the two fields does
  not evade detection.
- **Out-of-band egress residual is honestly worded** (audit:629;
  attack-surface.md:303-305): "curl, webhooks, unshimmed CLIs, and any
  other non-shimmed path … only shimmed send paths are gated." No
  overclaim found in the wording itself — but see F2 (it is not a
  catalog scenario).
- **R8 (iter6) confirmed fixed**: the dead `block-tier recall` grep is
  gone; the summary is sentinel-based.

## Findings

### F1 (P1) — Threat model has no "information without shapes" family; three live single-send evasions verified

- **Severity:** P1
- **Evidence:** Every catalog scenario (A1–E3) models private data as
  *shaped tokens* (key prefixes, SSN/card regexes, dollar figures, phone
  patterns). The gate is a shape predicate over literal text, not an
  information-flow control — but no scenario says so. Probes against the
  real `memory-egress-check` (scan-only, nothing sent):
  - `twelve thousand five hundred dollars` (spelled-out figure) → rc=0
  - fullwidth-digit `１２３-４５-６７８９` (U+FF10–FF19) → rc=0
  - double-base64 of a `sk_live_…` key → rc=0 (bare single base64 → rc=0
    as well)
  
  The same family includes paraphrased figures ("about twelve and a half
  k"), aggregates/qualitatives ("your balance grew ~20%"), and yes/no
  oracles ("is it above $X?" → 1 bit per send). None appears anywhere in
  the catalog, the corpus, or suite E.
- **Recommendation:** Add scenario row(s) (e.g. E4: compositional /
  verbalized / paraphrased single-send disclosure) with an honest
  verdict (OPEN GAP or POLICY-ONLY), stating the precise bound: the gate
  observes literal shapes, so any disclosure that carries the
  *information* without the *shape* is unobservable by construction.
  Add at least one corpus probe-first case per sub-class (verbalized,
  fullwidth, double-encoded) as documented-known-gap cases, not as
  expected-block cases.
- **Residual if not fixed:** readers equate "secrets are blocked" with
  "disclosure is prevented"; the cheapest evasions (rewording a number)
  are unexamined *and* unacknowledged — the exact failure mode the
  skill's coverage discipline exists to prevent.

### F2 (P1) — Chunked exfiltration and out-of-band egress have no catalog scenario rows; they evade the coverage discipline

- **Severity:** P1
- **Evidence:** `references/attack-surface.md` "Coverage discipline":
  "A new exfiltration path is handled by: (1) adding a scenario to this
  catalog with its verdict, (2) adding the control, (3) adding the test."
  The mechanical check at `bin/leakage-audit:555` fails the audit if any
  `### XN.` scenario lacks a test-matrix row — but it only sees
  cataloged scenarios. Compositional/chunked exfiltration and out-of-band
  egress exist *only* as residual prose (attack-surface.md:303-305;
  audit:628-629), with no `### XN.` row, so the discipline's own
  enforcement cannot see them. Same for voice calls (audit:626, no
  catalog row).
- **Recommendation:** Give each tracked residual a scenario row with its
  honest verdict (they are already "reported, never silent" — this only
  brings them under the mapping discipline), or explicitly document that
  residuals are exempt from the discipline and why.
- **Residual if not fixed:** the skill's headline guarantee ("a path with
  no scenario is an unexamined path") is violated by its own most
  important residuals.

### F3 (P2) — Chunked-exfiltration residual misdescribes the mechanism and understates exposure (iter6 R5, still open)

- **Severity:** P2
- **Evidence:** `bin/leakage-audit:628` ("content split across sends is
  never reassembled"); `references/attack-surface.md:303-305` ("the gate
  judges each send in isolation"). Unchanged at HEAD. Four imprecisions
  from iter6 R5 stand: (1) "never reassembled" implies reassembly would
  fix it — false against shape-fragment splits (a secret split *inside*
  the random part, e.g. `sk_live_` + `4eC39…`, leaves fragments with no
  matchable shape) and encoding-aware splits; (2) the precise bound is
  "any partition of a secret into shape-free fragments is unobservable by
  construction," not "we don't reassemble"; (3) no intra-session vs
  cross-session distinction (the latter needs persistent per-principal
  state plus the privacy cost of retaining sent content to join against
  — the actual infeasibility argument); (4) framed as block-tier only,
  but chunked review-tier figures evade approval the same way — the gap
  spans both tiers.
- **Recommendation:** Rewrite the residual with the shape-fragment
  mechanism, the two chunking scopes, the retention-cost argument, and
  both tiers.
- **Residual if not fixed:** readers either underestimate the gap ("just
  reassemble") or mislocate it (block-tier only).

### F4 (P2) — A4 claim "encoded payloads are decoded before the check" exceeds enforcement

- **Severity:** P2
- **Evidence:** `references/test-matrix.md` A4 row: "B: card inside
  base64 MIME → raw `messages.send` blocked"; `bin/leakage-audit:411-412`
  base64url-encodes the *bare fixture text* — no MIME structure, no
  headers, no part-level encoding (iter5 F6 MIME-realism, still open).
  The real shim decodes only the outer `raw` once
  (shim ~lines 95–115): a secret inside a base64 *MIME part* (the
  realistic nesting) is never decoded — verified conceptually by code
  reading, and bare/double base64 of secrets probes rc=0 on the real
  gate (see F1).
- **Recommendation:** Narrow the A4 "Covered by" to "single
  base64url-encoded raw bodies are decoded once"; catalog nested /
  part-level / non-base64 encodings as a residual.
- **Residual if not fixed:** the catalog claims encoding-robustness the
  single test does not establish.

### F5 (P2) — A5 "drafts never leave the account" is false as a terminal claim; the draft→send transition is unexamined

- **Severity:** P2
- **Evidence:** `references/attack-surface.md` A5: "PROTECTED (by
  non-action) — drafts never leave the account … so gating would be pure
  friction." `bin/leakage-audit:408` verifies `--draft` passes through,
  but nothing verifies the draft→send transition: a draft saved with
  secrets can later be sent from the Gmail UI (or any non-shimmed path)
  with no gate in the loop. The verdict rests on drafts being terminal;
  they are not.
- **Recommendation:** Recast A5 as POLICY-ONLY with the draft→send
  transition named as the residual, or add the control (e.g. the audit
  warns when block-tier content is saved to a draft).
- **Residual if not fixed:** the highest-friction-free path to
  exfiltrating a secret the gate already saw and waved through.

### F6 (P2) — A7 "Covered by" overstates a static grep as interception inheritance

- **Severity:** P2
- **Evidence:** `references/test-matrix.md` A7: "Covered by: C: cron
  prompt dirs must wire the shim PATH export." But
  `bin/leakage-audit:630` (suite E) honestly frames the same check as
  "static/syntactic: it proves the mandate is written in the prompt
  files, not that every scheduled worker honored it at runtime." The
  catalog headline verdict is "PROTECTED (by audit, after a real catch)"
  while the residual list concedes the mechanism is mandate-only. The
  map's "Covered by" prose ("scheduled workers inherit interception")
  matches neither.
- **Recommendation:** Align the map wording with the suite-E framing;
  consider downgrading A7's headline verdict to POLICY-ONLY to match the
  actual mechanism.
- **Residual if not fixed:** a reader of the map alone believes cron
  interception is mechanically assured.

### F7 (P2) — C5 "Covered by" cites injected-shaped payloads that do not exist

- **Severity:** P2
- **Evidence:** `references/test-matrix.md` C5: "Covered by: B: gate
  red-team over injected-shaped payloads; C: brief-gate + shim
  mandates." `bin/fixtures/` contains exactly
  card/clean/figure/phone/secret/secret2/ssn — no injected-shaped
  payload exists anywhere in fixtures or the corpus. The B-claim is
  factually wrong; the actual defense is mandate-level (injected
  instructions are data) plus the gate as backstop.
- **Recommendation:** Correct "Covered by" to what B does (shape
  detection over direct payloads) and state the injection defense as
  mandate + defense-in-depth, which is what the catalog's own C5 details
  already say.
- **Residual if not fixed:** phantom coverage for the prompt-injection
  scenario — the one adversary class most likely to be tested by a
  reader.

### F8 (P2) — D1/D2 "Covered by" cites controls the harness never exercises

- **Severity:** P2
- **Evidence:** `references/test-matrix.md` D1/D2: "Covered by: C:
  memory-audit opt-in; `memory-guard` pre-write scan." The audit never
  invokes `memory-guard` on a write; `memory-audit` is opt-in and a
  *pinned skip* in CI ("memory-audit run"); the stub — the only CI
  target — ships neither binary. Against stub targets, D1/D2 mechanical
  coverage is vacuous.
- **Recommendation:** Qualify the D1/D2 map rows by target kind
  (real-installation-only, mandate-level), or add a stub-side
  memory-guard double so the contract is exercised where CI runs.
- **Residual if not fixed:** "PROTECTED (at write time)" reads as
  harness-verified; it is not verified anywhere the harness runs in CI.

### F9 (P2) — B3 "Covered by" claims a denylist scan that cannot see private figures

- **Severity:** P2
- **Evidence:** `references/test-matrix.md` B3: "Covered by: C: same
  denylist scan (public repo content)." B3's scenario: "a document …
  embeds private figures, then the artifact is shared." The suite-C scan
  (`bin/leakage-audit:558-575`) is fixed-string (`grep -lF`) matching of
  the user's denylisted *literals* against tracked files — it cannot
  catch private figures (synthetic figures are explicitly declared
  *allowed* in `bin/fixtures/SYNTHETIC.txt`). A report containing a real
  balance would pass. In CI the check is additionally a pinned skip ("no
  egress denylist").
- **Recommendation:** Narrow B3's "Covered by" to secret-shaped /
  denylisted-literal content; name the figure-in-shared-artifact gap.
- **Residual if not fixed:** B3's POLICY-ONLY verdict looks
  backstopped by a scan that cannot see its scenario's payload.

### F10 (P2) — E3/E1/contract trilemma still unresolved (iter6 R3, unchanged)

- **Severity:** P2
- **Evidence:** `references/attack-surface.md` E3: "if the owner rules a
  specific nine-digit literal non-sensitive, the exemption path is the
  installation's `.egress-allowlist` (review tier only) — never a pattern
  carve-out" vs E1: allowlist is "review tier only; never for block-tier
  shapes" vs `bin/adversarial-corpus.txt`: `ssn_bare` expects rc=1
  (block tier) vs `references/gate-interface.md`: "It must NEVER turn a
  block-tier 1 into 0." Jointly inconsistent: a block-tier verdict
  cannot be exempted through a review-tier-only mechanism. All four
  texts unchanged at HEAD.
- **Recommendation:** Resolve the trilemma in the catalog (re-tier
  bare-9-digit, delete the exemption paragraph, or redefine allowlist
  semantics) and add the corresponding conformance case.
- **Residual if not fixed:** a documented exemption path that cannot
  work; the first real 9-digit false positive produces a which-doc-
  governs dispute.

### F11 (P2) — Approval-isolation conformance has no brief-gate case

- **Severity:** P2
- **Evidence:** `bin/leakage-audit:406-407` pin block-tier+approval → rc=1
  for gmail `+send` and messenger `send` only. The stub `brief-gate` is
  *correct* (exits 1 on block-tier before consulting approval), but no
  audit case pins it — a future brief-gate edit could weaken
  approval-isolation with no red test. The contract
  (`references/gate-interface.md`) states the rule for both gates.
- **Recommendation:** Add brief-gate approval-isolation cases mirroring
  406-407 (secret brief + `MOCHI_EGRESS_APPROVED=1` → rc=1).
- **Residual if not fixed:** the isolation guarantee is tested on two of
  three gate entry points.

### F12 (P2) — Probe-first corpus-expansion methodology is undocumented

- **Severity:** P2
- **Evidence:** The brief's stated methodology — new corpus cases are
  probe-first (probed against the real gate; mismatches become KNOWN-GAP
  entries, never failing corpus cases) — appears nowhere: `grep -ri
  probe` over README, CONTRIBUTING, references/, bin/ returns nothing.
  `CONTRIBUTING.md` documents "Adding an attack-surface scenario" but
  not "Adding a corpus case"; the corpus header documents two
  per-case design decisions but no expansion rule.
- **Recommendation:** Document the methodology in `CONTRIBUTING.md`
  (or the corpus header): probe against the real gate first, record the
  verdict, mismatches → KNOWN-GAP entries, never new expected-fail
  corpus cases.
- **Residual if not fixed:** the next contributor adds an aspirational
  expected-block case for an evasion the gate does not catch (e.g. any
  of F1's probes) and CI goes red on a true negative — or worse, the
  case is "fixed" by weakening the corpus.

### F13 (P2) — Corpus excluded classes still unenumerated (iter6 R1, now with live evidence)

- **Severity:** P2
- **Evidence:** `bin/adversarial-corpus.txt` header documents only
  `phone_bare10` and `clean_price`. Still inexpressible/unrepresented:
  encoded/obfuscated payloads, Unicode (fullwidth/homoglyph/zero-width),
  multiline PEM bodies (both corpus PEM cases are single-line), multipart
  MIME, subject-line dimension, near-miss boundaries. F1's probes
  (spelled-out, fullwidth, double-base64 → all rc=0) show these are not
  hypothetical: they are the live evasion surface, and the corpus
  neither covers nor disclaims them.
- **Recommendation:** Per iter6 R1: enumerate the excluded classes as
  documented limitations in the corpus header (do not grow the pinned
  36), and note the single-line format limitation.
- **Residual if not fixed:** 36/36 keeps being read as coverage of the
  attack surface rather than of 36 chosen points.

### F14 (P2) — Stub block-tier tautology still unnamed (iter6 R2)

- **Severity:** P2
- **Evidence:** `test/stub-memory-skill/build/build-blockset.sh` sources
  every want=1 corpus case into `blockset.txt`; the stub detector
  decides by hash lookup in that set — block-tier agreement is freshness,
  not detection. `references/gate-interface.md` "What the audit does
  NOT promise" and `references/test-matrix.md`'s target-kind note name
  the mechanism ("classifies by lookup in a declared set") but not the
  circularity.
- **Recommendation:** One paragraph: "The block set is derived from the
  corpus's own want=1 cases, so block-tier agreement against the stub is
  a freshness check, not a detection check. The informative signal in a
  stub run is the want=0/2 cases and the plumbing."
- **Residual if not fixed:** block-tier 19/19 keeps being read as
  "the detector catches secrets."

### F15 (P2) — E3 trade-off still uninstrumented (iter6 R4)

- **Severity:** P2
- **Evidence:** `references/attack-surface.md` E3: "a missed real SSN
  costs more than a refused order ID" — still no base rates, no
  per-shape FP measurement. Confirmed the log schema blocks it: the real
  gate logs `ts | context | verdict` only
  (`~/workspace/skills/personal-memory-system/bin/egress-gate:72`), so
  shape-level FP rates cannot be estimated from suite D. Tension with E1
  (approval fatigue as a security risk) unacknowledged.
- **Recommendation:** Log the firing shape *class* (not the token) with
  each decision; reconcile E1/E3 in the catalog with the operating
  assumption stated and the evidence that would reverse it.
- **Residual if not fixed:** the conservatism is a permanent untestable
  axiom; the gate cannot learn whether it is calibrated.

### F16 (P2) — Real-data verification still names no labeling protocol (iter6 R6)

- **Severity:** P2
- **Evidence:** `README.md:96-99` unchanged: "real figures, addresses,
  and numbers through the real gates, reporting verdicts per check"
  with no blind-labeling requirement, sampling plan, disagreement
  adjudication, or label-author/gate-author separation. An unblinded
  run re-measures agreement-with-self — the circularity iteration 5
  disclaimed for the stub.
- **Recommendation:** Specify the protocol, or mark the paragraph
  "labeling protocol TBD — an unblinded run proves nothing beyond
  self-consistency."
- **Residual if not fixed:** a future real-data run claims detector
  quality while repeating the author-labels circularity.

### F17 (P2) — No normative shape spec (iter6 R7 / iter5 F5)

- **Severity:** P2
- **Evidence:** `references/gate-interface.md` still has no normative
  shape definitions (only the stub's `patterns.sh`, an implementation),
  no error taxonomy, no latency bound, no stdin/file equivalence
  requirement, no gate-log schema. A second extractor implementation
  would encode the same author's guesses — agreement still ≠ ground
  truth.
- **Recommendation:** Per iter6 R7: add the normative shape spec to
  `gate-interface.md`; add a differential fuzz harness (mutate corpus
  tokens: case flips, separator swaps, boundary padding, truncation);
  document that ground truth means blind labels, not a second
  implementation.
- **Residual if not fixed:** the shared-`patterns.sh` blind spot stays
  unexamined; any future second implementation is built on sand.

### F18 (P3) — Brief-gate payload counts wrong in two docs (iter6 R9, unchanged)

- **Severity:** P3
- **Evidence:** `references/test-matrix.md:42` and `:102` ("the six
  payloads through `brief-gate` → 1/1/1/2/2/0"); `README.md:44` ("all
  seven payloads above" → `1 / 1 / 1 / 2 / 2 / 0 / 0`). Actual:
  `bin/leakage-audit:383-390` runs **seven** `gate_expect` calls per gate
  (clean, secret, secret2, ssn, card, figure, phone) → verdicts
  **0/1/1/1/1/2/2**. The matrix rows are wrong on count *and* values;
  the README row has seven numbers in the wrong sequence (drops a
  block-tier 1).
- **Recommendation:** Fix both to seven payloads with verdicts
  0/1/1/1/1/2/2.
- **Residual if not fixed:** prose-vs-test drift compounds; cross-
  checking the audit against the matrix yields contradictions.

### F19 (P3) — Stub `die()` still conflates internal error with review-tier (iter6 R11)

- **Severity:** P3
- **Evidence:** `test/stub-memory-skill/bin/memory-egress-check:31`:
  `die() { …; exit 2; }` on missing blockset/unreadable input — but 2 is
  review-tier, and the stub `egress-gate` maps rc=2 +
  `MOCHI_EGRESS_APPROVED=1` → allow (rc=0). A missing blockset
  (fail-closed intent) becomes fail-open whenever approval is set.
- **Recommendation:** Distinct error exit code (3, matching
  `adversarial-run`'s runner-failed convention) plus the error taxonomy
  in `references/gate-interface.md`.
- **Residual if not fixed:** stub-only, low blast radius — but the exact
  failure-mode class the contract was asked to pin down.

### F20 (P3) — `ITERATIONS.md:6` still hardcodes "36/36" in the standing validation instruction

- **Severity:** P3
- **Evidence:** `ITERATIONS.md:6`: "(`bash -n`, `bin/leakage-audit`
  CLEAN, `bin/adversarial-run` 36/36)". Historical entries elsewhere in
  the file are fine as history; line 6 is an instruction and rots on the
  next corpus change. (README was fixed per iter5 F7c; this line was
  missed.)
- **Recommendation:** Same dynamic wording as the README ("every corpus
  case matched").
- **Residual if not fixed:** minor rot; instruction contradicts the
  corpus on the next case-count change.

### F21 (P3) — Claimed-but-untested subcommands: messenger `edit`, gmail `+forward`, `--dry-run`

- **Severity:** P3
- **Evidence:** `references/gate-interface.md` shim contract claims
  messenger `send`/`edit`, gmail `+send`/`+reply`/`+forward`, and
  `--draft`/`--dry-run` passthrough. `bin/leakage-audit:397-420` tests
  `send`, `+send`, `+reply`, `--draft` — never `edit`, `+forward`, or
  `--dry-run`. The A6 map row ("messenger send secret blocked; clean
  passes") reflects only what is tested, but the catalog A6 scenario is
  "send/edit".
- **Recommendation:** Add the three missing red-team cases (or narrow
  the contract claims).
- **Residual if not fixed:** small untested surface on paths the
  contract says are covered.

### F22 (P3) — Voice calls reported in suite E with no catalog scenario

- **Severity:** P3
- **Evidence:** `bin/leakage-audit:626` reports "voice calls: phone
  tool's own confirmation flow (out of text-gate scope)" every run, but
  no `### XN.` scenario exists — same coverage-discipline gap as F2 on
  a smaller scale, and the mechanical scenario-mapping check
  (audit:555) cannot see it.
- **Recommendation:** Fold into the F2 fix (scenario row or documented
  exemption).
- **Residual if not fixed:** minor; a reported residual outside the
  mapping discipline.

### F23 (P3) — Gate's verbose refusal echoes matched tokens into agent context; no catalog row considers diagnostic output as a carrier

- **Severity:** P3
- **Evidence:** The real `memory-egress-check` prints up to 20 matched
  lines including the tokens (`--- BLOCKED:` /
  `--- review:` sections), and `egress-gate` relays them as `$detail`
  to stderr
  (`~/workspace/skills/personal-memory-system/bin/egress-gate:52-70`).
  This is inside the free-share zone by design (the agent already held
  the content), and any onward external send re-hits the gate — so the
  blast radius is small. But the catalog's threat model never considers
  the gate's *own* output as an exfiltration carrier (e.g. an agent
  quoting a refusal into a draft, a log, or a UI-sent message).
- **Recommendation:** One catalog line: refusal diagnostics echo
  matched content to the agent's context (in-zone by design); agents
  must not forward refusal text externally without re-gating (which the
  gate enforces anyway on shimmed paths).
- **Residual if not fixed:** negligible mechanically, but the threat
  model should be complete about its own outputs.

## Notes (non-findings)

- Fixture purity intact (spot-checked): corpus values are synthetic
  shapes belonging to nobody; no real private data was used or needed.
- The corpus's clean set retains genuine boundary discipline
  (`shell_var`/`shell_brace`, `order_num`/`zip_code`/`date_iso`) — these
  non-tautological cases are the corpus's most informative (cf. F14).
- Privacy paragraph compliance: every value cited above is the repo's
  own synthetic fixture or a trivial synthetic probe shape; no external
  personal data used.

## Suggested shape of the iteration-7 diff (validation-only, per repo scope)

1. Catalog: add scenario rows for compositional/verbalized disclosure
   (F1), chunked exfiltration, out-of-band egress, voice calls (F2/F22)
   with honest verdicts; fix E3 trilemma (F10); recast A5 (F5); align A7
   verdict with its mechanism (F6).
2. Test matrix: correct the five overstated "Covered by" claims
   (F4, F6, F7, F8, F9); fix brief-gate counts (F18); add the missing
   red-team cases — brief-gate approval isolation (F11), messenger
   `edit`, gmail `+forward`, `--dry-run` (F21).
3. Docs: probe-first corpus methodology in CONTRIBUTING.md (F12);
   excluded corpus classes in the corpus header (F13); tautology
   paragraph (F14); real-data labeling protocol or TBD marker (F16);
   normative shape-spec items in gate-interface.md (F17);
   `ITERATIONS.md:6` dynamic wording (F20).
4. Stub: `die()` exit 3 (F19).
5. Instrumentation: log shape class with gate decisions (F15).
