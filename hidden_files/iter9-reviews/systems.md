# Systems review — muse-leakage-guard @ e35c1bc ("Iteration 8")

Persona: staff systems engineer — stdin/stdout/byte-replay correctness in
shims, interface_version contract enforcement, process exit propagation,
subprocess failure modes, IPC and file-descriptor handling, determinism
and race safety.

Scope reviewed: `bin/leakage-audit` (730 lines), `bin/leakage-report`
(822 lines), `bin/adversarial-run` (111 lines),
`bin/adversarial-corpus.txt`, `references/{attack-surface,gate-interface,test-matrix}.md`,
`test/stub-memory-skill/` (shims, gates, detector, patterns, blockset
builder), `.github/workflows/validate.yml`, plus the gates/shims under
test in `~/workspace/skills/personal-memory-system/bin/` (read-only;
reviewed as the system under test, not modified).

Method: full static read of every script above, then **execution probes**
against the real gates/shims with fake delegates (`MOCHI_REAL_*`
overrides) and scratch copies in `/tmp` — simulated only, nothing sent,
no repo files touched. Findings are tagged **[EXEC]** (confirmed by
running it) or **[STATIC]** (code/doc analysis).

Headline: the harness itself is carefully built (sentinel-based parsing,
fail-at-the-end CI, honest labeling). But it has a structural blind spot:
**the audit proves the stub fails closed, never the real gate** — and the
real `egress-gate` fails *open* on any unexpected detector exit code
([EXEC] F-01). Two more fail-open-class behaviors in the real shim were
confirmed by execution (F-02, F-03). These are the findings that matter.

Finding counts: P0 ×0, **P1 ×4**, P2 ×5, P3 ×16 (25 findings total).

---

## 1. Findings that make the validation untrustworthy or misleading

### F-01 [P1] Real `egress-gate` fails OPEN on unexpected detector exit codes; the audit only tests fail-closed against the stub — [EXEC]

**What:** `personal-memory-system/bin/egress-gate` lines 50–70:
```bash
detail="$("$SKILL_DIR/memory-egress-check" "$CONTENT" 2>&1)"; grc=$?
if [ "$grc" -eq 1 ]; then verdict="BLOCKED"; rc=1 ...
elif [ "$grc" -eq 2 ]; then ... rc=2 or approved→0
fi
printf '%s | %s | %s\n' "$ts" "$CONTEXT" "$verdict" >> "$LOG"   # verdict still "clean"
exit "$rc"   # rc=0 — ALLOW
```
Any detector exit code outside {1,2} — missing binary (bash yields 127),
crashing detector, `exit 3`, killed-by-signal (137) — falls through both
branches: verdict stays `"clean"`, the send is **allowed (rc=0)** and
**logged as `clean`**. Confirmed by execution three ways against a
scratch copy in /tmp (secret payload each time): missing
`memory-egress-check` → rc=0, log line `… | probe:fail-open | clean`;
crashing detector (exit 127) → rc=0/clean; detector exiting 3 → rc=0/clean.

**Why it matters:** This is the single enforcement point for the whole
protection layer, and it violates its own contract —
`references/gate-interface.md` ("Non-verdict errors … must fail closed —
surface as block (1) or another nonzero code, but NEVER as 0 (allow)").
Worse, the audit's suite-A "operational failure fails closed" check runs
**only against the synthetic stub** (`if [ "$STUBKIND" = "synthetic-stub" ]`),
so a green audit against the real installation never exercises the real
gate's error paths. The validation is blind exactly where the contract's
most important error-handling clause lives.

**Remediation:** (a) In the real `egress-gate`, add an explicit
fail-closed else-branch: any `grc` not in {0,1,2} → `verdict="refused: detector error"`, `rc=1`, log it loudly. (b) In `bin/leakage-audit`
suite A, add a real-target operational-failure test mirroring the
stub-only one: copy the target's `bin/` to a temp dir, remove/break
`memory-egress-check` in the copy, run the copy's `egress-gate` on a
secret fixture with approval set, expect rc≠0 (the copy pattern is
already used for the stub — no destructive test of the live install).

### F-02 [P1] Real gws shim degrades to gating base64 *ciphertext* when python3 is unavailable — send allowed — [EXEC]

**What:** `personal-memory-system/bin/shims/hatch_gws_cli` lines 125–144.
The raw-MIME decode is attempted via python3; on *any* failure
(including `python3` not existing at all) it falls back to
`printf '%s' "$payload" > "$tmp"` — gating the still-base64-encoded
payload as text. A card-shaped secret inside base64 matches no shape, the
gate logs `clean`, the shim delegates. Confirmed by execution with a
fake `python3` (exit 127) earlier on PATH: base64(`card 4111-…`) via
`--params` → rc=0, delegate invoked, log line `… | gmail users messages
send (raw) | clean`. The **stub** shim refuses outright when python3 is
missing (fail closed) — so the audit's stub runs never see this, and the
two shims disagree on a safety-critical branch.

**Why it matters:** Fail-open on a degraded dependency. python3 absence is
not exotic (minimal containers, broken PATH in a cron worker — the exact
A7 scenario). The stub models fail-closed; the real shim doesn't.

**Remediation:** Mirror the stub: if the MIME cannot be decoded, refuse
the send (rc=1) with "cannot decode raw MIME for egress review" instead
of gating the encoded bytes. Add a suite-B red-team case with a
python3-less PATH asserting refusal.

### F-03 [P1] `gmail users drafts send` is not intercepted — ungated send of previously-ungated draft content — [EXEC]

**What:** The real gws shim intercepts `+send|+reply|+forward` and
`users messages send`, but nothing under `users drafts …`. Confirmed by
execution: `gmail users drafts send --params '{"id":"abc"}'` → rc=0,
delegate invoked, no gate log entry. Attack-surface A5 claims drafts are
"PROTECTED (by non-action)" because "drafts never leave the account" —
but a draft saved ungated *by design* (`+send --draft` passes through,
suite B asserts this) can then be sent via `drafts.send`, which is not
gated. Two-step bypass: (1) `+send --draft --body <secret>` (ungated by
design), (2) `users drafts send` (unintercepted) → secret leaves.

**Why it matters:** Invalidates the A5 verdict for any CLI surface that
exposes `drafts.send` (the Gmail API does; `hatch_gws_cli` mirrors the
API — the shim intercepts `users messages send` for exactly this
reason). The audit has no test for it and the matrix's A5 row claims
coverage via the `--draft` pass-through test alone.

**Remediation:** Intercept `gmail users drafts send` in the shim: resolve
the draft id to its content (read-only `drafts.get`) and gate it, or —
simpler and safer — treat it as approval-gated (rc=2) since the content
was never gated at rest. Add suite-B cases: `drafts send` refused without
approval (rc=2), allowed with approval. Update A5's verdict/boundary in
the attack-surface catalog.

### F-04 [P1] Audit never tests the real gate's fail-closed behavior (coverage gap making F-01 invisible) — [STATIC]

**What:** Suite A's operational-failure test (broken stub: missing
`blockset.txt` + approval set → expect rc=1) is inside
`if [ "$STUBKIND" = "synthetic-stub" ]`, with the else branch merely
skipping ("stub-only"). There is no equivalent probe for real targets.

**Why it matters:** Category-1 issue: the validation suite structurally
cannot detect F-01/F-02-class regressions in the installation it claims
to validate. A green report against the real installation currently
*implies* fail-closed error handling that was never exercised.

**Remediation:** Same as F-01(b): non-destructive broken-copy probe for
real targets (temp copy of target `bin/`, detector removed, secret
fixture, approval set → expect rc∈{1,2}, never 0).

---

## 2. Bypasses / coverage gaps in the gates and shims under test

### F-05 [P2] Contract promises stdin for `egress-gate`; the real gate has no stdin path — [STATIC]

**What:** `references/gate-interface.md` line 52:
`` `--content-file <file>` or stdin: the payload to scan. ``
The real `egress-gate` (`personal-memory-system/bin/egress-gate`
line 44) requires `--content-file` to name an existing file and exits 2
otherwise — there is no stdin branch. (The stub gate *does* read stdin
when `--content-file` is absent.)

**Why it matters:** The audit validates against the contract; the
contract describes an interface the real gate doesn't implement. Any
caller written against the contract's stdin form fails with exit 2
("usage error") against the real gate — and exit 2 is the *review* tier,
which `MOCHI_EGRESS_APPROVED=1` can downgrade to allow. A usage error
masquerading as a verdict tier is a category error with approval
implications.

**Remediation:** Either implement the stdin branch in the real gate or
correct the contract to `--content-file` only. Add a contract-conformance
probe (stdin payload → expect the documented behavior).

### F-06 [P2] `+send --body @file` indirection is gated as the literal "@path" — [EXEC]

**What:** `hatch_gws_cli gmail +send --to … --body @/tmp/…/bodyfile.txt`
(where the file held a secret-shaped fixture) → rc=0, delegate invoked;
the gate judged the literal string "@/tmp/…". The shim resolves `@path`
for `--params` (raw path, lines ~118–122) but performs no `@file`
resolution for `+send`'s `--body`/`--subject`. Whether this is an actual
bypass depends on whether the real CLI honors `@file` for `--body` —
unverifiable from here — but the shim's *model* of the message ("@/tmp/…"
is the content) provably diverges from what a `@file`-capable CLI would
send.

**Why it matters:** Classic argument-indirection bypass shape; the audit
never tests it, and the contract is silent on `@`-files for the
`+send` family.

**Remediation:** Either verify against the real CLI that `@file` is not
supported for `--body`/`--subject`/`--to` (document the negative result
in the contract), or resolve `@path` in the shim before gating (same as
the existing `--params @path` handling), failing closed when the file is
unreadable.

### F-07 [P2] Stub gates fail open on unexpected detector codes, unlike the contract they model — [STATIC]

**What:** `test/stub-memory-skill/bin/egress-gate` line 33 and
`bin/brief-gate` line 25: only rc 1 and rc 2 are mapped; any other
detector code (e.g. 3) falls through to `exit 0`. The contract
(`gate-interface.md`, "Non-verdict errors") demands fail-closed for all
non-verdict codes.

**Why it matters:** The stub exists to let the harness validate itself
*against the contract*. A stub that doesn't implement the contract's
fail-closed clause means the harness's "self-consistency" never covers
that clause — and a future audit change that weakens real-gate
fail-closed handling would still be green against the stub.

**Remediation:** In both stub gates, map any detector rc ∉ {0,1,2} to
block (rc=1) with a "detector error" message, mirroring the contract.
Add a stub-only audit case: detector exiting 3 → expect rc=1.

### F-08 [P2] Real shim: drive match is anywhere-token, contract says positional — [EXEC]

**What:** Contract line 92: "`drive permissions create` (positional
subcommand)". The real shim (`hatch_gws_cli` lines 33–38) sets flags on
*any* argv token equal to `permissions`/`create`. Confirmed by execution:
`drive files create --name permissions` → refused rc=2 (fail-closed
false positive). The test matrix acknowledges the divergence
("the real shim is conservatively broader (fail-closed), which the
contract permits") — but the contract text itself permits no such thing.

**Why it matters:** Not a leak (fail-closed), but a
contract/implementation/audit three-way divergence the audit cannot see:
the audit only tests the positional form, so neither the over-broadness
nor a future narrowing is pinned.

**Remediation:** Amend the contract to bless fail-closed-broader matching
explicitly ("positional, or broader provided it is strictly more
refusing"), and add a real-target suite-B case asserting the documented
behavior for `drive files create --name permissions` (whichever way the
contract lands).

### F-09 [P3] Messenger `--text` is delivered to the delegate twice (argv + stdin) — [EXEC]

**What:** `personal-memory-system/bin/shims/hatch_messenger_cli`
line 51: `"$REAL" "$@" < "$tmp"` where `$tmp` contains the captured
stdin *plus* the `--text` value appended (`printf '\n%s\n' "$text"`).
Confirmed by execution: `send --cid 999 --text "hello world"` with empty
stdin → delegate received argv `--text "hello world"` **and** stdin
`\nhello world\n`. Whether the real CLI double-sends depends on the CLI,
but the shim provably delivers the message through two channels.

**Why it matters:** Fidelity bug in the interception layer: what the gate
judged (one message) is not what the delegate receives (two copies).
Worst realistic case is a duplicate send; still, byte-replay correctness
is this layer's core promise.

**Remediation:** When `--text` was used (no `--text-stdin`), don't
replay stdin — or strip the appended text and replay only the original
stdin bytes. Assert in suite B: delegate stdin must be byte-identical to
the *caller's* stdin for both `--text` and `--text-stdin` forms.

### F-10 [P3] `users messages list --q send` refused — anywhere-token match hits read-only paths — [EXEC]

**What:** The `users` branch triggers on any argv token equal to
`messages`+`send`. Confirmed: `gmail users messages list --q send`
(read-only!) → refused rc=1 "could not capture the message payload".
Fail-closed, but it's an availability false positive with a misleading
error (there is no payload to capture — it's a list call).

**Why it matters:** Same root cause as F-08: token-anywhere matching.
Trains users to distrust/reflexively work around refusals.

**Remediation:** Positional match for `users messages send` (like the
stub's drive handling), or at minimum exempt known read-only leaves
(`list`, `get`, `threads`) before payload capture.

### F-11 [P3] Real shim has no tmp-cleanup traps; temp files leak on signals — [STATIC]

**What:** `hatch_gws_cli` creates `$tmp`/`$stdin_tmp` and `rm -f`s them on
the normal path, but installs no `trap`. A SIGTERM/SIGINT to the shim
mid-gate leaves the gated content in /tmp (world-readable directory,
predictable `mktemp` names are at least random). The stub's
`memory-egress-check` uses `trap … EXIT`; the shims don't.

**Why it matters:** Gated content is by definition the sensitive stuff;
leaving it in /tmp after a killed run is a (small) disclosure surface.

**Remediation:** `trap 'rm -f "$tmp" "$stdin_tmp"' EXIT` (or INT TERM
EXIT) in both real shims.

---

## 3. Gaps in the audit and adversarial suite

### F-12 [P2] Gmail raw-stdin *allow* path replay is not byte-asserted — [STATIC + EXEC]

**What:** Suite B's stdin-replay integrity check covers only the
messenger `--text-stdin` allow path. For `gmail users messages send`
with `{"raw":…}` on stdin, the audit asserts rc/invoked only. The fake
`real-gws` never echoes stdin, so byte-identity of the replay is
unverified. I verified manually ([EXEC]) that the real shim replays
byte-identically (delegate received the exact 154 input bytes), but the
audit doesn't lock this in — a future shim change that truncates or
re-encodes stdin on the allow path would stay green.

**Remediation:** Extend the fake `real-gws` to delimit stdin like
`real-msg` does, and add the same byte-compare assertion for the raw
stdin allow case.

### F-13 [P3] `+forward` and messenger `edit` never carry a payload in tests — [STATIC]

**What:** The matrix claims "all send subcommands are covered, not just
`+send`" (test-matrix.md, section B) and "Messenger `send`/`edit`"
(gate-interface.md line 94). Suite B tests `+send` (secret/figure) and
`+reply` (ssn) with content, but `+forward` never gets a payload, and
messenger `edit` is never exercised with content — only `send`.

**Why it matters:** The shim's `case` handles them identically today, but
the claim "covered" is stronger than the evidence. A future shim edit
that special-cases `edit` would not be caught.

**Remediation:** Add `+forward` + secret and messenger `edit` + secret
cases to suite B (four lines).

### F-14 [P3] `adversarial-run` tests the detector, not the gate — comment claims otherwise — [STATIC]

**What:** `bin/adversarial-run` line 70: "Same invocation shape as the
audit's gate_expect (file argument, no pipe)". In fact `gate_expect`
invokes `bin/egress-gate`/`bin/brief-gate` (approval logic, logging,
fail-closed mapping) while `adversarial-run` invokes
`bin/memory-egress-check` directly (`GATE=…/memory-egress-check`).
Consequences: (a) the comment is inaccurate; (b) the approval-override
path (`--approved` / `MOCHI_EGRESS_APPROVED=1` turning rc=2 into 0, and
*never* rc=1 into 0) gets no adversarial coverage — only the two
targeted suite-B approval-isolation cases.

**Remediation:** Fix the comment, and add a small corpus-adjacent loop
(or suite-B cases) running review-tier corpus cases through
`egress-gate` with and without approval, asserting 2→0 and 1→1.

### F-15 [P3] `--approved` flag form is never tested — [STATIC]

**What:** The contract documents `--approved` as an alternative to
`MOCHI_EGRESS_APPROVED=1`. The shims translate env→flag, so the flag path
*is* exercised transitively, but no audit case invokes `egress-gate
--approved` directly. A regression that breaks the flag (but not the
env) would surface only as mysterious rc=2s.

**Remediation:** One-line additions: `egress-gate --approved` on
figure/phone fixtures → expect rc=0; on secret fixture → expect rc=1.

### F-16 [P3] Corpus `|`-splitting has no validation — [STATIC]

**What:** `adversarial-run` parses `IFS='|' read -r name want content`.
A future corpus case whose *content* contains a literal `|` would
silently truncate the content (and shift fields), likely producing a
confusing mismatch rather than a parse error.

**Remediation:** Split into at most 3 fields is already the behavior of
`read` (last var gets the rest) — actually `read` assigns the remainder
to the last variable, so content *can* contain `|`. Not a bug. Downgrade
to a doc nit: the corpus header should document that `|` is legal in
content (it is, by `read` semantics). Keeping as P3 doc note.

### F-17 [P3] Real-gate `--action` values other than `brief` are unvalidated — [STATIC]

**What:** `egress-gate --action <word>` accepts any word; only `brief`
changes messaging. Fine, but the audit never passes `--action` at all —
the `brief-gate → egress-gate --action brief` composition is exercised
only via `brief-gate` tests. No finding beyond noting the composition is
covered transitively.

---

## 4. Report accuracy / honesty and design

Iteration 8's theme was report integrity; I verified the headline claims
by execution. The report is in genuinely good shape:

- **Badge integrity [EXEC]:** `clean` requires audit CLEAN **and**
  `adv_rc == 0` **and** parseable figures; a green audit with a broken
  adversarial runner renders ATTENTION. Verified in code
  (`leakage-report`, `clean = …` computation + badge override) and by
  the green run (badge `ok`/`CLEAN`, exit 0).
- **Stub labeling [EXEC]:** title carries "(synthetic stub)", banner,
  hero, footer, purple F-card callout ("Stub consistency: 36/36 matched
  — harness self-check, not detector validation"), `STUBKIND` sentinel.
  All present in the generated HTML.
- **Card B tri-state [EXEC]:** rendered "16 blocked outright · 6
  protected through approval · 12 allowed normally · 1 other" — rc=2
  checks are not reported as plain green. ("1 other" is the stdin-replay
  fidelity check, which carries no rc — correct.)
- **Card D promise kept:** "Gate decisions" evidence section renders the
  blocked/override context lines, matching the card's blurb.
- **Statistical humility:** Clopper-Pearson lower bounds labeled "Worst
  case consistent with these results (95% lower bound)", corpus framed
  as author-designed regression fixtures, not recall/precision. The
  3×3 confusion matrix renders.

Nits (all P3):

- **F-18 [P3] CLEAN definition ignores skips.** The hero defines "CLEAN
  means every check passed — nothing that should have been stopped got
  through." A run with skips (e.g. memory-audit skipped, cron dirs
  unconfigured) still badges CLEAN. The skip-definition line exists
  below the legend, but the verdict definition should carry the caveat:
  "…every check *that ran* passed (N skipped — see below)."
- **F-19 [P3] `msent` forge-resistance comment overstates slightly.**
  `bin/leakage-audit`: "a hostile check name or wrapped CLI output can
  never forge them". True for CLI output (newlines stripped, `@@@`
  neutralized to `[at]` in `msent`). Check names, however, are
  audit-authored string literals — not attacker-controlled — so "hostile
  check name" is a hypothetical the design doesn't actually face. The
  mechanism is sound; the comment claims a threat model that doesn't
  exist. Harmless, but precision matters in a trust-establishing tool.
- **F-20 [P3] `--out` with a directory path.** `leakage-report --out
  somedir/` → `mkdir -p` the dirname, then writes `somedir/.tmp.<pid>`
  and `os.replace`s it onto `somedir/` → fails or misbehaves. Validate
  that `--out` doesn't resolve to an existing directory (exit 2).
- **F-21 [P3] Legacy parser is now nearly dead code** but still the
  fallback for "older audit output". Since the audit and report ship in
  the same repo/commit, the fallback's main consumer is hypothetical.
  Keep (defense in depth for CI log archaeology), but the fallback's
  `UNKNOWN`-mode default is the load-bearing honesty feature — it was
  verified present. No action; noted for the record.

---

## 5. Docs / CI / maintainability (systems perspective)

- **F-22 [P3] `ITERATIONS.md` is stale at HEAD.** The log has sections
  for iterations 1–6 (with 6 filed *before* 5, out of order), then
  "Backlog" — but HEAD is "Iteration 8" and `2243723` was "Iteration 7".
  Neither iteration 7 (contract conformance) nor 8 (report integrity)
  has a section. `CHANGELOG.md` *does* document 7 and 8. For a repo
  whose process is "10 reviews → synthesis → one focused diff → one
  commit", the iteration log is the process's own audit trail; letting
  it lag the code by two iterations undermines the "report tells the
  truth" theme. Remediation: add the two sections (the CHANGELOG text
  can be adapted).
- **F-23 [P3] CI workflow is solid; two nits.** (a) The pinned skip set
  (exactly 4, with reasons) is good, but it's pinned to *CI's*
  environment — the reasons are documented inline, fine. (b) The
  "Provision hermetic delegates" step appends a directory of binaries
  literally named `hatch_gws_cli`/`hatch_messenger_cli` to `GITHUB_PATH`
  for subsequent steps; they're inert (`exit 0`), and the audit needs a
  distinct delegate — sound. No change needed; recording that I reviewed
  it and it's fine.
- **F-24 [P3] `local.env` is sourced by both `leakage-audit` and
  `adversarial-run`, but only the audit snapshots/ignores
  `MOCHI_LIVE_FIRE` from it.** `adversarial-run` has no live-fire mode,
  so there's no live-fire risk there — but it *does* source local.env
  for `PERSONAL_MEMORY_SKILL`, meaning a stale local.env can silently
  redirect the adversarial run to a different target than the audit in
  the same invocation pair (report runs both). Remediation: `leakage-report`
  should export the resolved `PERSONAL_MEMORY_SKILL` (and warn if
  `adversarial-run` would resolve differently), or both should log the
  resolved target. Today the report prints only the audit's target.
- **F-25 [P3] No `CONTRIBUTING`-level note that the stub must track the
  contract.** The stub's purpose is contract conformance, but nothing
  mechanical ties stub changes to `references/gate-interface.md`
  updates beyond the `interface_version` string. The audit enforces the
  version *number*; semantic drift within version 1 (like F-07's
  fail-open fall-through) is invisible. Remediation: a short checklist
  in `test/stub-memory-skill/README.md`: "when the contract changes,
  update these N files" — or better, a suite-A check that greps the
  stub gates for the fail-closed else-branch pattern.

---

## What I verified as sound (no finding)

- **Exit propagation:** `gate_expect`/`send_expect`/`live_send_expect`
  all capture `$?` immediately after `timeout -k`; rc=124 (timeout) is
  handled as a finding, never mistaken for a verdict. `exec`-based
  `pass_through` preserves delegate exit codes.
- **Invocation sentinel design:** blocked-send assertions key off the
  fake binary touching `$T/invoked-any`, not stdout text — immune to a
  crashing binary echoing markers. Good.
- **Stdin replay on allow (real shim):** byte-identical for both the
  messenger path and the gmail raw-stdin path ([EXEC] — the latter
  verified manually even though the audit doesn't assert it; see F-12).
- **No TOCTOU between gate and delegate:** the gate judges the exact
  bytes/file the delegate receives (captured stdin_tmp / tmp file);
  argv is unchanged between gating and delegation.
- **Approval isolation:** block-tier stays rc=1 under
  `MOCHI_EGRESS_APPROVED=1` for both gmail and messenger ([EXEC] via the
  green suite-B run).
- **Self-delegate refusal:** canonical-path comparison (symlink-aware)
  in stub shims + audit assertion; the real skill's audit does the same
  via `canon_path`. No exec-loop path found.
- **Determinism/race safety:** per-run `mktemp -d`, sequential checks,
  atomic log appends (`printf >>` single write), atomic report write
  (`os.replace`), deterministic blockset build (sorted). No shared
  mutable state across runs.
- **Live-fire guards:** inline-only opt-in, local.env ignored with
  loud warning, TTY/`$CI` refusal, stale `MOCHI_REAL_*` unset,
  Gmail-identity verification before send, owner-only Messenger chat
  resolution failing closed, live-fire refused against stubs. All
  present as documented (static read; live-fire itself not executed —
  out of scope for this review).
- **Fixture purity + denylist scan:** green in the executed run; the
  SHAPES manifest aligns with the stub's candidate patterns.

## Suggested priority for the next iteration

1. F-01 + F-04 (real gate fail-closed + audit probe for it) — the one
   structural hole in "the validation proves the protection."
2. F-02 (python3-missing fail-open) and F-03 (`drafts.send`
   interception) — both fail-open-class, both in the real shim.
3. F-05/F-07/F-08 (contract vs implementation drift) — cheap doc/code
   alignment that removes ambiguity the audit can't see.
4. F-12/F-13/F-14 (audit coverage: replay assertion, +forward/edit,
   approval-path adversarial) — lock in what's already true.

---
*Review method: read-only. No repo files modified, no git operations, no
network sends, no live-fire. Execution probes ran against fake delegates
and /tmp scratch copies only. All fixture values referenced are the
repo's own synthetic fixtures.*
