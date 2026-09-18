# Iteration-9 review — Senior PM (product value & report honesty)

Reviewer: Senior PM · date 2026-09-17 (report generated 2026-09-18 00:21 UTC) ·
repo HEAD `e35c1bc` ("Iteration 8: report integrity and readability"), not pushed.

Method: ran `bin/leakage-report --out /tmp/pm-review-report.html` against the
real installation (SIMULATED, exit 0) and against the synthetic stub
(`PERSONAL_MEMORY_SKILL=test/stub-memory-skill`, exit 0); read both HTML
reports end-to-end as the product; rendered the real-install report in local
headless Chrome at 390px and 1280px; empirically fired secret-bearing
payloads at the stub shims with fake delegates; empirically crashed the stub
detector; cross-checked report text against `bin/leakage-report`,
`bin/leakage-audit`, `bin/adversarial-run`, `references/`, `README.md`,
`SKILL.md`, `CHANGELOG.md`, `ITERATIONS.md`, `.github/workflows/validate.yml`.

Note on the read-only constraint: no repo files were modified and nothing was
committed, pushed, or sent. This review file itself is the explicitly
requested deliverable, written to the designated `hidden_files/iter9-reviews/`
directory. Scratch/execution artifacts live in `/tmp/pmrev/` (outside the repo).
The stub copies used for crash/bypass tests were copies in `/tmp`, never the
repo's files. All payloads were the repo's own synthetic fixtures or
throwaway synthetic strings.

## Verdict on the product

Iteration 8 was a genuine readability win — the tri-state callouts, verdict
definitions, plain-language residual glosses, dynamic legend, card-D evidence,
and stub banner are all present and correct in the generated report, and the
mobile/desktop renders are clean and scannable. The report now tells the
truth about what it *ran*.

It does not yet tell the truth about what it *didn't run*. The three P1s
below are all the same shape: a green report that implies coverage of a
surface the harness never examines — ungated send subcommands, the
detector-crash path, and a CI gate that a gutted corpus would still pass.
The iter8 synthesis explicitly deferred the gate fixes to iteration 9
("the report now *shows* these gaps honestly instead of masking them") —
but as of this HEAD the report does **not** show the bypass class or the
fail-open path anywhere: not in Known gaps, not in a callout, not in the
catalog's audited surface. A non-expert owner reading a CLEAN report today
would reasonably conclude "every way my data could leave was tested." That
conclusion is not supported.

13 findings: 3 × P1, 4 × P2, 6 × P3. Findings marked **[exec]** are
confirmed by execution; **[static]** by code/doc analysis.

---

## P1

### [exec] P1-1. The report implies send-path coverage while five secret-capable send paths sail through ungated — and none of them appear anywhere in the report
- Where: `test/stub-memory-skill/bin/shims/hatch_gws_cli` (the `gmail`
  `case` handles only `+send|+reply|+forward`, `users` with literal
  `messages`+`send` tokens, and `drive`; everything else falls through to
  `pass_through`). The real installation's shim
  (`~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli`)
  has the same shape.
- Confirmed by execution (stub shims + fake delegates, synthetic
  `sk-test-…` secret in body / base64 `raw` MIME; controls included):

  | command | rc | delegate invoked? |
  |---|---|---|
  | `gmail +reply-all --body <secret>` | 0 | **yes — ungated** |
  | `gmail users drafts send --params {"raw":<secret MIME>}` | 0 | **yes — ungated** |
  | `gmail users messages import --params {"raw":<secret MIME>}` | 0 | **yes — ungated** |
  | `gmail users messages insert --params {"raw":<secret MIME>}` | 0 | **yes — ungated** |
  | `gmail users settings updateAutoForwarding` | 0 | yes — ungated (control-path, no payload needed) |
  | CONTROL `gmail +reply --body <secret>` | 2 | no — refused |
  | CONTROL `gmail users messages send --params {"raw":<secret MIME>}` | 2 | no — refused |

- Why it matters (product/honesty, not just security): card B's callout
  reads "🟢🟡 Gate effectiveness: 16 blocked outright · 6 protected
  through approval · 11 allowed normally" — a non-expert reader takes this
  as "the ways I can send things were tested and hold." The Known-gaps
  card lists 10 residuals; this bypass class is not among them. The
  attack-surface catalog's "Coverage discipline" section states the
  project's own rule: *"A path with no scenario is an unexamined path —
  that is the failure mode this skill exists to prevent."* These paths
  have no scenario, no catalog row, no audit check — and the iter8
  synthesis already knew about most of them (deferred to iter 9 as "P0
  stub-shim bypasses"). The report at this HEAD nevertheless renders CLEAN
  with no mention of them. That is misleading by omission.
- Sharpest instance for the owner: `--draft` passes through ungated **by
  design** (A5: drafts never leave the account), and `drafts send`
  delivers a draft ungated **by omission**. The two individually-defensible
  rules compose into a complete gate bypass: draft a secret (allowed,
  ungated) → `drafts send` (allowed, ungated) → the secret leaves. Neither
  step trips anything, and the report blesses both steps.
- Suggested remediation: (a) short-term (report honesty): add the bypass
  class to suite E / Known gaps until hardened — e.g. "Some send commands
  this check doesn't watch yet (`+reply-all`, `drafts send`, `messages
  import`/`insert`, forwarding-rule changes) aren't gated — listed here
  until the shims cover them"; (b) structural: extend
  `references/gate-interface.md`'s interception contract beyond `messages
  send` (it currently names only `+send|+reply|+forward`, `messages send`,
  `drive permissions create`, messenger `send|edit`), add A-series catalog
  rows, and add audit probes. Note `messages import`/`insert` were not in
  the iter8 deferred list — same bypass class, additional instances.

### [exec] P1-2. The gates fail OPEN on detector crash, violating the written contract — and the audit's one "fail-closed" check tests a different failure mode
- Where: `test/stub-memory-skill/bin/egress-gate` lines 25–31 (and the
  identical shape in `bin/brief-gate`): only detector `rc=1` → exit 1 and
  `rc=2` without approval → exit 2 are handled; **any other detector exit
  code falls through to `exit 0` (allow)**.
- Confirmed by execution: copied the stub to `/tmp`, replaced
  `bin/memory-egress-check` with `exit 3`, ran both gates over a
  secret-bearing file → `EGRESS_GATE_RC=0`, `BRIEF_GATE_RC=0` (content
  allowed through).
- Why it matters: `references/gate-interface.md` ("Exit codes") states the
  contract explicitly: *"Non-verdict errors are not verdicts: usage errors,
  missing inputs, undecodable payloads, and missing interpreters must fail
  closed — surface as block (1) or another nonzero code, but NEVER as 0
  (allow) and NEVER as 2 (review) … a broken detector must not be
  approvable."* The stub violates this clause. Worse for report honesty:
  suite A *does* contain a check named "operational failure (missing
  blockset) fails closed under approval (rc=1)" which PASSES — it exercises
  a *detector-internal* fail-closed (missing blockset → detector rc=1),
  not the *gate's* handling of an abnormal detector exit. A reader (or a
  future maintainer) can easily take that green check as "error paths are
  fail-closed," which is false for the crash path. The audit has no check
  for abnormal detector exit codes at all.
- Suggested remediation: add a contract-conformance probe — run the
  target's gates against a detector that exits 3 / 124 / 137 (in a `/tmp`
  copy, as done here) and require rc=1; until the gates are fixed, list
  "detector crash → allowed" in Known gaps. This is the deferred
  "Gates fail OPEN on detector crash" thread — the report should show it
  while iteration 9 fixes it.

### [static] P1-3. CI pins the skip set but not the totals — a gutted corpus stays green
- Where: `.github/workflows/validate.yml`. The "Assert the pinned CI skip
  set" step pins exactly 4 skips; the final "Assert green" step checks only
  component exit codes. `@@@ TOTAL` and `@@@ ADV MATCHED` are read from
  logs for the *informational* summary only (lines ~264, ~285) — nothing
  asserts their values.
- Why it matters: suite A's corpus check is `corpus_cases -ge 1`. A corpus
  gutted to a single trivially-passing case yields: audit exit 0,
  adversarial `1/1 matched` exit 0, 4 pinned skips intact → green CI, green
  badge, and a report whose hero says "CLEAN means every check passed."
  The "36" in the report is read from the run, never pinned. For a
  validation tool whose whole value proposition is "the check actually ran,"
  the headcount of checks is the load-bearing number — and it is the one
  number CI does not pin. (Deferred from iter8 as "Pinned totals in CI,"
  still open at this HEAD.)
- Suggested remediation: extend the skip-assert step (or add a
  totals-assert step) to pin `@@@ TOTAL` and `@@@ ADV MATCHED` against
  expected values (e.g. corpus case count = 36), failing the job on
  mismatch — the same treatment skips already get.

---

## P2

### [static] P2-1. Memory-audit evidence is republished verbatim; the "judge public vs private yourself" instruction arrives after the copy
- Where: `bin/leakage-audit`, suite C — `detail="$(printf '%s\n'
  "$audit_out" | grep -E '^  (/|!)' | head -12)"` then
  `bad "memory-audit reported findings (judge public vs private yourself)"
  "$detail" …`. The verbatim lines land in the plain-text report, the
  HTML evidence, and the raw transcript. The report's `scrub()` only
  redacts email addresses and shortens `$HOME`.
- Why it matters: the memory-audit findings are file paths / content flags
  from the owner's real memory tree. The human is asked to classify public
  vs private *after* the tool has already copied the strings into a report
  artifact — classification theater, not classification. (Deferred from
  iter8 as "Memory-audit literal republication," still open.)
- Suggested remediation: summarize or hash the finding lines instead of
  copying them verbatim (per the deferred thread), and move the
  public-vs-private guidance ahead of any content inclusion. Note the
  check is opt-in (`MOCHI_MEMORY_AUDIT=1`), which bounds exposure but also
  means the highest-value audit (real memory contents) is the one most
  users never run — worth one line in the docs.

### [static] P2-2. The contract promises `to` is gated; the real shim doesn't gate it; the stub does; no test distinguishes them
- Where: `references/gate-interface.md` ("Shim interception contract"):
  "Gmail `+send`, `+reply`, `+forward`: subject/body/**to** pass
  `egress-gate`." The stub shim gates
  `printf 'to: %s\nsubject: %s\n\n%s\n' "$to" "$subject" "$body"`. The real
  shim gates only `printf 'subject: %s\n\n%s\n' "$subject" "$body"` — the
  recipient is excluded from the gated content.
- Why it matters: this is a three-way disagreement (contract vs. stub vs.
  real installation) about what "gated" means, and the audit has no probe
  that would catch any of the three being wrong — suite B never puts a
  secret or phone-shaped value in `to`. A validation harness that cannot
  distinguish "contract honored" from "contract violated" on a stated
  clause is not validating that clause. Practical exploitability is low
  (secrets in `to` are contrived), but the *validation-integrity* point
  stands: either the contract overstates the real protection or the real
  shim under-implements the contract, and today nothing would tell the
  owner which.
- Suggested remediation: add a suite-B probe with a block-tier token and a
  phone-shaped value in `--to` (expecting the contract's behavior), or
  narrow the contract to subject/body with a written rationale — then make
  stub and real agree.

### [static] P2-3. "Detection performance" / "adversarial" overclaims what is fixture conformance against author-set labels
- Where: card F callout — "🟢 Detection performance: 36/36 attack test
  cases matched the expected result." The corpus
  (`bin/adversarial-corpus.txt`) contains 36 plain payloads and zero
  injected- or adversarial-shaped cases; the catalog itself admits this
  (test-matrix.md, C5: "no injected-shaped payload exists in
  fixtures/corpus"). "Expected" is set by the same authors who wrote the
  detector patterns — the score is circular by construction. For the stub
  the circularity is total: `build-blockset.sh` literally builds the
  detector's token set *from the corpus's want=1 cases* (verified).
- Why it matters: the report does carry honest caveats ("Pass rates over 36
  author-designed test cases — not a real-world sample, and not ML
  recall/precision"), but they live in the expandable detail while the
  headline says "Detection performance" — the phrase a non-expert owner
  will quote. "Performance" implies measured capability against attacks;
  what was measured is agreement with the authors' own labels on plain
  payloads. (Related to the deferred data-science thread "corpus labels
  treated as unquestionable ground truth.")
- Suggested remediation: rename the card to "Detector conformance
  (author-designed cases)" and qualify the callout, e.g. "36/36 matched
  their expected verdicts on 36 author-designed cases — not a measure of
  real-world attack detection." Longer term: add injected-shaped cases
  (deferred to iter10) so "adversarial" earns its name.

### [static] P2-4. The B2/B3 public-repo literal scan never runs in CI — the one check guarding public repos against real literals is machine-local only
- Where: suite C's denylist scan reads
  `$PERSONAL_MEMORY_ROOT/memory/.egress-denylist`; absent in CI → skip,
  and CI's pinned skip set *expects* that skip ("no egress denylist").
- Why it matters: the catalog presents B2/B3 as covered by "C: tracked
  files of both public repos scanned against the egress denylist" — but in
  the CI run (the run the public badge reflects) that check is always a
  skip. The denylist necessarily holds the owner's real literals and can't
  go to CI, so this is structural — but the docs/report should say plainly
  "the public-repo literal scan runs only on the owner's machine; CI does
  not verify it," instead of letting the coverage table imply uniform
  enforcement.
- Suggested remediation: one honest line in `references/test-matrix.md`
  (B2/B3 rows) and the README noting the CI skip; optionally a CI-safe
  variant that scans for *shape* classes rather than the owner's literals.

---

## P3

### [static] P3-1. ITERATIONS.md is stale: iterations 7 and 8 have no entries, and 5/6 are out of order
- Where: `ITERATIONS.md` — `grep "^## Iteration"` lists 1, 2, 3, 4, 6, 5;
  nothing for 7 ("Contract conformance") or 8 ("Report integrity and
  readability"). Last touched at `e20a819` (Iteration 6).
- Why it matters: this is the file a new contributor or auditor reads to
  learn what each iteration changed and why; it now disagrees with
  `CHANGELOG.md` and the git log. (Deferred from iter8, still open.)
- Suggested remediation: add the Iteration 7 and 8 entries (the CHANGELOG
  entries are a good source), fix the 5/6 ordering.

### [static] P3-2. Iteration-8 leftovers still in the report text
Four items the iter8 PM review asked to fix that are still present at this
HEAD (all in `bin/leakage-report`'s Python):
1. "Detector check — no sends in either mode." — the "either mode"
   fragment the review asked to clarify or drop is still in the F-card
   blurb, in both real and stub runs.
2. Confusion-matrix caption "Expected vs actual exit code (3×3)" — the
   "(3×3)" dimension jargon was to become "Expected vs actual result."
3. Card-A evidence still says "fixture clean.txt present and non-empty"
   (the review suggested "test file" for non-engineers).
4. Skip reasons are still engineer-facing ("stub-only: exercises the
   synthetic stub's fail-closed error paths"; "the contract names no
   declaration point for real skills yet — see
   references/gate-interface.md"). The one-line "Skipped = …" definition
   was added (good); the reasons themselves were not plain-languaged.
- Suggested remediation: apply the four as written in the iter8 review.

### [exec] P3-3. Timestamp renders redundantly when local time is UTC
- Where: hero meta — "2026-09-18 12:21 AM UTC (2026-09-18 00:21 UTC)".
  `fmt_ts()` always appends the UTC original, even when the local zone
  *is* UTC (as in this container), producing a doubled timestamp. On the
  owner's machine (America/Los_Angeles) it renders correctly as e.g.
  "5:21 PM PDT (00:21 UTC)".
- Suggested remediation: only append the "(… UTC)" original when it
  differs from the local rendering.

### [exec] P3-4. Card-B callout's "2 other" is opaque
- Where: "🟢🟡 Gate effectiveness: 16 blocked outright · 6 protected through
  approval · 11 allowed normally · **2 other**, 1 skipped." The "Other
  evidence" group holds the stdin-replay check and the stub-only skip —
  "other" means nothing to a non-expert reader.
- Suggested remediation: fold the replay check into the pass-through
  group (it *is* an allow-path check) and let the skip join the skip
  count, or label the group plainly ("Delivery-integrity evidence").

### [exec] P3-5. Known-gaps subtotal wraps awkwardly inline
- Where: desktop render — "Known gaps: 10 things this check can't cover —
  listed openly, none hidden. **10 tracked · 0 hidden**" — the subtotal
  fragment lands mid-line after the callout sentence. Minor visual scruff
  on an otherwise clean card.
- Suggested remediation: render the subtotal on its own line (as red/skip
  cards already do).

### [static] P3-6. Stub-run hero verdict overstates: "nothing that should have been stopped got through"
- Where: the verdict definition under the badge is identical in stub runs,
  where the bypass class in P1-1 demonstrably gets through untested.
- Why it matters (small): the banner, page title "(synthetic stub)", and
  footer already blunt this, and catalog E2 acknowledges the screenshot
  risk — so this is defense-in-depth polish, not a new hole.
- Suggested remediation: in stub mode, qualify the definition, e.g.
  "CLEAN (stub): the harness's own checks passed — this says nothing
  about real protection."

---

## Iteration-8 fix verification (what the prior PM review asked for)

Fixed and verified in the generated report: tri-state 🟢/🟡 callout on
card B with tiered evidence groups (P1-1); card-D gate-log evidence
rendered (P1-2); plain-language residual glosses with technical notes
retained (P1-3); card-E "N tracked · 0 hidden" subtotal (P2-1); card-E
`.tested` de-duplicated (P2-2); rc codes defined in the legend,
`invoked=0/1` → "real tool never called"/"delivered normally" (P2-3);
"Skipped = …" definition (P2-4); CLEAN/ATTENTION/INCOMPLETE defined under
the badge (P2-5); Clopper-Pearson label replaced with the plain "Worst
case consistent with these results" line and the triple caveat
consolidated (P2-6, minus the "either mode" fragment — see P3-2);
CHANGELOG gained the Iteration 7 entry (P2-7); README/SKILL.md no longer
say "green/red callout" (P3-1); hero tagline "Automated
privacy-protection check" added (P3-2); local time rendered with UTC
original (P3-3, minus the UTC==local redundancy — see P3-3); card-B blurb
uses "attack tests run against fake stand-ins" (P3-4); legend renders only
treatments present in the run (P3-5); total box disambiguates the 63 vs 36
(P3-6); `.card.skip` has an explicit CSS rule (P3-7); callout says "attack
test cases" not "corpus cases" (P3-9). Not fixed: the four P3-2 leftovers
above.

## Checked, fine (not findings)

- Email redaction (`[redacted]`) and `~` shortening hold in the HTML body,
  evidence, and transcripts; no other PII-shaped strings in either report.
- The stub's blockset circularity (detector built from the corpus) is
  labeled honestly everywhere it appears: modebar banner, card-F callout
  ("Stub consistency … not detector validation"), footer, CI summary, and
  SKILL.md/contract docs. The label is doing its job; the measurement is
  what it says it is.
- CI safety shape is strong: live-fire and local.env refuse steps are
  fail-fast, `pull_request` (not `pull_request_target`), `contents: read`,
  shallow checkout, SHA-pinned actions, no secrets.
- Report structure for the failure case (findings section above cards,
  `#card-X` links, red cards pre-expanded server-side) is sound by code
  reading; this green run could not exercise it visually.
- The fail-open detector-crash shape was also noted as observed in the
  real installation (per the iter8 synthesis); fixing the real gates is
  out of scope for this skill (validation-only) — but *detecting and
  reporting it* is squarely in scope, hence P1-2.

## Priority framing for iteration 9

If iteration 9 is the gate-hardening iteration, the highest-value
validation work alongside it is: (1) put the P1-1 bypass class and the
P1-2 crash path into the audit as probes *first* (they will fail, which
is the point — the report then shows the gaps honestly while the shims
are hardened, and goes green as each is closed); (2) pin the totals in CI
(P1-3) so the green badge survives contact with a gutted corpus; (3) take
the four P3-2 one-line text fixes, which are cheap. The P2s are
report-honesty debt worth scheduling but not blockers for the hardening
work.
