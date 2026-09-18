# Iteration-8 review — Senior security engineer

Target: `~/workspace/skills/muse-leakage-guard`, HEAD `2243723` ("Iteration 7:
contract conformance"), branch `main`.
Mode: REVIEW-ONLY, simulated. No `MOCHI_LIVE_FIRE`, `local.env` untouched,
all payloads synthetic, no writes to the repo. All probes ran on `/tmp`
copies; the repo tree was only read.
Method: full-repo read of `bin/leakage-audit`, `bin/adversarial-run`,
`bin/leakage-report`, `.github/workflows/validate.yml`, both stub shims,
both stub gates, `bin/patterns.sh`, `build/build-blockset.sh`,
`references/gate-interface.md`, `references/attack-surface.md`,
`references/test-matrix.md`, `bin/adversarial-corpus.txt` — plus empirical
probes for every deferred iter-7 thread in my lens and every new claim below.
Baseline at HEAD: audit vs stub = CLEAN (66 passed / 0 failed / 2 skipped);
adversarial-run = 36/36 (block 19/19, review 9/9, clean 8/8).

## Verdict summary

18 findings: **1 P1, 6 P2, 9 P3, 2 P4**. 12 of the 18 are empirically
confirmed (deterministic reproductions on `/tmp` copies); the rest are
confirmed by code inspection with exact line references. Iteration-7's
fail-opens (stdin MIME, draft token-confusion, delegate self-exec,
`die()`→2, interface_version, live-fire timeout) were re-verified as fixed
and are not re-reported. Two carryovers from the deferred list are verified
fixed ("Detection performance" mislabel is fixed only on the all-matched
path — see P3-8; the C5/A7 wording fixes hold).

The single most important result: **the reference gates fail OPEN when the
detector crashes** (P1-1) — a contract violation in the iteration that was
about contract conformance, and the same shape was found by read-only
inspection in the real installation's gates.

Severity rubric: P1 = fail-open / contract-violating behavior in the
reference implementation; P2 = measurement-integrity hole (green output
that does not mean what it claims) or conditional bypass needing one
verification step; P3 = diagnostic-accuracy / hardening / label-honesty
gaps; P4 = cosmetic or test-double fidelity nits.

---

## P1

### P1-1 — Stub gates fail OPEN (rc=0) when `memory-egress-check` exits with any non-0/1/2 code — detector crash becomes allow

**Evidence:**
- `test/stub-memory-skill/bin/egress-gate:25-33`:
  `RC=1` → block; `RC=2 && !APPROVED` → review; otherwise **falls through
  to `exit 0`**. Any detector exit outside {0,1,2} — 137 (SIGKILL/OOM),
  139 (SIGSEGV), 143 (SIGTERM), 126/127 (not executable / not found) —
  returns **allow**.
- `test/stub-memory-skill/bin/brief-gate:20-25`: identical fallthrough.
- Contract (`references/gate-interface.md`, "Exit codes"): *"Non-verdict
  errors are not verdicts … must fail closed — surface as block (1) or
  another nonzero code, but **NEVER as 0 (allow)** and NEVER as 2
  (review), because approval can downgrade a 2 to 0 and a broken detector
  must not be approvable."* The stub claims interface version 1 and
  violates it.

**Reproduction (simulated, `/tmp` copy, synthetic fixtures):** stub copy
whose `memory-egress-check` is `kill -9 $$` (simulates OOM-killer /
external SIGKILL mid-scan):
- `egress-gate --content-file <secret.txt> --context …` → **rc=0** (allow).
- `brief-gate --brief-file <secret.txt> --task …` → **rc=0** (allow).
Deterministic. Direct invocation of the detector gives rc=137, proving the
gate — not the detector — converts the crash into allow.

**Why the existing tests miss it:** suite A's "operational failure fails
closed" test removes `blockset.txt`, which exercises `die()` → exit 1 —
the *handled* error path. No check exercises a detector that dies by
signal or exits 126/127/143. CI is green with this fail-open present.

**Portability (read-only inspection, out of this repo's diff scope):**
`~/workspace/skills/personal-memory-system/bin/egress-gate` (the real
installation) has the same shape — `verdict="clean"; rc=0` initialized,
then only `grc==1` / `grc==2` override it; any other `grc` keeps
`verdict=clean, rc=0`, logs "clean" to the real gate log, and `exit 0`.
The real `brief-gate` `exec`s into it, inheriting the hole. The real shim
proceeds on `rc==0` only, so a crashed detector → **the send proceeds**.
The iter-7 commit note already recorded true-positive fail-opens in the
real installation; this is a third candidate of the same family.

**Recommendation:** in both stub gates, replace the fallthrough with an
explicit case: `0` → allow; `1` → block; `2` → review-or-allow; `*` →
fail closed as block (rc=1) with a distinct stderr message. Add an audit
probe: detector replaced by `kill -9 $$`, gate called **with
`MOCHI_EGRESS_APPROVED=1`** on a block-tier fixture, assert rc=1. Port
the same fix to the real installation's `egress-gate` (the pattern is
identical).

**Residual if not fixed:** any crash of the detector process — OOM,
SIGKILL, segfault, missing interpreter — silently converts to allow, in
the reference test double *and* (by inspection) the deployed gate. The
audit's fail-closed story covers only the `die()` path.

---

## P2

### P2-1 — Report badge says CLEAN (green) while the F card is red: adversarial figures unparseable but `adv_rc == 0`

**Evidence:** `bin/leakage-report`, badge logic:
`clean = (verdict_word == "CLEAN" and adv_rc == 0)`. It keys on the
runner's *exit code*, not on whether its figures were actually parsed
(`adv is not None`).

**Reproduction (`/tmp` copy):** `bin/adversarial-run` replaced with a stub
that prints no sentinels and exits 0 (truncated/corrupt runner output).
Result: report rc=0, badge `<span class="badge ok">CLEAN</span>`, while
card F is `class="card red"` with callout "🔴 Detection performance:
adversarial runner failed — see transcript." The pipeline's one-sentence
verdict contradicts its own evidence card, and the exit code (0) tells CI
"report written (exit 0 — CLEAN)".

**Recommendation:** `clean = (verdict_word == "CLEAN" and adv_rc == 0 and
adv is not None)`. Any unparseable component must force the badge to
ATTENTION/INCOMPLETE, never CLEAN.

### P2-2 — No pinned pass/adversarial totals: a gutted corpus yields a fully green pipeline

**Evidence:** the audit asserts only `corpus_cases >= 1`
(`bin/leakage-audit`); CI pins the *skip* set (exactly 4) but no pass
total and no adversarial total (`validate.yml`).

**Reproduction (`/tmp` copy):** corpus reduced to a single clean case,
`build-blockset.sh` re-run (so `--check` stays green):
- audit: **CLEAN, 66 passed / 0 failed / 2 skipped** ("adversarial corpus
  has 1 cases" passes);
- `adversarial-run`: **1/1 matched, exit 0** (block-tier 0/0, review 0/0);
- CI components would all be green.

**Recommendation:** pin the expected totals the way the skip set is
pinned — audit asserts the corpus case count equals the committed count
(or CI asserts `@@@ ADV MATCHED 36/36` exactly, not just rc=0). This was
the deferred "exact pass-total / adversarial-total assertions" thread;
the probe shows the erosion is silent end-to-end today.

### P2-3 — Fixture-purity SHAPES and stub candidate patterns have drifted; no shared manifest or cross-check

**Evidence:** the purity guarantee ("every secret-shaped token in
fixtures/corpus is declared synthetic") rests on two independently
maintained literals: `SHAPES=` in `bin/leakage-audit` and
`STUB_SECRET_CAND=` in `test/stub-memory-skill/bin/patterns.sh`, with only
a prose claim that the latter is a superset of the former.

**Reproduction (differential probe, all synthetic):** tokens detected by
the stub extractor but invisible to the audit purity check:
`4111-111111111111`, `41111111-1111-1111`, `4111 111111111111`,
`411111111111-1111` (mixed-separator 16-digit card shapes) — audit=False,
stub=True. A fixture containing such a shape passes the purity check with
no `SYNTHETIC.txt` declaration. (The reverse direction self-corrects via
adversarial mismatches; this direction does not.)

**Recommendation:** the deferred "SHAPES manifest or fixture-purity
cross-check" — single-source the shape list (one file both scripts read)
or add a CI step asserting the two literals are equivalent over a shape
exercise set. Until then the purity check is shape-incomplete.

### P2-4 — Report redaction covers email addresses (and `$HOME`) only; failure evidence can carry payload bytes into the persisted HTML

**Evidence:** `bin/leakage-report`: `scrub()` = `EMAIL_RE` only;
`scrub_transcript()` = `EMAIL_RE` + `$HOME`→`~`. No redaction of
secret/phone/figure-shaped tokens.

**Reproduction (`/tmp` copy, stub detector neutered so a secret passes):**
`send_expect`-style failure evidence prints
`REAL-MSG-INVOKED argv-sha256=…|---stdin---|Also tried: -----BEGIN FAKE
PRIVATE KEY-----|…` — the secret payload's first line lands in the audit
finding, hence in the transcript `<pre>`, hence in the persisted HTML
artifact. Trigger condition is "the gate erroneously allowed" — exactly
the failure class this harness exists to catch.

**Scope note:** suite B fixtures are synthetic by policy, so no live
exposure today. But the transcript also carries live-fire real-CLI output
(`live_send_expect` failure evidence) and real gate-log lines (suite D),
where `EMAIL_RE`-only scrubbing is shape-incomplete. Defense in depth:
hash stdin bytes for the replay-integrity comparison and for evidence
(the deferred "messenger stdin-echo hashing" thread) instead of echoing
them, and extend transcript scrubbing to the secret/phone/figure shapes
from a shared manifest (P2-3's manifest would serve).

### P2-5 — Real shim `--draft` detection vs `--` end-of-options: conditional gate bypass (needs one verification step; pattern note for this repo)

**Evidence (read-only; real installation, out of this repo's diff scope):**
`~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli`
`+send` parser sets `is_draft=1` whenever `--draft`/`--dry-run` appears
with an empty `prev`, with **no `prev_opt` tracking**. The stub shim
(iter-7) *does* track `prev_opt`, so `--draft` after `--` is treated as a
flag value (gated content), not a flag.

**Conditional bypass:** `hatch_gws_cli gmail +send --body <secret> --
--draft` — the real shim sees `--draft` with `prev` empty → `is_draft=1`
→ **passes through UNGATED**. If the underlying CLI honors `--` as
end-of-options, `--draft` is a positional there (not a draft flag) and
the send is a **real, ungated send** carrying the secret. The stub cannot
reproduce this (its stricter parser blocks it), so the harness validates
a stronger shim than the one deployed — a parity gap in the test double.

**Recommendation:** verify against the real CLI whether `--` is
end-of-options; if yes, port the stub's `prev_opt` strictness (or
explicitly reject `--` in send argv) to the real shim, and add a
red-team case (`+send -- --draft` with secret → must be blocked, not
passed through).

### P2-6 — Neither shim intercepts `gmail users drafts send` (conditional on the CLI exposing it)

**Evidence:** both stub and real GWS shims gate `users messages send`
(anywhere-token `messages`+`send`) but not `users drafts send`. The
Gmail API has `users.drafts.send`; if `hatch_gws_cli` exposes it, it is a
raw-API send path that bypasses the MIME gate in both shims. The contract
(`gate-interface.md`) does not list it.

**Recommendation:** verify whether the CLI exposes `users drafts send`;
if yes, add it to the interception contract and both shims (or document
why it cannot send). Fails closed today only if the subcommand does not
exist.

---

## P3

### P3-1 — Timeout-budget asymmetry: audit (30s) vs adversarial-run (10s) contradict each other on a slow-but-correct gate

**Evidence:** `gate_expect`/`send_expect` use `timeout -k 10 30`;
`adversarial-run` uses `timeout -k 5 10`.

**Reproduction (`/tmp` copy):** detector sleeping 15s then returning the
correct verdict: 10s budget → rc=124 (TIMEOUT → adversarial mismatch,
red); 30s budget → rc=1 (correct block, green). Same gate, opposite
verdicts from the two suites. (Adversarial-run fails closed here, which
is safe, but the suites disagree and the audit would print CLEAN while
adversarial-run prints mismatches.)

**Recommendation:** unify the budgets (or document the intended split and
make `gate_expect` treat 10–30s latency as a finding so the suites cannot
diverge silently).

### P3-2 — rc=137 (and other signal deaths) produce misleading "tighten the pattern" diagnostics

**Evidence:** `gate_expect`, `send_expect`, `live_send_expect` check
`rc == 124` first, then fall into verdict comparison. A SIGKILLed gate
(rc=137, e.g. OOM) yields e.g. "want rc=1, got rc=137" with suggestion
*"block-tier payload passed the gate. Tighten SECRET_RE/BLOCK_RE …"* —
the payload did not pass; the gate was killed. `adversarial-run` lists
`got rc=137` as a mismatch (honest, but terse).

**Recommendation:** treat 137 (and 139/143) like 124: an operational
failure → `bad()` with "the gate was killed (rc=137); investigate the
installation" instead of a pattern-tightening suggestion. This is the
deferred "rc=137 handling" thread; it compounds P1-1's misdiagnosis
(the crash-fallthrough currently surfaces as "want rc=1, got rc=0" with
the same wrong suggestion).

### P3-3 — Yellow (🟡 "protected through approval") is documented in the legend but never emitted

**Evidence:** `bin/leakage-report` legend defines 🟡 = "protected through
approval — review-tier: refused without explicit approval (rc=2)".
`grep` finds 🟡 exactly once — in the legend. `callout()` never emits it;
`render_card()` has no yellow class. The suite-B tri-state groups *label*
rc=2 evidence "Approval-gated" in section headers, but no card ever
renders the legend's yellow.

**Recommendation:** either use yellow for approval-gated-dominant cards
or drop it from the legend. A legend entry with no referent trains
readers to ignore the legend — the deferred "yellow-semantics
consistency" thread.

### P3-4 — "Detection performance" mislabel persists on the F-card failure paths

**Evidence:** `callout()` for suite F: all-matched + stub → "🟣 Stub
consistency…" (fixed), but mismatches → "🔴 Detection performance: N of
M corpus cases mismatched" and runner-failed → "🔴 Detection performance:
adversarial runner failed" — **even when `stub` is true**. A stub
mismatch is harness self-inconsistency, not detector performance.

**Recommendation:** qualify all three F branches with the stub wording
("Stub consistency: … — harness self-check, not detector validation").

### P3-5 — `[B] [B]` / `[A] [A]` prefix duplication in report Findings titles

**Evidence:** `bad()` prefixes check names with `[$SUITE_LETTER]` in the
`@@@ CHECK FAIL` sentinel; the report's findings builder prefixes
`[{s['letter']}]` again.

**Reproduction (`/tmp` copy, one pattern broken to force failures):**
findings render as `[B] [B] gmail +reply ssn blocked`, `[A] [A] stub
blockset.txt is stale`. Deterministic. (Terminal output shows the prefix
once; only the report doubles it.)

**Recommendation:** strip the existing `^\[[A-Z]\] ` prefix when building
finding titles, or don't add it in `bad()`'s sentinel.

### P3-6 — Findings evidence truncated to `ev[0]` (first wrapped line)

**Evidence:** `bin/leakage-report`: `ev = scrub(c["ev"][0]) if c["ev"]
else ""` — and `ev_item` likewise renders only `c["ev"][0]`. Since
`wdetail` wraps at ~42 chars, a finding's evidence in the auto-expanded
Findings section is the first 42 characters of the detail; the operative
part (e.g. `got rc=0 invoked=1`, the third output line) is cut. Full text
survives only in the raw transcript.

**Recommendation:** include all evidence lines in the finding (they are
already wrapped short), or at least the first three — the deferred
"report tri-state fallback to `ev[0]`" thread.

### P3-7 — `test-matrix.md` "same six → brief-gate" is actually seven checks

**Evidence:** the audit runs seven fixtures through each gate
(clean, secret, secret2, ssn, card, figure, phone) → expected
0/1/1/1/1/2/2. The matrix says "same six → brief-gate | 1/1/1/2/2/0" —
wrong count and wrong code list (drops one block-tier). The deferred
"brief-gate doc count" thread.

**Recommendation:** "same seven → brief-gate | 0/1/1/1/1/2/2".

### P3-8 — No duplicate corpus-name detection (none today; silent misattribution if introduced)

**Evidence:** `awk … | sort | uniq -d` → 0 duplicates today, but nothing
enforces it. With duplicate names, `adversarial-run` counts both rows
while the report's per-case table does `next((m for m in mismatches if
m[0] == name), None)` — first-match attribution, silently wrong for the
second row.

**Recommendation:** audit or CI asserts corpus names are unique (one
`sort | uniq -d` check) — the deferred thread, cheap to close.

### P3-9 — Probe-first / membership-oracle surface: tier-distinguishing messages confirm blockset membership in words

**Evidence:** the stub's `memory-egress-check` prints on stdout
"BLOCK — N declared synthetic block-tier token(s) present" vs "REVIEW —
undeclared secret/figure/phone-shaped content; fail closed". Exit codes
1 vs 2 already distinguish tiers (inherent to the approval contract), but
the messages additionally *narrate* set membership. Anyone able to invoke
the gate locally can binary-search it: blockset member vs novel shape.

**Scope note:** the stub's corpus/blockset is public, so no
confidentiality is at stake *here*. The risk is the pattern being ported:
the real installation's denylist holds the user's real literals, and a
membership-confirming message turns the gate into a denylist oracle.

**Recommendation:** make gate/detector messages tier-uniform and
non-confirming ("refused", never "declared … present" / "undeclared").
Document the probe-first threat (iter-10 already plans oracle scenarios;
this is the mechanism).

### P3-10 — Slow/hanging/flaky fault variants: only the missing-blockset fault is probed

**Evidence:** suite A probes exactly one operational fault (missing
`blockset.txt` → `die()` → rc=1). Not probed: a *flaky* detector
(nondeterministic verdicts across runs — the audit runs each fixture
once, so flakiness is invisible), a detector that is slow-but-under-
budget on some inputs, or a gate whose verdict depends on
`$TMPDIR`/`mktemp` pressure. P3-1 covers the timeout half; flakiness has
no coverage.

**Recommendation:** run the block-tier gate checks twice and fail on
verdict disagreement (cheap flakiness tripwire), or document the gap in
suite E.

---

## P4

### P4-1 — Shim `mktemp` files (containing full gated bodies) are not trap-cleaned if the shim is SIGKILLed

**Evidence:** both stub shims (and the real ones) `mktemp` the gated
content and `rm -f` it after the gate returns. The audit wraps shims in
`timeout -k`, which SIGKILLs on hang — a killed shim leaks the tmpfile
(0600, but containing the secret, in `/tmp`) until reboot/tmpwatch.

**Recommendation:** `trap 'rm -f "$tmp" "$stdin_tmp"' EXIT` in the shims'
gating helpers.

### P4-2 — Messenger shim arg-parsing fidelity nits

**Evidence:** `test/stub-memory-skill/bin/shims/hatch_messenger_cli`:
`--text --cid 5` swallows `--cid` as a flag (text=""), and `--text
--text-stdin` drops the value — divergences from likely real-CLI parsing
of a `--text` value that looks like a flag. Low stakes (stdin form is
still gated), but the stub is the contract reference.

**Recommendation:** treat any token following `--text` as its value
unless it is a *known* flag of the send/edit subcommand; document the
chosen rule in the contract.

---

## Focus-area verification (deferred iter-7 threads, in my lens)

1. **Exact pass-total / adversarial-total assertions:** CONFIRMED GAP —
   see P2-2 (gutted corpus → full green).
2. **Duplicate corpus-name detection:** CONFIRMED ABSENT — see P3-8
   (0 dupes today, no enforcement).
3. **rc=137 handling:** CONFIRMED GAP — see P1-1 (crash → allow in the
   gates) and P3-2 (misleading diagnostics in the audit).
4. **Slow/hanging/flaky stub fault variants:** PARTIAL — timeouts are
   handled as findings (124), but only one fault variant is probed; see
   P3-1 (budget asymmetry) and P3-10 (flakiness).
5. **Timeout-budget asymmetry (30s vs 10s):** CONFIRMED — see P3-1.
6. **SHAPES manifest / fixture-purity cross-check:** CONFIRMED DRIFT —
   see P2-3.
7. **Near-miss/probe-first methodology:** corpus near-misses exist
   (`phone_bare10`, `shell_var`, `zip_code`, `order_num`, `date_iso`,
   `version`, `clean_price`); the probe-first oracle surface is see P3-9.
8. **Report tri-state fallback:** CONFIRMED HOLE — see P2-1 (badge CLEAN
   + red F card + exit 0 on unparseable adversarial output); `ev[0]`
   truncation see P3-6.
9. **Messenger stdin-echo hashing:** CONFIRMED — see P2-4 (payload bytes
   in failure evidence → transcript → HTML).
10. **HTML redaction beyond email addresses:** CONFIRMED INCOMPLETE —
    see P2-4 (`EMAIL_RE` + `$HOME` only).
11. **Yellow-semantics consistency:** CONFIRMED — see P3-3 (legend-only
    yellow) and P3-4 (stub mismatches labeled "Detection performance").

## Notes (non-findings)

- **Iter-7 fixes re-verified:** stdin-form raw MIME is gated with
  byte-identical replay; `--subject --draft` token-confusion is blocked;
  delegate resolution is canonicalized with self-identity refusal (both
  shims); `die()` → exit 1 and brief-gate usage error → exit 1;
  `interface_version` enforced as the first suite-A check with fail-fast
  on mismatch; `live_send_expect` wrapped in `timeout -k 10 30`; suite-A
  distinct-delegate assertion present; `build-blockset.sh --check` wired
  into suite A and CI.
- **Sentinel forgery re-probed:** still holds — `msent` strips newlines
  and rewrites `@@@`; corpus rows are line-based.
- **Real-installation observations** (P1-1 portability, P2-5, P2-6) are
  read-only findings for the parent to route: this repo cannot patch the
  `personal-memory-system` tree, but the iter-7 precedent (commit note)
  treats such true positives as reportable.
- **Out of scope, not probed:** live-fire paths (never armed, per brief),
  the real CLIs, `~/workspace/your_files/`, memory files, `local.env`.

## Method appendix

Probes (all on `/tmp` copies; repo tree unmodified):
- Differential shape probe: audit `SHAPES` vs stub `STUB_SECRET_CAND`
  over 28 synthetic tokens → 4 drifted shapes (P2-3).
- Crash probe: stub copy with `memory-egress-check` = `kill -9 $$` →
  `egress-gate` rc=0, `brief-gate` rc=0 on block-tier fixtures (P1-1).
- Tri-state probe: `adversarial-run` printing no sentinels, exit 0 →
  badge CLEAN + red F card + report exit 0 (P2-1).
- Evidence probe: detector neutered → secret passes → failure evidence
  contains the secret's first line (P2-4).
- Latency probe: 15s detector → 10s budget rc=124 vs 30s budget rc=1
  (P3-1).
- Gut probe: 1-case corpus + rebuilt blockset → audit CLEAN 66/0/2,
  adversarial 1/1 rc=0 (P2-2).
- Dup-prefix probe: broken SSN pattern → findings titled `[B] [B] …`,
  `[A] [A] …` (P3-5).
- Oracle probe: corpus member → rc=1 "declared synthetic block-tier
  token(s) present"; novel shape → rc=2 "undeclared …" (P3-9).
