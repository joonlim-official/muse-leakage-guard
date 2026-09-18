# Iteration-6 review — Senior AI researcher

Repository: `~/workspace/skills/muse-leakage-guard`, HEAD `5ff8950`
("Iteration 5: honest green"). Full-repo, unlimited-scope, READ-ONLY
review; no repo files modified. Followed the task brief's privacy
paragraph: no personal details used or needed; every payload value below
is the repo's own synthetic fixture (shaped to trip detectors, belonging
to nobody).

Scope note: this review concentrates on the five briefed focus areas
(corpus design, the stub's self-consistency loop, the chunked-exfiltration
residual, the E3 precision/recall framing, independent-extractor ground
truth) plus a full-repo sweep. Iter5's AI-researcher findings were
checked for resolution: F2 (approval isolation) and F7 (measurement
honesty) are fixed; F3 (residual-list divergence) is fixed — suite E now
tracks chunked exfiltration, out-of-band egress, B4, and E3; F5 (contract
underspecification), F6 (MIME realism), F8/F9 (residual/cron-PATH
precision) are substantially unaddressed and resurface below where they
bear on the focus areas.

## Findings

### R1 (P1) — The pinned 36-case corpus silently excludes entire attack classes; the exclusions are not enumerated anywhere

- **Severity:** P1
- **Evidence:** `bin/adversarial-corpus.txt` (36 cases; header documents
  only the `phone_bare10` and `clean_price` design decisions).
  `bin/adversarial-run` reads `IFS='|' read -r name want content` — one
  case per line, so **multiline payloads are inexpressible** in the corpus
  format.
- **Missing classes** (none represented, none disclaimed):
  - *Encoded/obfuscated single payloads:* URL-encoding, hex,
    double-base64, quoted-printable, base64 with MIME 76-char line
    wrapping, HTML entities. (Suite B's one encoding test base64-encodes
    bare fixture text — iter5 F6, still unaddressed.)
  - *Unicode:* fullwidth digits (U+FF10–FF19), homoglyph/lookalike
    characters, zero-width joiners/spaces inside tokens, Unicode dashes
    (U+2013) in SSN-like strings. `grep -E` operates byte-wise; no
    normalization exists anywhere in the pipeline.
  - *Multiline/boundary:* real PEM bodies are multiline — both corpus PEM
    cases are single-line; token split across lines, CRLF endings, token
    at input start/end, token adjacent to quotes/punctuation, empty and
    binary/non-UTF-8 inputs.
  - *Realistic MIME:* multipart with the token in part 2, RFC 2047
    encoded-word headers, token in an attachment filename.
  - *Subject-line shapes:* the corpus has no field dimension at all —
    every case is one undifferentiated content blob (iter5 F10's
    subject-coverage gap, still open).
  - *Near-miss boundaries:* 8- and 10-digit bare numbers in SSN context,
    sub-minimum key lengths (`api_key=` values under 16 chars),
    uppercase prefixes (`SK_LIVE_…` — patterns are lowercase-only; the
    corpus pins neither behavior as intended).
- **Recommendation:** Do not grow the corpus (owner pin stands). Instead:
  (a) enumerate the excluded classes as documented limitations in the
  corpus header, and (b) give `adversarial-run` a supplemental-corpus
  input (second file argument or `corpus.d/` directory) so attack-class
  packs can be executed without touching the pinned 36. Document the
  single-line format limitation alongside.
- **Residual if not fixed:** readers treat 36 cases as coverage; encoded,
  Unicode, multipart, and multiline exfiltration remain unprobed *and*
  unacknowledged — the exact "unexamined path" failure mode the repo's
  coverage discipline exists to prevent.

### R2 (P1) — Stub block-tier verdicts are tautological when the blockset is current; no doc states the circularity precisely

- **Severity:** P1
- **Evidence:** `test/stub-memory-skill/build/build-blockset.sh`
  sources "(1) every adversarial-corpus case with want=1" into
  `bin/blockset.txt`;
  `test/stub-memory-skill/bin/memory-egress-check` hashes each extracted
  candidate and looks it up in that set → for want=1 cases, rc=1 follows
  by construction whenever the blockset is current (CI pins this with
  `build-blockset.sh --check`).
- **What the self-consistency loop CAN catch** (worth stating, to avoid
  over-claiming uselessness): blockset staleness vs corpus+fixtures;
  want=0/2 label-vs-extractor inconsistency (a clean case matching a
  shape fails; a review case matching a blockset token fails); want=1
  cases whose tokens the patterns *cannot* extract (rc=0 ≠ want=1 fails
  loudly — a genuine corpus-maintenance invariant); and all plumbing
  (exit codes, approval isolation, shim delegation, report parsing).
- **What it CANNOT catch:** any shape absent from `patterns.sh` — build
  and runtime deliberately share that file ("can never disagree"), so the
  loop is blind to pattern-recall gaps by construction; semantic label
  errors (a mislabeled want=1 still passes); anything about the real gate.
- **Recommendation:** Add one paragraph to the target-kind note in
  `references/test-matrix.md` (or the "does NOT promise" section of
  `references/gate-interface.md`): "The block set is derived from the
  corpus's own want=1 cases, so block-tier agreement against the stub is
  a freshness check, not a detection check. The informative signal in a
  stub run is the want=0/2 cases and the plumbing." The current wording
  ("classifies by lookup in a declared set of synthetic tokens") names
  the mechanism but not the circularity.
- **Residual if not fixed:** block-tier 19/19 keeps being read as "the
  detector catches secrets" — the Clopper-Pearson bounds quantify
  sampling uncertainty but not this structural tautology.

### R3 (P2) — E3's exemption paragraph is logically inconsistent with E1's allowlist rule

- **Severity:** P2
- **Evidence:** `references/attack-surface.md` E3: "if the owner rules a
  specific nine-digit literal non-sensitive, the exemption path is the
  installation's `.egress-allowlist` (review tier only) — never a pattern
  carve-out." vs E1: the allowlist is for "review tier only; never for
  block-tier shapes." vs `bin/adversarial-corpus.txt`: `ssn_bare`
  expects rc=1 (block tier).
- **Analysis:** A block-tier verdict cannot be exempted through a
  review-tier-only mechanism without violating the contract's strongest
  negative rule ("approval must NEVER turn a block-tier 1 into 0",
  `references/gate-interface.md` — now conformance-tested per iter5).
  The three statements are jointly inconsistent; an operator reading E3
  will believe a per-literal exemption exists that the gate cannot honor.
  One of the three must change: make bare-9-digit review-tier, delete the
  exemption paragraph, or redefine allowlist semantics with an explicit
  carve-out and its own conformance test.
- **Recommendation:** Resolve the trilemma in the catalog; whichever
  direction, add the corresponding conformance case (mirroring the
  approval-isolation tests).
- **Residual if not fixed:** documented exemption path that cannot work;
  first real 9-digit false positive produces confusion about which doc
  governs.

### R4 (P2) — E3's precision/recall trade-off is asserted as axiom, with no instrumentation to ever measure it

- **Severity:** P2
- **Evidence:** `references/attack-surface.md` E3: "Deliberately
  conservative: a missed real SSN costs more than a refused order ID."
  No base rates, no false-positive/false-negative measurement, no
  per-shape instrumentation — `references/gate-interface.md` specifies
  the gate log as (timestamp, context, verdict) only, so shape-level FP
  rates cannot be estimated from suite D. Unacknowledged tension with E1:
  E1 warns that approval friction trains reflexive approval (a security
  risk in its own right); E3's conservative default *manufactures* that
  friction on every 9-digit number, with no tripwire defined for when the
  trade-off should be revisited.
- **Recommendation:** (a) Log the firing shape *class* (not the token)
  with each gate decision, enabling per-shape FP-rate estimation from the
  audit log; (b) reconcile E1/E3 in the catalog — state the operating
  assumption explicitly and name the evidence that would reverse it.
- **Residual if not fixed:** the trade-off is a permanent untestable
  axiom; the gate cannot learn whether its conservatism is calibrated.

### R5 (P2) — The chunked-exfiltration residual misdescribes the mechanism

- **Severity:** P2
- **Evidence:** `bin/leakage-audit` suite E: "compositional/chunked
  exfiltration across calls: the gate judges each send in isolation;
  content split across sends is never reassembled";
  `references/attack-surface.md` residual summary: "(the gate judges each
  send in isolation)".
- **Analysis — four imprecisions:**
  1. "Never reassembled" implies reassembly would fix it. It would not
     against encoding-aware splits (base64 chunks that decode only when
     joined) — and naive reassembly is defeated by splits at shape
     boundaries: `sk_live_` + `4eC39…` leaves the second fragment
     shape-free (note the first fragment alone still matches
     `sk_live_[A-Za-z0-9]+`, so effective chunking must split *inside*
     the random part — the residual says nothing about this
     shape-fragment mechanics).
  2. The precise bound is not "we don't reassemble" but: detection is a
     per-payload shape predicate, so *any partition of a secret into
     shape-free fragments is unobservable by construction*.
  3. No distinction between intra-conversation chunking (observable in
     principle with a session buffer) and cross-session/cross-channel
     chunking (requires persistent per-principal state — the actual
     infeasibility argument, compounded by the privacy cost of retaining
     sent content to join against).
  4. The residual is framed around block-tier secrets, but chunked
     review-tier figures also evade approval (each fragment clean) —
     the gap spans both tiers.
- **Recommendation:** Rewrite the residual with the shape-fragment
  mechanism, the two chunking scopes, the retention-cost argument, and
  both tiers.
- **Residual if not fixed:** readers either underestimate the gap
  ("just reassemble the sends") or mislocate it (block-tier only).

### R6 (P2) — The "real-data verification" paragraph names no labeling protocol

- **Severity:** P2
- **Evidence:** `README.md` ("What a real run reports"): "the
  installation can additionally run a real-data verification: real
  figures, addresses, and numbers through the real gates, reporting
  verdicts per check. That harness must live outside this repo and never
  be committed."
- **Analysis:** This is the repo's only path from self-consistency to
  actual detector-quality evidence — and as written it can reproduce the
  same circularity on real data: if the label author and the gate author
  are the same person, "verdicts per check" measure agreement-with-self
  again. A credible protocol needs: blind labeling (labels authored
  without seeing gate verdicts), a sampling plan, disagreement
  adjudication, and label-author/gate-author separation. None is
  specified.
- **Recommendation:** Specify the protocol, or mark the paragraph as a
  placeholder ("labeling protocol TBD — an unblinded run proves nothing
  beyond self-consistency").
- **Residual if not fixed:** a future real-data run claims detector
  quality while repeating the author-labels circularity the repo just
  spent iteration 5 disclaiming.

### R7 (P2) — No independent shape spec exists, so a second extractor implementation would encode the same guesses

- **Severity:** P2 (focus-area 5 verdict)
- **Evidence:** `references/gate-interface.md` still lacks the iter5-F5
  items: no normative shape definitions (only the stub's `patterns.sh`,
  which is an implementation, not a spec), no error taxonomy, no latency
  bound, no stdin/file equivalence requirement, no gate-log schema.
- **What a second implementation would buy:** catches tool-semantics bugs
  (grep ERE `\b`/interval syntax vs another regex engine),
  build-pipeline bugs (locale-dependent `sort -u`, sha256 `cut`), and
  build/runtime drift — *if* it does not share `patterns.sh`.
- **What it would cost:** doubled maintenance per pattern change;
  shallow independence (same author's mental model — a shape nobody
  thought of is missing from both); agreement still ≠ ground truth
  (ground truth = blind labels, still missing per R6); poor value/tax
  ratio against a 36-case pinned corpus.
- **Recommendation:** Do not build a second production extractor.
  Instead: (a) add the normative shape spec to `gate-interface.md` (the
  missing F5 piece — any second implementation would be built against it
  anyway); (b) add a differential fuzz harness: mutate corpus tokens
  (case flips, separator swaps, boundary padding, truncation) against a
  small expectation table — catches implementation brittleness without a
  second implementation; (c) document that ground truth means a
  blind-labeled corpus, not a second implementation of the same shapes.
- **Residual if not fixed:** the shared-`patterns.sh` blind spot stays
  unexamined; a future second implementation would be built on sand
  (no spec to be independent *against*).

### R8 (P3) — CI summary greps for the pre-iter5 "recall" terminology and silently drops the tier line

- **Severity:** P3
- **Evidence:** `.github/workflows/validate.yml`, "Summarize the
  validation" step: `grep -aE 'block-tier recall' … || true`, but
  `bin/adversarial-run` has printed "block-tier pass" since iteration 5's
  measurement-honesty change. The `|| true` swallows the miss, so the
  step summary silently loses the tier breakdown it was meant to carry.
- **Recommendation:** Grep `block-tier pass` (or the `·`-separated tier
  line) instead.
- **Residual if not fixed:** CI summaries under-report; stale "recall"
  terminology lingers in the workflow.

### R9 (P3) — Brief-gate payload counts are wrong in two docs

- **Severity:** P3
- **Evidence:** `references/test-matrix.md:42` ("same six →
  `brief-gate` | 1/1/1/2/2/0") and `:102` ("the six payloads through
  `brief-gate` → 1/1/1/2/2/0"); `README.md:44` B8 ("all seven payloads
  above | `1 / 1 / 1 / 2 / 2 / 0 / 0`"). Actual: `bin/leakage-audit` runs
  **seven** `gate_expect` calls per gate (clean, secret, secret2, ssn,
  card, figure, phone) → verdicts 0/1/1/1/1/2/2. The test-matrix rows are
  wrong on count *and* values; the README row has seven numbers but the
  wrong sequence (drops a block-tier 1).
- **Recommendation:** Fix both to seven payloads with the correct
  verdicts — the same prose-vs-test drift class as iter5 F10.
- **Residual if not fixed:** doc drift compounds; a reader cross-checking
  the audit against the matrix finds contradictions.

### R10 (P3) — `ITERATIONS.md` still hardcodes "36/36"

- **Severity:** P3
- **Evidence:** `ITERATIONS.md` validation line: "`bin/adversarial-run`
  36/36". README was fixed per iter5 F7c ("every corpus case matched")
  but this file was missed.
- **Recommendation:** Same dynamic wording as the README.
- **Residual if not fixed:** rots on the next corpus change; minor.

### R11 (P3) — Stub `die()` conflates internal error with the review-tier verdict

- **Severity:** P3
- **Evidence:**
  `test/stub-memory-skill/bin/memory-egress-check`: `die()` exits 2 on
  missing `blockset.txt`/unreadable input — but 2 is also review-tier.
  The stub `egress-gate` maps rc=2 + `MOCHI_EGRESS_APPROVED=1` → allow
  (rc=0). So a missing blockset (fail-closed intent) becomes fail-open
  whenever approval is set. This is the error-taxonomy gap from iter5 F5,
  still present in the contract.
- **Recommendation:** Distinct error exit code (3, matching
  `adversarial-run`'s runner-failed convention) and add the error
  taxonomy to `references/gate-interface.md`.
- **Residual if not fixed:** stub-only, low blast radius — but it is the
  exact failure-mode class the contract was asked to pin down.

## Notes (non-findings)

- Fixture purity verified intact: every secret-shaped token extractable
  from the corpus, guard fixtures, and stub fixtures is declared in
  `bin/fixtures/SYNTHETIC.txt` (mechanical `comm` check, zero
  undeclared).
- The corpus's clean set contains genuine boundary discipline worth
  keeping: `shell_var`/`shell_brace` pin the `$1`/`${10}` non-match,
  `order_num`/`zip_code`/`date_iso` pin digit-run non-matches. These are
  the corpus's most informative cases precisely because they are *not*
  tautological (R2).
- Privacy paragraph compliance: all values cited above are the repo's own
  synthetic fixtures; no external personal data was used or needed.
