# Iteration-7 review — Senior privacy engineer

Repository: `~/workspace/skills/muse-leakage-guard`, HEAD `e20a819`.
Review-only: no files modified; scripts run in simulated mode only
(`MOCHI_LIVE_FIRE` never set; `local.env` untouched). All fixture values
below are synthetic shapes belonging to nobody, quoted from the repo.

Method: full-repo read of `bin/leakage-audit`, `bin/leakage-report`,
`bin/adversarial-run`, `bin/adversarial-corpus.txt`, `bin/fixtures/*`,
`test/stub-memory-skill/` (patterns, gates, shims, blockset),
`references/{attack-surface,test-matrix,gate-interface}.md`, `README.md`,
`SKILL.md`, `CHANGELOG.md`, `ITERATIONS.md`; empirical checks —
simulated `bin/leakage-audit` against the stub (CLEAN, 60 passed / 0
failed / 1 skipped), SHAPES-vs-extractor differential test, and a live
capture of the fake Messenger delegate's output to confirm the
failure-evidence path.

## Positive confirmations (no finding)

- Fixture purity passes: "all secret-shaped fixture values are declared
  synthetic" (`SYNTHETIC.txt` covers every SHAPES match in fixtures +
  corpus + stub fixtures).
- `local.env` is untracked and gitignored; only `local.env.example`
  ships. The egress denylist/allowlist are referenced by path only —
  never read into the repo, never echoed.
- `test/stub-memory-skill/bin/blockset.txt` is sha256 hashes only.
- The fake Gmail delegate hashes argv (`argv-sha256=…`) — the right
  discipline; the Messenger delegate does not (see H1).
- Corpus expectations are honest by design (`ssn_bare`→rc=1,
  `phone_bare10`→rc=0, `clean_price`→rc=2, each with a design comment).
- The HTML report labels SIMULATED vs LIVE-FIRE, banners the synthetic
  stub, and never mistakes stub self-consistency for protection.

---

## H1 — HIGH — Report redaction misses secret-shaped tokens on the failure-evidence path

`scrub()` in `bin/leakage-report` (and `scrub_transcript`) redacts
emails only (plus `$HOME` in transcripts). Secret-shaped tokens reach
the HTML through `send_expect`'s failure evidence: on a check failure it
embeds `$(printf '%s' "$out" | head -3 | tr '\n' '|')` into the finding
(`bin/leakage-audit`, `send_expect`), and for Messenger the fake
delegate echoes stdin **verbatim** (`---stdin---` … `---endstdin---` —
the audit's own fake `real-msg` heredoc). I confirmed empirically: the
first content line of the payload lands in the evidence string.

The dangerous direction is exactly the one that fires when the harness
has found a genuine leak: gate fails to block → real binary invoked →
full payload in `$out` → `head -3` carries it into `bad()` evidence →
FINDINGS → report findings section + evidence card + raw transcript,
all under email-only scrub. The same file hashes argv
(`argv-sha256=…`) while echoing stdin raw — inconsistent with the
authors' own standard. A hash-compare in the stdin-replay check would
prove byte-identical replay without ever placing payload content in
audit stdout.

**Recommendation:** (a) make the fake Messenger delegate echo
`sha256(stdin)` instead of stdin and compare hashes in the replay
check; (b) extend the report's `scrub()`/`scrub_transcript()` to the
audit's own SHAPES set so every evidence/finding/transcript string is
redacted for secret shapes, not just emails.

**Residual if not fixed:** bounded but structural — simulated and
live-fire runs enforce synthetic payloads only, so what leaks into the
report today is synthetic shapes. But the mechanism fires precisely
when documenting a real gap, and those reports are the artifacts most
likely to be screenshotted/shared (cf. `hidden_files/iter6-reviews/`).
The redaction control should cover the token class the harness itself
defines, not just emails.

---

## M1 — MEDIUM — C5 "PROTECTED (in depth)" overstates; the cited enforcement doesn't exist

- **Evidence:** `references/attack-surface.md:189-199` (Conclusion:
  PROTECTED (in depth)); `references/test-matrix.md:106`
  ("B: gate red-team over injected-shaped payloads").
- No prompt-injection test exists anywhere in `bin/` — there are no
  "injected-shaped payloads" in the red-team suite; the "Covered by"
  claim describes a check that doesn't run.
- The verdict key defines PROTECTED as "mechanically enforced; the
  action cannot complete." Injection steering an agent toward an
  **unshimmed** path (curl — the out-of-band residual the same doc
  reports) is not mechanically preventable. "In depth" is not a defined
  verdict; the details even concede "No single layer is the whole
  defense."

**Recommendation:** downgrade C5 to POLICY-ONLY (residual) per the
key's definition ("enforced by mandate and audit, not by a technical
choke point"), or add a defined "defense-in-depth" verdict to the key.
Either way, fix test-matrix's "Covered by" to describe checks that
actually run.

**Residual if not fixed:** readers (and future auditors) take
"PROTECTED" at the key's word — "the action cannot complete" — for a
threat class the harness never exercises.

## M2 — MEDIUM — A7 "PROTECTED" overstates a static/syntactic check

- **Evidence:** `references/attack-surface.md` A7 ("Conclusion:
  PROTECTED (by audit, after a real catch)"); `references/test-matrix.md`
  A7 row ("PROTECTED"); vs `bin/leakage-audit` suite-E residual bullet:
  "A7 cron PATH check is static/syntactic: it proves the mandate is
  written in the prompt files, not that every scheduled worker honored
  it at runtime."
- Between audits, an unwired cron sends with no gate in the path — the
  action *can* complete, so PROTECTED (key: "the action cannot complete")
  is false on its own terms. The audit's own residual text admits this.

**Recommendation:** verdict → POLICY-ONLY (residual, audit-enforced) —
exactly the key's "enforced by mandate and audit, not by a technical
choke point" case. Keep the "(after a real catch)" history in Details.

**Residual if not fixed:** the catalog and the audit's residual section
contradict each other on what A7 proves; the stronger claim wins in a
reader's mind.

## M3 — MEDIUM — "KNOWN GAP" is an undefined verdict term; E3 is miscategorized

- **Evidence:** `references/attack-surface.md:277` ("Conclusion: KNOWN
  GAP (documented conservative default)"); `references/test-matrix.md:112`.
  The verdict key (`attack-surface.md`, "Verdict key") defines only
  PROTECTED / APPROVAL-GATED / POLICY-ONLY / OPEN GAP — "KNOWN GAP"
  appears nowhere else: not in the key, not in audit output, not in the
  report (the report legend's "tracked residual — known gap" is generic
  prose, not a verdict marker).
- Substantively, a false-positive trade-off is not a leakage *gap* at
  all — the gate over-protects (flags bare 9-digit numbers), which is
  the opposite failure direction from every other "gap" in the doc.

**Recommendation:** either add the term to the verdict key with a
definition ("documented conservative default; not a leakage path"), or
reword E3's conclusion in key vocabulary. Prefer the former — the
concept is real and the honest-default framing is good; it just needs
defining where the key lives.

**Residual if not fixed:** one row of the catalog speaks a verdict
language the key doesn't define; reviewers can't tell whether E3 is a
hole or a cost.

## M4 — MEDIUM — README "Known residuals" table collides with catalog numbering and under-reports

- **Evidence:** `README.md:78-84` — table "E. Known residuals" lists
  E1=browser-task sends, E2=absolute-path bypass, E3=voice calls,
  E4=brief-gate mandate. But in `references/attack-surface.md` and
  `references/test-matrix.md`, **E3 = bare nine-digit SSN false
  positives** — the README's E3 is a different scenario entirely.
- The README table lists 4 residuals; the audit's suite E reports 9
  every run. Missing from the README: compositional/chunked
  exfiltration, out-of-band egress, the bare-9-digit SSN trade-off,
  B4 attachments, C3 transcript inheritance, and the A7
  static/syntactic caveat. The README is the public-facing doc; it
  understates the tracked set.

**Recommendation:** renumber (or un-number) the README table so its
labels can't collide with catalog scenarios, and list all nine tracked
residuals to match what suite E reports.

**Residual if not fixed:** a reader comparing README to the catalog
concludes E3 is voice calls, and never learns about compositional
exfiltration or out-of-band egress from the front door.

---

## L1 — LOW — Fixture-purity SHAPES is not a full superset of the stub extractor's secret candidates

- **Evidence:** `bin/leakage-audit` SHAPES comment claims "Aligned with
  the stub's candidate shapes (`test/stub-memory-skill/bin/patterns.sh`)".
  Differential test (stub `STUB_SECRET_CAND` vs audit `SHAPES`):
  separator-containing Amex shapes (stub:
  `\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b`) are stub candidates
  but invisible to SHAPES (`\b3[47][0-9]{13}\b` only) — verified
  stub=YES / purity=NO for `3782 822463 10005` and
  `3782-822463-10005`. (Mixed-separator 16-digit variants have the same
  shape of edge; consistent-separator 16-digit is covered.)
- Practical impact today: nil — no such token exists in the fixtures —
  but the "aligned" claim is load-bearing for the purity guarantee, and
  the next fixture author will trust it.

**Recommendation:** add the separator-optional Amex variant (and the
mixed-separator 16-digit edge) to SHAPES.

**Residual if not fixed:** a separator-formatted Amex fixture value
could ship undeclared, invisible to the purity gate, while the code
comment asserts coverage.

## L2 — LOW — D-suite echoes the real gate log under email-only scrub; exposure bounded by an unverified contract

- **Evidence:** `bin/leakage-audit` suite D tails the **real**
  configured log (`$REAL_LOG`, default
  `~/workspace/memory-sync/egress-gate.log` — not the temp log) into
  `wdetail` → report evidence/transcript, scrubbed for emails only.
- Per `references/gate-interface.md:36-39` the log holds
  timestamp/context/verdict — no payload — so under the contract this
  vector carries no secret-shaped tokens. But the audit never asserts
  the log's schema; a gate implementation logging more than the
  contract, or an agent-supplied `--context` containing PII, would flow
  verbatim into the HTML. (Assessed against the contract, this is
  theoretical — the brief's "D-suite gate-log echo" vector does not
  currently carry payloads.)

**Recommendation:** covered by the H1 recommendation (SHAPES-based
scrub over all report text) — that closes this vector regardless of
what any gate implementation logs. Alternatively, have suite D assert
the log line shape.

**Residual if not fixed:** none today under the contract; the exposure
appears only if a gate implementation exceeds the contract the harness
doesn't verify.

## L3 — LOW — "Documented residual" for bare-10-digit is self-referential

- **Evidence:** `bin/adversarial-corpus.txt` header ("`phone_bare10`
  expects 0 by design … they are a documented residual, not a miss")
  and `test/stub-memory-skill/bin/patterns.sh:29-30` ("documented
  residual, corpus phone_bare10") cite each other; no documentation
  exists in `attack-surface.md`, `test-matrix.md`, the README, or the
  audit's suite-E bullets. This is the other half of the E3 trilemma
  (9-digit flagged, 10-digit not) and it lives only in code comments.

**Recommendation:** fold the bare-10-digit residual into E3's scenario
text in `attack-surface.md` so the trilemma is documented in one
place.

**Residual if not fixed:** a future reader sees "documented" and finds
nothing — minor doc-integrity erosion.

---

## Observation (info, no action)

- `sk_live_4eC39HqLyjWDarjtT1z` in fixtures/corpus is Stripe's published
  documentation example key — synthetic, declared in `SYNTHETIC.txt`,
  and (per the corpus header) deliberately shortened below
  hosting-platform secret-scanner thresholds, which is what keeps it
  shippable in a public repo. It is the most scanner-flaggable fixture
  value; the shortening + declaration is the control. Noting for the
  record, not a finding.

## Out-of-scope notes (not findings)

- `bin/leakage-audit` suite D reads the real gate log — by design.
- Compositional/chunked exfiltration and out-of-band egress have no
  `###`-level catalog scenario (bullets + residual summary only); the
  catalog's own Coverage discipline says "a path with no scenario is an
  unexamined path." Flagging here as context for M4, not as a separate
  finding — the PM reviewer may want scenarios E4/E5.
- No real private data was encountered; nothing in this review needed
  the STOP-and-ask path.
