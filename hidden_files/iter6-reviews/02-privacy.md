# Iteration-6 review — Senior privacy engineer

Repository: `~/workspace/skills/muse-leakage-guard`, HEAD `5ff8950`
("Iteration 5: honest green"). Full-repo, unlimited-scope, READ-ONLY
review; no repo files modified. Followed the task brief's privacy
paragraph: no personal details used; all payload values below are the
repo's own synthetic fixtures.

Verification performed (empirical, against the synthetic stub):
- `bin/adversarial-run`: **36/36 matched** (block 19/19, review 9/9, clean 8/8).
- `bin/leakage-report --out /tmp/iter6-report.html`: green-path HTML
  contains **no** secret-shaped tokens, no emails, no `/home/*` paths
  (grep over the corpus SHAPES set, EMAIL_RE, `/home/[a-z]+` — all empty).
- Failure-path test (repo copied to /tmp, stub gate tampered to force
  rc=0 in the COPY only; the real repo untouched): forced
  `send_expect` failures, generated the report, and confirmed fixture
  content reaches the HTML (Finding P1a).
- D-suite test (same /tmp copy): gate-log lines carrying a synthetic
  secret-shaped token and a figure, fed via `MOCHI_EGRESS_LOG`, reach
  the generated HTML verbatim (Finding P1b).

## Findings

### P1 — Report redaction covers only emails and home paths; secret-shaped tokens reach the shareable HTML on two demonstrated paths

- **Evidence:** `bin/leakage-report:206-224`. `scrub()` (line 207) is
  `EMAIL_RE.sub("[redacted]", s)` — email shapes only.
  `scrub_transcript()` (line 219) adds only the `$HOME` → `~` rewrite.
  No secret/key/SSN/card/figure/phone redaction exists anywhere in the
  report pipeline. (Note: the iter6 brief's premise that "`scrub()`
  scrubs secret-shaped tokens from captured transcripts" is inaccurate —
  it does not; that premise is itself part of the problem.)
- **Path A — `send_expect` failure evidence embeds fixture content.**
  `bin/leakage-audit:376`: on a check failure, the evidence string is
  `want rc=... got rc=... :: $(printf '%s' "$out" | head -3 | tr '\n' '|')`
  — the first 3 lines of the delegate's stdout. The fake Messenger
  delegate (`bin/leakage-audit:313-322`) echoes stdin between
  `---stdin---` / `---endstdin---` markers, so a failing Messenger check
  embeds the fixture's first content line in evidence. Demonstrated in
  the /tmp copy: the failing `messenger send secret blocked` evidence
  reads `... :: REAL-MSG-INVOKED argv-sha256=<hash>|---stdin---|Also
  tried: -----BEGIN FAKE PRIVATE KEY-----|`, and that line lands in the
  report's Findings section, evidence cards, and raw transcript —
  verbatim, unredacted. This directly contradicts the code comment at
  `bin/leakage-audit:313`: "Arg values are hashed, never echoed —
  failure evidence must not carry fixture content." The Gmail fake
  delegate honors that intent (hash-only); the Messenger delegate
  violates it. The Gmail-side hash design is good; the Messenger side
  is the hole.
- **Path B — D-suite echoes raw gate-log lines verbatim.**
  `bin/leakage-audit` suite D greps the configured gate log for
  `| BLOCKED$` / `| approved-override$` and prints `tail -5` of matching
  lines with `wdetail` (no content filtering); the report renders them
  via `scrub()` (email-only). Demonstrated: a synthetic blocked line
  containing `sk_live_4eC39HqLyjWDarjtT1z` and an approved-override line
  containing `$12,500` both appear verbatim in the generated HTML.
  Against the real installation today the exposure is latent, not
  active — the real gate log format on this machine is
  `timestamp | <context label> | <verdict>` with no payload snippets
  (verified read-only, values masked) — but the report's safety rests
  on an external log-format invariant it does not check.
- **Why it matters:** the HTML report is explicitly designed to be
  shared ("mobile-friendly outcome report"), and CI retains the artifact
  14 days. In CI and stub runs everything is synthetic, so today's
  exposure is synthetic — but the same pipeline runs locally against
  the real installation in LIVE-FIRE mode, where Path A would embed
  head-3 of *real CLI* output (whose content the harness does not
  control) and Path B would echo real blocked lines. A shared local
  report could carry a real token verbatim.
- **Recommendation:** add a secret-shaped-token redaction pass to
  `scrub_transcript()` (and ideally `scrub()`), reusing the audit's
  SHAPES set — the same shapes the fixture-purity check already
  maintains. This is already on the iterations 6–10 backlog ("Report
  transcript secret-shaped-token redaction"); it should be treated as
  the privacy-blocking item of this iteration. Separately, make the
  fake Messenger delegate stop echoing stdin on the failure path (hash
  the stdin like argv, or truncate evidence to the hash line) so the
  "failure evidence must not carry fixture content" comment is true.
- **Residual if not fixed:** any locally generated report that includes
  a failing send detail or a gate-log line with a secret-shaped token,
  if shared or screenshotted without the surrounding page, discloses
  the token. The green-path cleanliness (verified above) does not cover
  failure paths, which are exactly the reports most likely to be shared
  for debugging.

### P2 — E3's exemption paragraph gestures at a relief valve that cannot apply to its own case

- **Evidence:** `references/attack-surface.md:271-286` (E3) vs `:247`
  (E1) and `references/gate-interface.md` (approval override: "must
  NEVER turn a block-tier 1 into 0").
- E3 is honest about the false-positive *cost* — it names the colliding
  shapes (order IDs, reference numbers, ticket numbers) and the
  approval-fatigue mechanism. The gap is the remedy paragraph: "The
  review tier exists for exactly this kind of judgment call; if the
  owner rules a specific nine-digit literal non-sensitive, the exemption
  path is the installation's `.egress-allowlist` (review tier only) —
  never a pattern carve-out." But `ssn_bare` is **block-tier** (corpus
  `ssn_bare|1`, `bin/adversarial-corpus.txt`), and E1 itself states the
  allowlist is "review tier only; never for block-tier shapes". For a
  block-tier 9-digit false positive there is *no* relief valve at all:
  approval cannot override it (approval isolation, verified by suite B),
  the allowlist cannot exempt it, and E3 forbids a pattern carve-out.
  The paragraph implies a per-literal judgment path that does not
  exist for this tier.
- **Recommendation:** state it plainly in E3: block-tier shapes have no
  per-literal exemption — a 9-digit order ID is refused outright with no
  override, and that total friction is the deliberate price of the
  conservative default. One focused doc edit; no corpus or pattern
  change.
- **Residual if not fixed:** readers (and future maintainers) believe a
  nine-digit literal can be allowlisted after a judgment call, and are
  surprised — or design around — a hard block that has no documented
  escape hatch. The confusion is precisely the approval-fatigue-adjacent
  friction E1 warns about.

### P2 — No mechanism to add near-miss negative traps without touching the pinned 36-case corpus

- **Evidence:** `bin/adversarial-run` hardcodes
  `CORPUS="$SKILL_DIR/bin/adversarial-corpus.txt"`; `bin/leakage-report`
  passes only that file as `corpus_src` (per-case table + 3×3 matrix).
  There is no second corpus input, no `corpus.d/` directory, no
  `--corpus` flag.
- The brief asks whether near-miss cases (e.g. `AIzaX` trivial match,
  9-digit vs 10-digit boundaries, `api_key=` with short values,
  separator-variant Amex) can be added without revising the parent
  constraint. Today they cannot: any new case edits the pinned file,
  which the constraint forbids.
- **Recommendation:** add a *supplemental* corpus input —
  `bin/adversarial-corpus-nearmiss.txt` (empty/absent = skipped) —
  executed by `adversarial-run` and rendered by the report in its own
  section, leaving `bin/adversarial-corpus.txt` byte-identical. The
  pinned 36 stay pinned; the near-miss traps live beside them with
  their own want/got semantics. This is already on the backlog
  ("Near-miss negative traps (corpus stays pinned at 36 unless
  revised)").
- **Residual if not fixed:** the adversarial suite can never probe the
  detector's decision boundaries — the exact region where a real
  regression (over/under-matching on shape edges) would hide — without
  violating the pin. Boundary precision stays untested by construction.

### P3 — Carry-forward nits from the iter5 privacy review (all still present, all low)

- **Evidence:**
  - `test/stub-memory-skill/bin/patterns.sh:21`: `AIza[A-Za-z0-9_-]+`
    still has no minimum length (iter5 P2 recommended
    `AIza[A-Za-z0-9_-]{10,}`). "AIzaX" classifies as a secret candidate.
  - `bin/fixtures/SYNTHETIC.txt:22`: `5550001234` still declared though
    unextractable by either pattern set (inert declaration; iter5
    recommended removal or annotation).
  - `bin/leakage-audit:589`: fixture-purity scan glob still covers only
    fixtures + corpus; no docs coverage and no "docs are out of scope,
    review by hand" note (iter5 P2 offered either; neither landed).
    `CONTRIBUTING.md:10-14` still scopes the synthetic rule to the same
    three locations.
  - `test/stub-memory-skill/README.md:21-35`: "What this stub is NOT"
    still lacks the iter5-recommended sentence warning against copying
    the declared-set *lookup architecture* into a real gate (the
    deployment warning is adequate; the architecture-copy warning is
    not there).
  - Shape divergence (residual of the fixed iter5 P1): the stub
    extractor matches separator-variant Amex
    (`\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b`) but the audit's
    SHAPES only matches bare 15-digit (`\b3[47][0-9]{13}\b`) — a
    `3782-822463-10005` fixture token would be a stub candidate the
    purity check cannot see. (16-digit card alternations differ in
    formulation but cover the same shapes.)
- **Recommendation:** fold into one focused diff: tighten the AIza
  floor, drop or annotate the `5550001234` line, add the docs
  out-of-scope note (or extend the glob — all currently-quoted doc
  tokens are already declared, so the check would stay green), add the
  one-sentence lookup-architecture warning, and align the Amex
  alternation.
- **Residual if not fixed:** each is minor in isolation; together they
  are slow drift in exactly the machinery whose job is to stay
  fail-closed.

## Verified non-findings (checked, deliberately not raised)

- **CI artifacts are synthetic-only.** `validate.yml` runs stub-only
  (shallow checkout, no secrets, live-fire variables refused,
  `local.env` refused, skip set pinned at 2). The uploaded HTML is the
  stub report; the step summary greps only `Total:` / adversarial
  count lines from stub logs. The green-path report was verified
  empirically clean (no secret-shaped tokens, emails, or home paths).
  14-day artifact retention is fine for synthetic content.
- **argv-hash evidence is sound on the Gmail path.** Failing Gmail
  checks emit `argv-sha256=<hash>` only — no payload. (The Messenger
  path is Finding P1a.)
- **E3's false-positive *cost* is stated honestly.** The colliding
  shapes and the approval-fatigue mechanism are named; the conservative
  "missed SSN costs more than refused order ID" judgment is explicit.
  Only the exemption paragraph (P2) misleads.
- **Interface version is declared but not enforced** (docs +
  `.synthetic-stub` say `interface_version=1`; nothing in
  `bin/leakage-audit` reads it). Noted for the systems reviewer — it's
  on the backlog ("Interface-version enforcement") and is a
  correctness/contract issue rather than a privacy leak, so I leave it
  to that lane.
- **Generated reports are gitignored** (`hidden_files/reports/*`,
  `reports/*` in `.gitignore`, verified via `git check-ignore`) —
  a local real-installation report cannot be committed by accident.
- **Corpus tiering remains disciplined** (re-verified: all `want=1`
  are secret/credential/SSN/card shapes; `want=2` figures/phones;
  `want=0` genuinely clean; the two deliberate exceptions documented).
- **`local.env` stays untracked**; `local.env.example` contains no real
  values.

## Scope notes

- Read-only throughout: the failure-path and D-suite demonstrations
  ran against a copy of the repo in `/tmp/lg` (stub gate tampered
  there only); the real repo at HEAD `5ff8950` is untouched. Report
  outputs were written to `/tmp` (`--out`), never into the repo.
- The real gate log format (`~/workspace/memory-sync/egress-gate.log`)
  was inspected read-only with values masked, solely to determine
  whether payload snippets reach the D-suite — they do not in the
  current format (context labels only).
