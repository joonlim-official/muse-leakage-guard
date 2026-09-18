# Iteration-8 review — Senior privacy engineer

**Repo:** `~/workspace/skills/muse-leakage-guard`, HEAD `2243723` ("Iteration 7: contract conformance"), branch `main`.
**Mode:** review-only. Files read; scripts run in simulated mode only (`bin/leakage-audit` ran clean rc=0 against the real installation in SIMULATED mode during this review). No files modified, `MOCHI_LIVE_FIRE` never set, all payloads synthetic. Nothing written outside `/tmp` scratch and this review file.

**Lens:** fixture/corpus purity, SHAPES-vs-extractor coverage, HTML report redaction, `scrub()` behavior, data minimization in logs/artifacts, residual-gap documentation honesty.

**Fixture purity (spot-checked):** all fixtures and corpus values are synthetic and properly shaped — SSA-reserved `123-45-6789`, `4111…` test cards, `555-01XX` reserved phones, Stripe's published doc example keys shortened below scanner thresholds. No real names, addresses, emails, or identifiers anywhere in fixtures, corpus, docs, scripts, or the stub. Untracked `hidden_files/iter*-briefs/` contain no private identifiers (only the public org name `joonlim-official`). `local.env` and `hidden_files/reports/*` are gitignored — no committed config or report artifacts.

---

## P1 — memory-audit integration republishes the exact private literals it detects (new)

**Evidence:**
- `bin/leakage-audit` C-suite, with `MOCHI_MEMORY_AUDIT=1` and a failing memory-audit:
  `detail="$(printf '%s\n' "$audit_out" | grep -E '^  (/|!)' | head -12)"` →
  `bad "memory-audit reported findings (judge public vs private yourself)" "$detail" …`
- The memory skill's `bin/memory-audit` §8 ("public skill free of installation-sensitive literals") prints:
  `leak=$(grep -rF -f "$deny_tmp" "$SKILL_DIR" --exclude-dir=.git … | head -5)` then
  `printf '%s\n' "$leak" | sed 's/^/  /'` — i.e. **full matched lines containing the real denylisted literal**, each prefixed with two spaces + absolute path.
- Those lines match `^  (/|!)`, so they are embedded into `bad()` evidence → terminal stdout, HTML findings section, suite-C evidence card, raw transcript, and `@@@ CTX` machine sentinels.
- `flag()` lines (`"  ! $*"`) likewise embed real memory content: `malformed entry: <full trace line>`, `duplicated passage: <80 chars of memory content>…`, `expired … not retired: <100 chars of trace>`.
- Confirmed empirically with a synthetic mock through the exact extraction pipeline: all four line classes (trace excerpt, duplicated passage, denylist match line, financial-fact line) are captured.
- The report's `scrub()`/`scrub_transcript()` redact **emails only** — names, phone numbers, dollar figures, Rx/account numbers, and absolute home paths survive verbatim. Absolute home paths survive even in transcripts only partially (`~` shortening applies to transcripts, but evidence cards use `scrub()` which has no path handling).

**Why P1:** the failure mode that fires is precisely scenario B2 — denylisted (real private) literals found in a public repo, "this one has happened" per the catalog. At the moment the harness detects the worst-case privacy event, it republishes the real private literals into the report artifacts — the same artifacts designed to be screenshotted, saved (`reports/<date>.md`), and in CI uploaded as artifacts. Meanwhile the audit's *own* denylist check in the same suite (B2/B3) carefully echoes only repo + filenames, never literals — evidence hygiene is inconsistent within one suite.

**Recommendation:** reduce memory-audit evidence to counts and finding names (e.g. `memory-audit: N findings incl. installation-literal match in <file> — see the memory skill's own audit`), never matched lines; or run the memory-audit output through a SHAPES-based redactor (iter7 H1's recommendation, still open) before it enters evidence/transcript.

---

## P2 — HTML footer "nothing real was sent or disclosed" is false for real-target runs (new)

**Evidence:** `bin/leakage-report` footer for non-stub simulated runs:
`"Synthetic payloads only — nothing real was sent or disclosed."`
- Suite D tails the **real configured gate log** (`$REAL_LOG`) — `grep "| BLOCKED$" | tail -5` / `approved-override` — verbatim into the transcript. Log contexts are real send metadata: `gmail +send to <real address>`, `messenger send <real cid>`, real brief-context strings (subagent task names can carry names/plans).
- The memory-audit integration (P1) embeds real memory excerpts.
- The report *file* is itself a disclosure surface: saved to disk, emailable, screenshot-able. "Disclosed" is doing work the footer denies.

**Recommendation:** qualify the footer ("payload content is synthetic; the report may contain real send-context metadata from the gate audit log") — or better, stop embedding verbatim log tails and memory-audit excerpts (summarize: counts + salted hashes of contexts), which fixes P1's second half and this finding together. This is squarely iteration 8's report-honesty theme.

---

## P2 — fixture-purity SHAPES omits phone and figure classes; SYNTHETIC.txt's invariant already violated (new)

**Evidence:**
- `bin/fixtures/SYNTHETIC.txt` header: "every secret-shaped token in `bin/fixtures/`, `bin/adversarial-corpus.txt`, and `test/stub-memory-skill/bin/fixtures/` must be listed here, one per line."
- The purity `SHAPES` regex (`bin/leakage-audit`) has **no phone shape and no figure shape** at all.
- Empirically verified (stub `STUB_SECRET_CAND` vs audit `SHAPES` vs token list): these values are in fixtures/corpus but **undeclared** in `SYNTHETIC.txt` and invisible to the purity check — `415-555-0132` (`bin/fixtures/phone.txt`, `test/stub-memory-skill/bin/fixtures/phone.txt`), `(415) 555-0132`, `415.555.0132`, `+1-415-555-0132` (corpus), `$12,500` (`figure.txt`), `$5M`, `$275`, `$19.99`, `$999` (corpus).
- These are the personal-data classes (personal phone, financial figures) the skill exists to protect. A future fixture author adding a real-looking phone or amount gets no warning from the gate whose documented purpose is "catches any other undeclared secret-shaped value before it can ship in a public fixture."
- Current values are all `555`-reserved → no exposure today; the invariant is broken, not the data.

**Recommendation:** add the stub's `STUB_PHONE_CAND` / `STUB_FIGURE_CAND` equivalents to `SHAPES` (phone/figure values then get declared as synthetic in `SYNTHETIC.txt` like everything else), or explicitly document in the `SYNTHETIC.txt` header that phone/figure shapes are out of the purity invariant — but the latter would weaken a public-repo guard, so prefer the former. (Distinct from iter7 L1, which was the Amex-separator edge *within* secret shapes — that edge is also still open; see carryover.)

---

## P3 — plain-text audit stdout has zero redaction (new)

**Evidence:** `bin/leakage-report` applies `scrub()`/`scrub_transcript()` to HTML, but `bin/leakage-audit`'s own stdout — the channel `SKILL.md` tells users to persist via `bin/leakage-audit | tee reports/<date>.md` — is never scrubbed at all. It prints: the owner's full email in live-fire target lines (`wdetail "live-fire target: $LIVE_EMAIL (verified…)"`), real gate-log contexts (Suite D), memory-audit excerpts (P1), and `wdetail "LIVE-FIRE: unsetting stale $_rv (was: ${!_rv})"` echoing override path values.

**Recommendation:** apply at minimum the email scrub to stdout, or document that stdout is the unredacted channel and reports intended for sharing must come from `leakage-report`.

---

## P3 — no retention policy for local reports that may contain real metadata (new)

**Evidence:** `bin/leakage-report` defaults to `hidden_files/reports/leakage-validation-<timestamp>.html`, accumulating indefinitely (two already present). Any report generated against the real installation can embed real gate-log contexts (Suite D) and memory-audit excerpts (P1) in its transcripts. Gitignored, but a growing local archive of real-metadata-bearing reports with no documented rotation.

**Recommendation:** document retention (e.g. keep N latest, prune on run) or, preferably, fix P1/P2-1 so reports contain no real metadata by construction.

---

## Positive confirmations (verified, no finding)

- **Fixture/corpus purity:** all values synthetic, reserved ranges; denylist scan covers `git ls-files` of both repos; fixture-presence/non-empty fail-closed checks; `SYNTHETIC.txt` declaration flow sound for the shapes it covers.
- **Denylist scan evidence hygiene:** the audit's *own* B2/B3 check echoes only repo + filenames — the right pattern; P1 is about the delegated memory-audit path, not this one.
- **adversarial-run:** never echoes payload content (names + rc only); sentinels anchored on runner-printed prefixes; `@@@ ADV MISMATCH` lines carry no content.
- **F-card corpus table:** `leakage-report` reads the corpus file but renders only case names + want/got codes — no payload content in report tables.
- **Live-fire guards:** inline-only opt-in, TTY/CI refusal, stale `MOCHI_REAL_*` unset loudly, email-vs-Gmail-profile and Messenger self-chat verification, Drive shares stay simulated, refused against stub. Recipient-mismatch evidence redacts to domains only — good data minimization.
- **local.env:** live-fire can never arm from it (warned + ignored); gitignored; `.example` documents the contract honestly.
- **CI:** runs against the stub only, no secrets, live-fire refused, report uploaded as 14-day artifact — synthetic content only.
- **Messenger fixture CID `999`:** used only in simulated mode with fake binaries; consistent with the synthetic-fixture-never-real-target rule.
- **Residual documentation:** attack-surface.md's KNOWN-GAP definition, A7's corrected POLICY-ONLY verdict, README's de-collided T-ID residual list, and suite-E's nine residuals are honest and complete against the code. `msent` CTX lines can't forge `@@@` sentinels (`@@@`→`[at]` substitution).

---

## Carryover from iter7 (status at this HEAD — not new findings)

- **H1 (HIGH) — UNFIXED:** `scrub()`/`scrub_transcript()` still email-only; `send_expect`/`live_send_expect` failure evidence still `head -3` of captured output; the fake Messenger delegate still echoes stdin verbatim (needed by the byte-identical replay check, but the comment "failure evidence must not carry fixture content" remains false on the invoked path). Recommend the iter7 fix: hash stdin in the fake delegate and strip the stdin block from failure evidence.
- **L1 (LOW) — UNFIXED:** SHAPES still misses separator-form Amex (`3782-822463-10005`, `3782 822463 10005` → stub=1, purity=0, re-verified today). Now compounded by P2 above (whole phone/figure classes missing, not just an edge).
- **L2 (LOW) — UNFIXED:** Suite D still tails the real log under email-only scrub. My P2-1 is a distinct angle (footer honesty claim), not a re-report.
- **M1 (MEDIUM) — PARTIALLY ADDRESSED:** test-matrix C5 row now honestly discloses "(no injected-shaped payload exists in fixtures/corpus)" — the false "Covered by" claim is fixed. But the verdict stays "PROTECTED (in depth)" while "in depth" remains undefined in the verdict key and the key defines PROTECTED as "mechanically enforced; the action cannot complete" — still overstated for injection steered at unshimmed paths, which the same Details concede ("No single layer is the whole defense").
- **M2, M3, M4 — FIXED:** A7 is now POLICY-ONLY; KNOWN GAP is defined in the verdict key; README residuals use non-colliding T-IDs and list the full tracked set.

---

## Recommended iteration-9 privacy work, in order

1. P1: stop memory-audit output (matched lines, excerpts) from entering leakage-audit evidence/transcript — counts + names only.
2. H1 (carryover): SHAPES-based redaction across all report text (findings, evidence cards, transcripts) — closes P1's residual, L2, and the footer problem structurally.
3. P2-1/P3-2: qualify the footer and document report retention, or make reports metadata-free by construction.
4. P2: widen purity SHAPES to phone/figure classes and declare existing values in SYNTHETIC.txt.
5. M1 remainder: replace "PROTECTED (in depth)" with a defined verdict or downgrade to POLICY-ONLY.
