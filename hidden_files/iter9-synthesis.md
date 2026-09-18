# Iteration 9 synthesis — fail-closed + red-team coverage honesty
Date: 2026-09-17 PDT · HEAD `e35c1bc` · All 10 personas reviewed (4,215 review lines).

## Convergent finding (8 of 10 personas)
Leakage Guard at `e35c1bc` renders CLEAN while critical protection-layer
bypass paths exist and go undetected:
- **Ungated send paths**: `gmail +reply-all`, `gmail users drafts send`
  (pairs with ungated `--draft` into a complete two-step bypass),
  `users messages import`/`insert`, auto-forwarding/delegate/settings
  mutations, Messenger `--text-stdin`, `chat +send`, `calendar +insert`
  (security, airesearch, systems, PM; PM reproduced against stub + fake delegates).
- **Fail-open gates**: non-{0,1,2} detector exits (rc 3/126/127/137) fall
  through to allow (exit 0), violating `references/gate-interface.md`
  (security, airesearch, systems; PM reproduced).
- **`--` argument-parser bypass**: secret after `--` reaches the delegate
  ungated (SRE reproduced).
- **Undoctored honest-caveat gap**: suite D passes on an empty gate log;
  audit never probes `--dry-run`/`--json`/`+forward`/messenger `edit`;
  gate-decision logging is a contract requirement nothing verifies
  (PM, privacy, OSS).
- **Report-level**: gate log contexts republished verbatim (privacy P1-1
  on memory-audit evidence; P2-1 on suite-D contexts); corpus composition
  unpinned in CI (datasci, PM P1-3); `[B] [B]` dupe prefix, wrong
  timestamps on non-UTC machines (designer DG6, privacy P3-1, PM P3-3);
  stale `ITERATIONS.md`.

## Theme choice — iteration 9
**"Fail-closed gates + red-team coverage of critical send paths."**
One coherent improvement: every confirmed bypass/probe class gets
(1) a protection-layer fix where the real installation is responsible,
(2) a matching probe in Leakage Guard that would have caught it,
(3) contract/catalog language that tells the truth about the residual.
This directly serves the skill's stated purpose (prevent the
"unexamined path" failure mode) and responds to the strongest
convergent demand across personas.

## Conflict resolution
1. *Validation-only repo vs real protection fixes.* Adding probes for
   real bypasses will make real-target validation RED until the real
   gates/shims are fixed. Resolution: split the work like iteration 7 —
   patch `~/workspace/skills/personal-memory-system` first (existing
   identity, targeted probes, full validation, its own commit+push),
   then add the matching probes here. Never commit red in either repo.
2. *Green CLEAN vs honest red.* "Never commit red" does not mean "never
   go red" — it means the commit must be green after the fix. Temporary
   red probes between the two commits are the honest signal, not a
   violation. The sequence is enforced: protection patch first, then
   probe commit.
3. *Scope creep (chat/calendar/settings enumeration).* Acknowledge the
   gap honestly in the catalog/Known gaps; add probes only for the
   confirmed-critical set (`+reply-all`, `drafts send`, `import`/`insert`,
   fail-closed gates, `--` parser bypass, messenger `--text` shapes).
   Broader enumeration → iteration 10 backlog.
4. *Validator republishes real data (privacy P1-1/P2-1).* Fix inside the
   same theme: the validator must not amplify what it detects. Suite C
   prints counts, not verbatim memory-audit lines; suite D strips
   contexts to channel + verdict. This is validation honesty, in theme.

## Implementation plan (one commit here, plus one protection commit there)
### In personal-memory-system (real protection)
1. `bin/egress-gate`, `bin/brief-gate`: any detector rc ∉ {0,1,2} → exit 1
   (fail closed). Log it. Same for stub gates.
2. `shims/hatch_gws_cli`: intercept `+reply-all`, `users drafts send`,
   `users messages import`, `users messages insert`, `users settings`
   mutation paths; route through egress-gate. Fix `--` parser: gate what
   the real CLI will actually interpret, not what the shim pattern-matches.
3. Raw-MIME path: if `python3` is unavailable (or the JSON parse fails),
   refuse rather than gating opaque bytes.
4. Validate with targeted fake-delegate probes; audit + adversarial; commit
   with the repo's existing identity; push (standing auto-evolution authority).

### In muse-leakage-guard (this repo)
1. `references/gate-interface.md`: pin "undecodable raw → refuse";
   extend interception contract to the newly gated paths.
2. `bin/leakage-audit`: add suite-B probes (reply-all, drafts send,
   import/insert, `--` bypass shape, messenger edit, `+forward`); add
   fail-closed probes for detector rc 3/137 (in /tmp copies, never the
   real files); assert gate-decision log grows after blocked sends; make
   suite-D "gate log reviewed" warn (not ✓) on empty logs.
3. `bin/leakage-report`: scrub contexts to channel+verdict; suite-C
   evidence prints counts not verbatim lines; dedupe `[B] [B]` prefixes;
   fix timestamp on non-UTC machines (omit UTC parenthetical when equal).
4. `.github/workflows/validate.yml`: pin `@@@ TOTAL` and `@@@ ADV MATCHED`
   totals alongside the skip set; add CI-safe assertions for live-fire
   guards (exit 2 on stub/non-TTY/local.env) — no sends possible.
5. `ITERATIONS.md`: add entries 7 and 8, fix 5/6 ordering.
6. `references/attack-surface.md` + README + suite E: converge the
   residual enumeration; note remaining honest residuals (chat/calendar/
   settings enumeration, chunked/compositional, attachments, out-of-band).

## Backlog for iteration 10 (not in theme)
- Broader chat/calendar/settings-plane interception coverage
- Evasion corpus depth (whitespace/case/punctuation/multi-tier variants)
- `memory-guard` write-time probe (P1-2 privacy) + allowlist exercise
- B2/B3 git-history scan; live-fire guard CI steps beyond exit-2
- SECURITY.md, issue/PR templates, CONTRIBUTING canonical quickstart,
  exit-code reference, TOC, fixture-recipient ground rules
- Report print stylesheet, findings-focus movement, noscript chevron,
  timestamp `fmt_ts` dedup (designer DG6), residual subtotal line,
  legend collapse on mobile, matrix off-diagonal tint, corpus/label
  philosophy, lowercase bound "illustrative" labeling
- Screen-reader pass, real-device iOS/Android check
- Old public-history private-data claim near `918e243` (verify, no rewrite)

## Validation bar (both repos)
- bash -n on all touched scripts
- Fake-delegate probes: blocked paths block; allowed paths pass
- Stub `bin/leakage-audit` CLEAN, `bin/adversarial-run` 36/36 (or updated totals)
- Real-target `bin/leakage-audit` CLEAN, `bin/adversarial-run` 36/36
- Generated HTML report QA (desktop + mobile local headless Chrome)
- One commit: "Iteration 9: fail-closed gates + critical send-path coverage"
- Do not push yet (iteration 10 still to run before final public-diff review)
