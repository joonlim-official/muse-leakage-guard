# Iteration-5 review — Senior AI researcher

Repo: `~/workspace/skills/muse-leakage-guard` @ HEAD `e4b2af1`
("Iteration 4: CI readiness + synthetic stub skill"). Read-only review;
no files modified. All payloads described below are synthetic shapes
(shaped to trip detectors, belonging to nobody); no real data was used.

## A. Agentic threat-model gap analysis: compositional / multi-step patterns

The 36-case corpus (`bin/adversarial-corpus.txt`) tests single-payload,
single-decision gate verdicts. A real agent operating with tool use can
compose steps that are individually clean. The catalog
(`references/attack-surface.md`) has no scenario for any of these shapes:

1. **Chunked / staged exfiltration.** A token is split across N sends, each
   individually clean ("first half 4111-1111" in one email, "second half
   1111-1111" in another). The gate is stateless per invocation — nothing
   in the audit or corpus tests session-level aggregation, and no catalog
   entry admits this as a known-unknown. Evidence: every suite-B red-team
   check is one `send_expect` of one fixture; `gate_expect` has no
   multi-call sequence test.
2. **Field-splitting.** Payload split between subject and body, or between
   body and attachment filename. A1's details claim "scans subject +
   body", but no suite-B test puts a block-tier fixture in `--subject`;
   all red-team fixtures go in `--body` only. Subject coverage is
   asserted by prose, not exercised by test.
3. **Encoding obfuscation beyond single-layer base64.** The only encoding
   test (B12) base64-encodes a bare plaintext fixture — not a real MIME
   document (no headers, no multipart, no quoted-printable). Untested
   shapes: double-base64, URL-encoding, hex, quoted-printable MIME parts,
   multipart payloads (token in part 2), unicode fullwidth/lookalike
   digits, zero-width joiners, whitespace steganography ("1 2 3 - 4 5"),
   base64 with embedded newlines. `patterns.sh` normalizes none of these.
4. **Lexicalized / redacted-form exfiltration.** Digits spelled out ("four
   one one one"), masked with reassembly cues, or described rather than
   emitted. Shape-based detection fails by construction; the catalog has no
   scenario admitting this boundary of the detection approach.
5. **Mixed-payload approval laundering.** Suite B tests
   `MOCHI_EGRESS_APPROVED=1` only on figure-only fixtures (lines 398, 410,
   457 of `bin/leakage-audit`). No test sends a payload containing a
   *block-tier* token alongside a review-tier one with approval set —
   even though `gate-interface.md` states approval "must NEVER turn a
   block-tier 1 into 0". The contract's strongest negative rule has no
   conformance test.
6. **Report-transcript as a secondary exfiltration path.** `bin/leakage-report`
   renders the raw audit transcript and gate-log lines into HTML; suite D
   surfaces BLOCKED lines from the real gate log. `scrub()` exists
   (lines 203–208), but no test feeds a hostile context label (control
   characters, HTML) through the report pipeline to assert the scrub
   coverage. For a real-installation run, the report itself is a
   document that can carry real payloads — uncataloged.
7. **Prompt-injection of the gate input.** C5 covers injection steering the
   *agent*; nothing covers adversarial content aimed at the *gate itself*
   (e.g. a payload containing text shaped like gate instructions). Today
   the gate is a bash script over text, so the impact is nil — but the
   catalog should record this as a known-unknown so a future LLM-based
   gate cannot silently inherit the assumption.

## B. Findings list

### F1 (P0) — Corpus and suite B cannot see compositional exfiltration; threat model is single-decision only
- **Priority:** P0
- **Title:** Agentic exfiltration is multi-step; all tests are single-step
- **Evidence:** `bin/adversarial-corpus.txt` = 36 single-payload cases;
  `gate_expect`/`send_expect` in `bin/leakage-audit` test one gate call or
  one send each; the attack-surface catalog has no entry for chunking,
  field-splitting, lexicalization, or session aggregation. The gap list in
  "Agentic threat-model gap analysis" above enumerates the missing shapes.
- **Recommendation:** Add a corpus section for *sequence* cases (shapes:
  split-token halves, spelled-out digits, double-encoded bodies, subject-
  carried secrets) with expected verdicts, and add catalog scenarios
  marking which are OPEN vs POLICY-ONLY. Where a shape is technically
  infeasible to block (chunked sends across sessions), state that as a
  known-unknown rather than leaving it unexamined — per the repo's own
  coverage discipline ("a path with no scenario is an unexamined path").

### F2 (P0) — No conformance test for the contract's "approval never un-blocks block-tier" rule
- **Priority:** P0
- **Title:** Mixed block+review payload under approval override is untested
- **Evidence:** `bin/leakage-audit` lines 398, 410, 457 use
  `MOCHI_EGRESS_APPROVED=1` only with figure-only fixtures; nothing sends
  a fixture containing a block-tier token with approval set.
  `gate-interface.md` says approval "must NEVER turn a block-tier 1 into 0".
- **Recommendation:** Add `send_expect "gmail +send mixed secret+figure with
  approval still blocked" 1 0 -- env MOCHI_EGRESS_APPROVED=1 ...` and the
  equivalent gate-level case (want rc=1 despite `--approved`). This is the
  conformance test for the contract's strongest negative guarantee and
  should live in suite B, not just in prose.

### F3 (P1) — Suite E's residual list diverges from the catalog's residual list
- **Priority:** P1
- **Title:** Residuals are restated from a hardcoded copy that disagrees with the source of truth
- **Evidence:** `references/attack-surface.md` "Residual risk summary" lists
  A8, B2 (public pushes), B4 (attachments — OPEN GAP), C3, C4. Suite E in
  `bin/leakage-audit` hardcodes four different bullets (browser sends,
  absolute-path, voice calls, brief-gate mandate) — B2 and B4 are silently
  dropped from the every-run report despite the "reported, never silent"
  principle. `test-matrix.md` section E mirrors the same four-item copy.
- **Recommendation:** Derive suite E from a single machine-readable
  residuals manifest (every POLICY-ONLY / OPEN scenario id) and fail the
  audit if the manifest and the printed list disagree. Minimum: add B2 and
  B4 to suite E's restated list.

### F4 (P1) — Missing known-unknowns: gate-input injection, report-transcript path, stateless-gate aggregation
- **Priority:** P1
- **Title:** Three plausible residual classes are neither cataloged nor disclaimed
- **Evidence:** (a) `references/attack-surface.md` C5 covers injection
  steering the agent but nothing covers content targeting the gate
  mechanism itself; (b) `bin/leakage-report` embeds raw transcripts and
  gate-log lines into HTML — `scrub()` at lines 203–208 has no test
  asserting it on hostile labels; (c) no catalog entry admits the gate is
  stateless per call, so multi-send aggregation is structurally
  unobserved. The brief explicitly named the first two as areas to assess.
- **Recommendation:** Add three catalog entries (verdicts: currently
  N/A-by-construction for (a), POLICY-ONLY for (b)/(c)), add a report test
  feeding a hostile context label through the scrub pipeline, and state the
  statelessness bound explicitly: "the gate judges each call independently;
  exfiltration split across calls is not observable by design."

### F5 (P1) — Gate-interface contract is underspecified for independent conformance testing
- **Priority:** P1
- **Title:** `references/gate-interface.md` cannot be implemented from blindly
- **Evidence:** Contract pins flags and exit codes but is silent on:
  (a) latency bounds — audit imposes 30s/10s timeouts externally, contract
  states no bound a gate must meet; (b) whether `memory-egress-check`
  accepts `--approved` (approval override is specified only under
  `egress-gate`); (c) failure modes for missing `--brief-file`, unreadable
  content file, or binary/non-UTF-8 input — a conforming implementation
  could return 0 on a missing brief file and open the gate; (d) stdin-vs-
  file verdict equivalence (adversarial-run's comment notes the shapes
  match, the contract doesn't require it); (e) the gate log line schema —
  suite D greps for `"| BLOCKED"` but the schema is defined nowhere in the
  contract.
- **Recommendation:** Extend the contract with: latency bound (e.g. "must
  answer within the caller's timeout; hanging is non-conformance"),
  exact `--approved` support per binary, an error taxonomy (missing
  required flag → exit 2, never 0), stdin/file equivalence requirement,
  and the log line schema. Then add a contract-conformance suite:
  (i) corpus cases with `--approved`: want=2→rc 0, want=1→rc 1
  (never downgraded); (ii) missing `--brief-file` → usage error, not rc 0;
  (iii) stdin and file input give identical verdicts per case;
  (iv) binary/garbage content fails closed (never silent rc 0).

### F6 (P1) — A4's encoding test is a base64 blob, not a MIME document
- **Priority:** P1
- **Title:** "Decoded before the check" is tested on a non-MIME payload
- **Evidence:** Suite B builds `RAW_MIME` as `base64.urlsafe_b64encode` of
  `card.txt` alone — decoded it is bare text "Card 4111-1111-1111-1111
  charged", with no headers, no multipart boundaries, no quoted-printable.
  The contract's "the MIME is base64-decoded and gated" is therefore
  validated on a shape that exercises none of MIME parsing's failure
  modes (multipart part 2, nested parts, encoded-word headers).
- **Recommendation:** Add red-team cases with realistic MIME shapes: a
  multipart body with the token in the second part, a token in an encoded
  filename header, and a quoted-printable body. Mark which the real shim
  normalizes; catalog the rest as known limits.

### F7 (P2) — Calibration language: "recall"/"36/36" measure self-consistency, and the repo sometimes says so only in fine print
- **Priority:** P2
- **Title:** Detection-metric language invites misreading as detector quality
- **Evidence:** `bin/adversarial-run` header says "this proves the
  detectors"; `bin/leakage-report` hero for real targets reads
  "Detection performance: {mm}/{tt} corpus cases matched expected
  verdicts" with per-tier "block-tier recall 19/19" (lines 226, 271–275);
  README Quickstart hardcodes `# expect CLEAN and 36/36`. Both payloads
  and expected labels were authored by the detector's authors and shaped
  to match the detector — the only honest reading is agreement-with-self,
  i.e. a regression-consistency check. The stub-target caveats are good;
  the real-target language is where peer review would object. n=19 for
  the block tier makes "19/19" brittle: one added case moves it to 95%.
- **Recommendation:** (a) Rename the report's metric to "corpus agreement
  (self-consistency)" with the canonical sentence: *"Across the synthetic
  corpus (36 cases, all authored by the harness maintainers and shaped to
  trip the detectors), the detector's verdicts agreed with the authors'
  expected labels in all 36 cases. This is a self-consistency check of the
  harness, not evidence of protection: only a run against the real
  installation speaks to protection, and only a detector-blind,
  independently authored corpus would speak to detector quality."*
  (b) Replace "proves the detectors" with "probes the detectors" in
  `adversarial-run`. (c) In README Quickstart, derive the count
  dynamically ("expect CLEAN and all corpus cases matched") instead of
  hardcoding 36/36, which rots when the corpus grows.

### F8 (P2) — Suite E hardcodes residuals as prose instead of testing the residual claims
- **Priority:** P2
- **Title:** "Reported every run" is satisfied by printing, not by verifying the residual is still true
- **Evidence:** Suite E prints four static bullets; it does not verify,
  e.g., that the brief-gate mandate still appears in the agent manual
  (suite C does this separately), or that voice calls remain out of scope.
  Printing a bullet does not detect when a residual silently becomes false
  (e.g. if the manual's mandate were deleted, suite C would catch it, but
  suite E would still print the same bullet).
- **Recommendation:** Make each residual bullet carry a check where one is
  cheap (mandate presence, no-new-hardcoded-paths) and label the rest
  explicitly as "unverifiable by audit — documented here only". This keeps
  "never silent" honest: silence is avoided by verification, not by
  repetition.

### F9 (P3) — The cron-PATH check (A7) verifies a literal string, not the running job
- **Priority:** P3
- **Title:** Static grep for `bin/shims:$PATH` cannot see runtime PATH composition
- **Evidence:** Suite C greps prompt files for the export string; a prompt
  that builds PATH at runtime, sources it from a shared profile, or has
  the literal in a comment passes identically. A7's "PROTECTED (by audit)"
  verdict is really "protected by static text match".
- **Recommendation:** Downgrade the claim's precision: note in the catalog
  that the check is syntactic, and add a runtime spot-check where feasible
  (e.g. a canary cron that reports its own resolved `command -v
  hatch_gws_cli`). Catalog the semantic gap as a known-unknown.

### F10 (P3) — Subject-line coverage is claimed but never exercised
- **Priority:** P3
- **Title:** A1's "scans subject + body" has no red-team case
- **Evidence:** All suite-B gmail cases place fixtures in `--body`; no
  case places a block-tier or review-tier fixture in `--subject`. The
  claim rests on implementation inspection, not on the audit.
- **Recommendation:** Add `send_expect "gmail +send secret in subject
  blocked" 1 0 -- ... --subject "$(cat $FIX/secret.txt)"` (and a figure
  review-tier case). Cheap, closes the prose-vs-test gap.

## C. Gate-interface conformance test to add (summary)

Beyond the F5 contract text additions, the audit should gain a
"contract-conformance" suite, runnable against any target (stub or real),
that asserts: (1) approval override converts want=2→rc 0 and never
want=1→anything-but-1 (F2); (2) missing required flags fail with usage
error, never rc 0; (3) stdin and file inputs produce identical verdicts;
(4) malformed/binary input fails closed; (5) the corpus's encoding cases
pass through the shim path, not only the gate binary (F6). This turns
`gate-interface.md` from documentation into a testable specification —
the actual point of iteration 4's stub.

## D. Calibration-honesty recommendation (canonical language)

Proposed standard wording for README, report blurbs, CI summaries, and
ITERATIONS.md validation lines, to replace bare "36/36" and "proves the
detectors":

> Detection figures in this repo are **corpus agreement**, not detector
> quality: the payloads and the expected verdicts were authored by the
> same team that wrote the detectors, and shaped to trip them. A green
> run means the harness and its test double are self-consistent. It does
> not mean the protection generalizes to unseen attacks (only a
> detector-blind, independently authored corpus could show that), and it
> does not mean any real installation is protected (only a run against
> the real installation shows that).

Do not print "36/36" as a bare number anywhere user-facing; always pair
it with the corpus scope (n per tier) in the same breath.
