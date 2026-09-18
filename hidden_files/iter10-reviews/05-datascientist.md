# Iteration-10 review — Data scientist (measurement)

**Target:** `~/workspace/skills/muse-leakage-guard`, HEAD `653bdd9`.
**Mode:** REVIEW-ONLY; read corpus, runner, report statistics, blockset
builder. No repo writes; synthetic data only.

**Lens:** are the measured quantities honest, complete, and partitioned
correctly? What is measured vs merely claimed?

**Baselines:** adversarial 36/36 both targets (block 19/19, review 9/9,
clean 8/8); stub audit 86/0/1; real audit 82/0/5.

## Verdict summary

**4 findings: 1 P1, 1 P2, 2 P3.** The P1 is measurement coverage: the
write-time classifier (`memory-guard`) has three operating points
(block/review/clean) and the harness measures exactly zero of them. The
P2 is corpus evasion depth. The honesty machinery (Clopper-Pearson lower
bounds labeled as bounds over author-designed fixtures, "pass rates not
recall", timeout-denominator partitioning) all still holds — re-verified,
no regression.

## Findings

### DS-1 (P1) — the write-time classifier is unmeasured

**What.** Every other classifier in the system has measured pass rates:
the egress gate (suite B red-team), the detector (adversarial corpus with
per-tier rates and 95% lower bounds). `memory-guard` — which makes the
identical three-way decision (block secret / flag figure-or-PII / pass
clean) on the write path — has no measurements at all. The catalog's D1
"PROTECTED" and D2 "APPROVAL-GATED" are therefore uncalibrated labels, not
measured properties. The six-probe set (secret→1, figure→2, phone→2,
clean→0, allowlisted figure→0, allowlisted secret→1) gives the write-time
classifier the same fixture-conformance treatment the send plane got in
iteration 9. Note the asymmetry it would expose if it ever regressed: a
write-time block-tier miss (secret → rc=0) is strictly worse than a
review-tier miss, and the probe set partitions exactly that way.

**Recommendation.** Implement the probe set in suite C. Do not add
Clopper-Pearson bounds for n=6 — the suite-C probes are conformance
checks, not a sampled evaluation; bounds over 6 fixtures would imply a
generality the set does not have. Keep them as pass/fail checks like the
rest of suite C.

### DS-2 (P2) — corpus evasion depth

**What.** The 36-case corpus measures the detector at the shapes the author
wrote, once each. Missing equivalence classes: case variants of key
prefixes, whitespace inside the token, `api_key`/`apikey`/`API_KEY`
separator variants, punctuation-adjacent tokens, multi-tier payloads
(secret and figure in one input — exercises the "worst wins" logic), and
near-miss negatives (e.g. `sk_live_` truncated below the length threshold,
which must stay clean). The stub double's fail-closed design (undeclared
secret-shaped → rc=2) means evasion cases need corpus + blockset + CI-pin
updates in lockstep; the machinery for that exists (`build-blockset.sh`,
the pin comment in the workflow). Deferred to post-loop backlog per PM-4 —
it is a detector-depth theme, separate from the write-time theme.

### DS-3 (P3) — probe fixtures already exist; no new synthetic values needed

**What.** Positive: the six-probe set reuses `bin/fixtures/{secret,secret2,
figure,phone,clean}.txt` — all declared in `SYNTHETIC.txt`, all already in
the fixture-purity SHAPES coverage. No new synthetic tokens, no blockset
rebuild strictly required for the probes themselves (the stub double reads
the existing blockset). The allowlist probe fixtures (`/tmp` allowlist
files) contain only synthetic fixture lines. Nothing new to declare.

### DS-4 (P3) — keep the corpus total pinned at 36

**What.** The write-time probe set does not touch `bin/adversarial-
corpus.txt`, so `@@@ ADV MATCHED 36/36` is unaffected. Only `@@@ TOTAL`
moves (83 → 91 in CI). Stating this explicitly because the two pins are
updated by different mechanisms and a confused edit could "fix" the wrong
one.
