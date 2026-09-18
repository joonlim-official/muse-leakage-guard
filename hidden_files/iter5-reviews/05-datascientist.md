# Iteration-5 review — Senior data scientist

Repo: `~/workspace/skills/muse-leakage-guard`, HEAD `e4b2af1`.
Read-only review. Sources examined: `bin/adversarial-corpus.txt` (36 cases,
verified counts: want=1 × 19, want=2 × 9, want=0 × 8), `bin/adversarial-run`,
`bin/leakage-report`, `test/stub-memory-skill/{bin/memory-egress-check,bin/patterns.sh,build/build-blockset.sh}`,
`references/{attack-surface,test-matrix,gate-interface}.md`, `SKILL.md`, `README.md`.

Privacy note (per brief): this review used only facts in the task brief plus
the repo itself. All corpus/fixture values examined are declared synthetic.
No personal data was needed or used.

---

## Findings

### P0 — "19/19 recall" is a measurement claim the data cannot support

**Evidence.** `bin/adversarial-run` prints `block-tier recall 19/19 · review-tier
recall 9/9 · clean precision 8/8`. The 36 cases are a fixed, author-designed
fixture set, not a sample from any distribution of real exfiltration attempts —
every case maps to a pattern class the author already knew the gate handles
(see corpus: vendor key prefixes, two PEM headers, two SSN shapes, four card
shapes, four figure shapes, four phone shapes, eight hand-picked clean traps).
"Recall" and "precision" are estimators of population performance; a fixture
set has no population, so the terms license no generalization. Concretely, the
95% exact (Clopper–Pearson) interval for 19/19 is **[0.82, 1.00]**; for 9/9 it
is **[0.66, 1.00]**; for 8/8 it is **[0.63, 1.00]**. The honest reading of
today's headline number is "all 19 fixtures passed; the data are consistent
with fixture-class recall as low as ~82%."

**Recommendation.** Rename the runner/report metrics to fixture pass rates
(e.g. `block fixtures 19/19`), print the exact 95% CI next to each, and add a
fixed caveat line to the runner footer and the report's detection card:
"Fixture set (n=36), author-designed — licenses no claim about real-world
detection." Keep the stub-run qualifier already present (leakage-report:374).

### P0 — Per-tier pass rates hide the most dangerous confusion direction

**Evidence.** `adversarial-run` aggregates into `p1/f1`, `p2/f2`, `p0/f0` and
reports only marginal pass rates. A block-tier payload that lands in
review-tier (rc=2) and one that lands in clean (rc=0) are both "1 miss" in the
current figures, but the security meaning is completely different: rc=2 still
refuses without approval (fail-closed-ish), rc=0 is silent exfiltration. The
existing headline cannot distinguish them.

**Recommendation.** Emit a 3×3 confusion matrix (expected rc ∈ {1,2,0} × got
rc ∈ {1,2,0}) in both the runner's text output and the report's detection
card. Off-diagonal cells are the real signal; a `1→0` cell should be
impossible to miss in the report.

### P1 — The stub's 19/19 in CI is tautological: build and runtime share the extractor

**Evidence.** `build/build-blockset.sh` and the stub's
`bin/memory-egress-check` both `source bin/patterns.sh` — the same
`$STUB_SECRET_CAND` pattern extracts candidates at build time (to hash into
`blockset.txt`) and at runtime (to look up). Any systematic extraction bug
affects both sides identically and is therefore invisible to the suite.
Iteration 4's own bug (greedy shape patterns fusing adjacent tokens across
concatenated cases) is exactly this class of failure: had the fused tokens
been hashed consistently on both sides, the suite would have stayed green
while testing nonsense tokens.

**Recommendation.** Add independent ground-truth assertions in `test/`: a
small hand-written list of (corpus-case → expected extracted token string)
that is checked against `blockset.txt` contents (un-hashed, human-verified),
independent of `patterns.sh`. This breaks the build↔runtime agreement loop
with a third, human source of truth. CI should run it alongside
`build-blockset.sh --check`.

### P1 — Fail-closed-to-review is the stub's most important behavior and is completely untested

**Evidence.** The stub's documented contract (`bin/memory-egress-check`
header): any secret-shaped candidate NOT in `blockset.txt` → rc=2. No corpus
case or audit check exercises this path — by construction `adversarial-run`
cannot, since every corpus case must match its `want` exactly. The brief's
masking concern is therefore real but mislocated: a *new block-tier shape*
added to the corpus with `want=1` that fails to make it into the blockset
(wrong token extracted, build silently extracting zero tokens for the case)
currently surfaces only as a suite mismatch at runtime — and `build --check`
passes in the meantime because it compares hash sets, not per-case token
coverage.

**Recommendation.** (a) Add a dedicated fail-closed canary *outside*
`adversarial-run`: feed the stub an undeclared synthetic secret-shaped token
(e.g. `sk_test_` + random suffix never in the corpus), assert rc=2. This
documents fail-closed as tested behavior rather than assumed behavior.
(b) Make `build-blockset.sh --check` assert ≥1 extracted token per
`want=1` corpus case, so a case that contributes zero tokens fails the build,
not just the suite. (c) Add a stub-vs-real differential check: run the
corpus against both the real gate and the stub, and report the verdict
disagreement count. Every `real=1, stub=2` disagreement is a documented,
expected under-detection by the test double — it bounds what stub CI can
claim and makes the fail-closed masking visible instead of silent.

### P1 — Fixture-adversarial coupling: the corpus validates what the author already knew to test

**Evidence.** The corpus is a regression suite, not an adversarial sample:
each case was written against a known pattern class, and the two
"by design" exceptions (`phone_bare10`→0, `clean_price`→2) are documented in
the corpus header — i.e., the corpus encodes the gate's *current doctrine*,
so it can never surprise it. Unknown-unknown evasion (encoding, homoglyphs,
line-splitting — see coverage analysis) is structurally out of reach of this
method.

**Recommendation.** Document the corpus explicitly as "regression fixtures,
not a sample" (see P0 caveat), maintain a KNOWN-GAP registry (dimensions in
the coverage analysis below, each with desired verdict and current status),
and consider a cheap differential fuzzer as future work: mutate existing
fixtures (case, whitespace, adjacency, encoding) and assert the real gate's
verdict never *downgrades* (1→2 or →0) relative to the parent fixture. That
is a monotone property that needs no oracle and catches real regressions.

### P2 — Near-miss (negative trap) coverage is ad hoc

**Evidence.** Clean traps exist for some classes (`$1`/`${10}` shell vars vs
figure patterns; bare-10-digit vs phone; `v1.2.3` vs digit runs; `5550001234`
order number; `90210` zip) but there is no systematic near-miss per block
class: no too-short key (`sk-abc`), no `password` with no value, no malformed
SSN (`12-345-6789`), no 20-digit run vs card patterns, no 7-digit phone, no
prefix-adjacent word (`skipping`). Over-gating regressions (E1 in
attack-surface.md) are caught only where someone happened to write a trap.

**Recommendation.** Adopt the rule "every block-tier shape class gets ≥1
negative trap" and track the near-miss trap ratio (see metrics below).

### P2 — Report already qualifies stub runs; the runner's own header does not

**Evidence.** `leakage-report:374` and the F-blurb (line ~272) both state that
stub figures measure harness self-consistency, not detector quality — good.
But `bin/adversarial-run`'s own header comment and its terminal output
(`adversarial-run: 36/36 cases matched… block-tier recall 19/19…`) carry no
such qualifier; the raw runner output is the artifact most likely to be
pasted into chat or a commit message without the report's framing.

**Recommendation.** Print the one-line caveat in the runner's summary output
itself (e.g. `note: fixture set, not a sample — see <report> for framing`),
so the number never travels without its interpretation.

---

## Corpus coverage-gap analysis

Dimensions verified absent from `bin/adversarial-corpus.txt` (no case name
matches, and inspection of all 36 payloads confirms): case variation of
labels, JSON/quoted structure, whitespace games, multiline payloads,
truncation/adjacency boundaries, any encoding (base64/URL/hex), Unicode
confusables, secret-splitting across lines, combined payloads (block-wins
logic), dotted card separators, IBAN/account-number shapes, personal email
addresses, dates of birth, multi-secret payloads.

**Disposition rule for the proposals below:** corpus cases must stay green
against the real gate, so each candidate should first be *probed* against the
real `memory-egress-check`. If it matches the desired verdict, add it as a
passing case; if it does not, register it in the KNOWN-GAP registry with the
desired verdict and current status — do not add failing cases to the corpus.

### Priority 1 — likely passes today, closes real evasion classes (add first)

| Case (synthetic-only) | Desired | Rationale |
|---|---|---|
| `Password: hunter2hunter2` (mixed-case label) | 1 | Real exfiltration text is not lowercase-normalized by attackers; tests pattern case handling |
| `passwd :\thunter2hunter2` (label/space/colon/tab) | 1 | Whitespace games are the cheapest evasion; adjacent to existing `api_key_eq`/`api_key_space` |
| `{"api_key": "abcdefghij1234567890abcdef"}` (JSON-quoted) | 1 | Config dumps are the most realistic secret context; tests quote/colon adjacency |
| `(ghp_abcdefghij1234567890abcdefgh)` (paren-wrapped token) | 1 | Token-boundary handling; adjacent to existing bare-prefix cases |
| `sk-abcdefghij1234567890ABCD` adjacent to trailing `!` / `",` | 1 | Punctuation adjacency — same class as paren wrap, cheap to add |
| `Budget $12,500; pay with sk_live_4eC39HqLyjWDarjtT1z` (secret + figure) | 1 | Tests worst-tier-wins (block over review) — currently untested composition |
| Two distinct secrets in one payload | 1 | Multi-hit path; stub counts `secret_hits` but no corpus case exercises >1 |
| Full PEM block with newlines (header + base64 lines + footer) | 1 | Multiline payload — existing `pem_key`/`pem_ec` are single-line fragments |

### Priority 2 — review-tier class gaps (probe against real gate; new classes likely KNOWN-GAP)

| Case (synthetic-only) | Desired | Rationale |
|---|---|---|
| `Contact: jdoe@example.com` (personal email in body) | 2 | C2 doctrine covers "personal contact info"; no corpus case tests email shapes |
| `DOB: 1986-10-03` | 2 | Same class as above; currently untested |
| `IBAN DE89 3704 0044 0532 0130 00` | 2 | Account-number shapes are a whole untested detector class; likely KNOWN-GAP today |
| `+14155550132` (bare digits with country code, no separators) | 2 | Between `phone_plus1` (separators) and `phone_bare10` (documented residual 0); resolves an ambiguity the corpus currently straddles |

### Priority 3 — negative traps (clean, want=0; cheap, prevent over-gating regressions)

| Case (synthetic-only) | Desired | Rationale |
|---|---|---|
| `reset your password regularly` (label, no value) | 0 | Near-miss for `password:` class |
| `key sk-abc is too short` | 0 | Near-miss for `sk-` class (length floor) |
| `ticket 12-345-6789` (malformed SSN grouping) | 0 | Near-miss for SSN class; tests strictness of 3-2-4 |
| `ref 12345678901234567890` (20-digit run) | 0 | Near-miss for card class; tests word-boundary handling |
| `Call 555-0100` (7-digit) | 0 | Near-miss for phone class |
| `skipping the live demo` (prefix-adjacent word) | 0 | Near-miss for `sk_` prefix; guards against over-broad prefix regex |

### KNOWN-GAP registry (desired 1, expected to miss today — document, do not add as failing cases)

1. **Homoglyph / confusable digits:** full-width `１２３-４５-６７８９`, Cyrillic `а` in `password`. Desired 1.
2. **URL-encoded label:** `api_key%3Dabcdefghij1234567890abcdef`. Desired 1.
3. **Base64 blob of a secret** (not inside MIME — bare blob in text). Desired 1. Note suite B already covers card-inside-base64-MIME on the shim path; the corpus has no encoding case at all.
4. **Line-split token:** `sk_live_` + newline + remainder. Desired 1.
5. **Dotted card separator:** `4111.1111.1111.1111` (pattern allows `[- ]` only). Desired 1.
6. **Truncated-at-boundary input:** very long input where a gate-side length cap could cut a token mid-shape (robustness, not a single case — a probe dimension).

---

## Corpus-quality metrics recommendation

Small set, reported by the runner/report footer. None of these pretend to
measure real-world detection — they measure the *instrument*:

1. **Tier × detector-class matrix** (counts): rows = key-prefix families,
   PEM, SSN, card, figure, phone; columns = block/review/clean cases.
   Surfaces at a glance that e.g. "PEM has 2 block cases, 0 traps."
2. **Near-miss trap ratio:** clean near-miss traps per block-tier shape
   class; target ≥ 1 per class. (Directly operationalizes the P2 finding.)
3. **KNOWN-GAP registry:** count + one-line list, printed every run
   (same discipline as the existing section-E residuals). A gap that is
   printed cannot quietly become assumed-safe.
4. **Exact 95% CI on each tier pass rate** (informational), with the fixed
   "fixture set, not a sample" caveat — replaces the bare `19/19` headline.
5. **3×3 confusion matrix** (expected × got) in runner output and the
   report's detection card (P0 finding). The off-diagonal cells are the
   metric that matters.
6. **Stub↔real differential disagreement count** (new, from the P1
   recommendation): corpus run against both targets; report
   `real=1/stub=2`, `real=2/stub=0`, etc. disagreements. Bounds what stub
   CI can claim and makes fail-closed under-detection visible.
7. **Corpus version stamp** in reports (hash of corpus + blockset
   freshness already CI-checked via `--check`): makes "which corpus
   produced this 19/19" answerable after the fact.

---

## Method note

Counts verified by parsing the corpus (`want=1 × 19, want=2 × 9, want=0 × 8`);
Clopper–Pearson bounds computed as the Beta-quantile lower bound for x/x
successes (e.g. 19/19 → 0.025^(1/19) ≈ 0.82). No corpus payloads were
executed against any gate in this review (read-only); "desired verdicts"
above are inferred from the documented gate doctrine in
`references/attack-surface.md` and `references/test-matrix.md`, and each
carries the probe-first disposition rule.
