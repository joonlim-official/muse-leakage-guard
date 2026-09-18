# Iteration-5 review — Senior privacy engineer

Repository: `~/workspace/skills/muse-leakage-guard`, HEAD `e4b2af1` ("Iteration 4:
CI readiness + synthetic stub skill"). Read-only review; no files modified.

Verification performed (empirical, not from docs alone):
- `bin/adversarial-run` vs stub: **36/36 matched** (block 19/19, review 9/9,
  clean 8/8) — matches ITERATIONS.md.
- `bin/leakage-audit` vs stub (simulated): **57/0/2 CLEAN** — matches the
  pinned skip set (memory-audit, gate-log).
- `build/build-blockset.sh --check`: current (21 tokens).
- Generated report `hidden_files/reports/leakage-validation-20260917-204438-9012.html`:
  no secret-shaped tokens, no emails, no `/home/*` paths in raw transcripts.
- Diffed the audit's fixture-purity SHAPES against the stub's
  `STUB_SECRET_CAND`: 8 secret-shaped tokens in the tree are invisible to the
  purity check (evidence below).

## Findings

### P1 — Fixture-purity SHAPES is a strict subset of the stub's secret-candidate shapes
- **Evidence:** `bin/leakage-audit:573` (SHAPES) and `:579` (the scan glob)
  vs `test/stub-memory-skill/bin/patterns.sh:21` (STUB_SECRET_CAND).
  Empirically: 8 tokens in `bin/fixtures/*.txt`, `bin/adversarial-corpus.txt`,
  and `test/stub-memory-skill/bin/fixtures/*.txt` match STUB_SECRET_CAND but
  are never extracted by the audit's SHAPES: the bare 9-digit SSN (`123456789`,
  corpus `ssn_bare`), the bare 16-digit card (`4111111111111111`, corpus
  `card_bare`), the 15-digit Amex (`378282246310005`, corpus `amex_15`), and
  the `api_key=`/`password:`/`passwd=` tokens in the secret/secret2 fixtures
  and corpus. Conversely, `5550001234` is declared in
  `bin/fixtures/SYNTHETIC.txt` but extractable by neither pattern set —
  an inert declaration that creates false confidence.
- **Recommendation:** Extend the audit's SHAPES with the missing alternations
  (`\b[0-9]{9}\b`, bare 16-digit card, 15-digit Amex, `api[ _-]?key…`,
  `password…`, `passwd…`) so the purity gate and the stub's extractor agree on
  what "secret-shaped" means; declare the newly extracted synthetic tokens in
  `bin/fixtures/SYNTHETIC.txt`; remove or annotate the inert `5550001234`
  line. This keeps the gate fail-closed: after the change, any new bare-digit
  or password-shaped token must be declared or the audit fails.
- **Residual if not fixed:** A real-shaped password, API key, bare SSN, or
  bare card number added to any fixture or corpus case passes the purity check
  undeclared and ships in the public repo. This is the highest-value bypass in
  the fixture-purity machinery.

### P1 — Bare 9-digit SSN over-blocking has no KNOWN-GAP marker
- **Evidence:** `test/stub-memory-skill/bin/patterns.sh:21`
  (`\b[0-9]{9}\b`); corpus `bin/adversarial-corpus.txt` bakes `ssn_bare → 1`;
  `references/attack-surface.md` section E (Classification) has only E1/E2 —
  the precision cost of the bare-9-digit shape (collides with order IDs,
  reference numbers, zip+4 concatenations) is documented nowhere, unlike the
  two other deliberate corpus exceptions (`phone_bare10 → 0`,
  `clean_price → 2`, both documented in the corpus header and E1).
- **Recommendation:** Add an **E3 KNOWN-GAP marker** in attack-surface.md
  documenting the precision trade-off (block-tier is the conservative choice;
  false positives are the known cost). Do **not** tighten the pattern in this
  repo: the corpus bakes `ssn_bare → 1` and the real gate classifies SSN as
  block-tier, so the honest move is the explicit marker, not a silent
  relaxation. (Broad JWT matching: no JWT pattern exists anywhere in this
  repo — verified by grep — so that precision question belongs to the real
  memory skill's gate and is out of scope here; if a JWT case is ever mirrored
  into the stub corpus, it should land with its own KNOWN-GAP entry.)
- **Residual if not fixed:** Readers see `ssn_bare → block` presented as
  unqualified correct behavior and may copy the bare-9-digit shape into other
  contexts unaware of its false-positive rate — the exact approval-fatigue
  risk E1 warns about.

### P2 — Purity scan excludes docs and comments entirely
- **Evidence:** `bin/leakage-audit:579` — the scan glob covers only
  `bin/fixtures/*.txt`, `bin/adversarial-corpus.txt`, and the stub fixtures.
  SKILL.md, README.md, and `references/*.md` already quote only declared
  tokens today, but nothing mechanical enforces that going forward. The
  B2/B3 denylist scan only catches the user's *own declared* literals, not an
  arbitrary real-looking token pasted as a docs example.
- **Recommendation:** Either extend the purity glob to the markdown trees
  (all currently-quoted tokens are already declared in SYNTHETIC.txt, so the
  check would stay green) or add an explicit "docs are out of scope, review
  by hand" note to the check header and CONTRIBUTING.md's synthetic-data
  section.
- **Residual if not fixed:** A realistic token pasted as a new docs example
  ships in the public repo with no automated check to catch it.

### P2 — Report transcript redaction covers only emails and home paths
- **Evidence:** `bin/leakage-report:202-210` (`scrub`/`scrub_transcript`
  redact EMAIL_RE and `$HOME` only). `bin/leakage-audit:595-601` (suite D)
  echoes the last 5 raw `approved-override`/`BLOCKED` gate-log lines into the
  transcript; `send_expect` failure evidence includes head-3 of send output
  (`bin/leakage-audit` `send_expect`). Against a stub target everything is
  synthetic, and CI artifacts are stub-only, so today's exposure is local —
  but the HTML report is explicitly designed to be shared ("mobile-friendly
  outcome report"), and CI retains the artifact 14 days.
- **Recommendation:** Add a secret-shaped-token redaction pass (the SHAPES
  set, ideally the full STUB_SECRET_CAND shapes) to `scrub_transcript`, so a
  real token that ever lands in a gate-log line, a MISMATCH detail, or a
  live-fire failure's send output cannot ride into the shareable HTML.
- **Residual if not fixed:** A locally generated report that includes a real
  gate-log line (D suite) or a failing live-fire detail, if shared externally,
  carries the real token verbatim.

### P2 — `AIza` pattern has no minimum length
- **Evidence:** `test/stub-memory-skill/bin/patterns.sh:21`:
  `AIza[A-Za-z0-9_-]+` matches `AIza` plus a single character. The corpus
  deliberately uses shortened keys *below hosting-platform scanner
  thresholds* (`bin/adversarial-corpus.txt` header), but the stub pattern is
  thresholded far shorter than even that intent.
- **Recommendation:** Tighten to a floor that keeps the corpus green but
  rejects trivial matches — e.g. `AIza[A-Za-z0-9_-]{10,}` (the corpus key is
  39 chars; real keys are 39). Tighten rather than KNOWN-GAP-mark: this is the
  stub's own approximation, not inherited real-gate policy.
- **Residual if not fixed:** Minimal — "AIzaX" classifies as a secret
  candidate (review-tier fail-closed), slightly inflating review-tier noise.

### P2 — Stub README disclaimer doesn't warn against copying the lookup architecture
- **Evidence:** `test/stub-memory-skill/README.md` "What this stub is NOT"
  section, `bin/memory-egress-check` header, and `references/gate-interface.md`
  all state the stub "is not a detector" and "must never be deployed as a
  protection layer" — the *deployment* warning is adequate. The gap is
  subtler: the stub's runtime rule is "undeclared secret-shaped → review-tier
  (rc=2, fail closed)", which inverts real-detector semantics for
  password/`api_key=` shapes (real gates block on shape). A reader could take
  the declared-set lookup as the reference *classification architecture*.
- **Recommendation:** One added sentence in the README's "What this stub is
  NOT" section: real detectors classify by shape (block-tier on match); the
  declared-set lookup exists only because the stub's universe is synthetic,
  and must not be copied into a real gate.
- **Residual if not fixed:** Someone reimplements "lookup in a declared set"
  as a real protection layer, inheriting fail-open-by-omission semantics for
  every token not in the set.

## Non-findings (checked, deliberately not raised)

- **Corpus tiering is disciplined.** Every `want=1` case is a
  secret/credential/SSN/card shape; every `want=2` is a figure/phone; every
  `want=0` is genuinely clean. The two deliberate exceptions (`clean_price →
  2` per the E1 conservative default; `phone_bare10 → 0` as documented
  residual) are documented in the corpus header comment *and* in
  attack-surface.md E1. No synthetic shape is mis-tiered, and the corpus
  teaches the right classification lesson (shape → tier, conservative
  default for unruled figures).
- **The "not a detector" disclaimer is sufficient as a deployment warning.**
  It appears in the stub README (dedicated section), every stub file header,
  `gate-interface.md` ("What the audit does NOT promise"), the report banner/
  title/footer, and the E2 attack-surface entry. Only the
  lookup-architecture-copy risk above (P2) remains.
- **Stub-target labeling holds up.** `target-kind: SYNTHETIC STUB` print,
  `STUBKIND` sentinel, live-fire refusal (exit 2, verified in code at
  `bin/leakage-audit`), report banner + "(synthetic stub)" page title, CI
  summary disclaimer, and the pinned skip set (exactly 2) all check out.
  CI runs `pull_request` only, `contents: read`, SHA-pinned actions, shallow
  checkout, refuses live-fire variables and a committed `local.env`.
- **`local.env` is gitignored and untracked** (verified via `git ls-files`);
  CI additionally refuses it if present. The committed `local.env.example`
  contains no real values.
- **blockset.txt is hashes-only and current** (`--check` green, 21 tokens);
  tokens are recoverable from the public corpus anyway, so hash-reversibility
  is not a leak vector.
