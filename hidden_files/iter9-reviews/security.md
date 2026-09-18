# Iteration-9 review — Senior security engineer

Target: `~/workspace/skills/muse-leakage-guard`, HEAD `e35c1bc` ("Iteration 8:
report integrity and readability"), branch `main` (not pushed).
Mode: REVIEW-ONLY. No writes to the repo tree (only this review file, the
assigned deliverable); no git operations beyond read-only `log`/`diff`/
`status`; no live-fire; no network sends. All probes ran against `/tmp`
copies or through the shims with fake `MOCHI_REAL_*` delegates and
synthetic payloads only (the same simulated harness the audit itself uses);
nothing was ever really sent. Shell contexts were set up with the shim
PATH export per the brief; no CLI was invoked by absolute path.

Method: full-repo read of `bin/leakage-audit`, `bin/adversarial-run`,
`bin/leakage-report`, `.github/workflows/validate.yml`, both stub shims,
both stub gates, `bin/patterns.sh`, `build/build-blockset.sh`,
`references/gate-interface.md`, `references/attack-surface.md`,
`references/test-matrix.md`, `bin/adversarial-corpus.txt`, `CHANGELOG.md`;
read-only inspection of the gates under test in
`~/workspace/skills/personal-memory-system/bin/` (the real installation the
skill validates); empirical routing probes through the real shims with
inert fake delegates; differential probes for shape-drift and report
honesty. Baseline at HEAD: audit vs stub = CLEAN (66 passed / 0 failed /
2 skipped); adversarial-run = 36/36 (block 19/19, review 9/9, clean 8/8).

Severity rubric: **P0** = confirmed bypass of the protection being
validated, or validation output that certifies a bypass as clean.
**P1** = high — uncatalogued exfil path, contract violation, or harness
blind spot with a short exploit chain. **P2** = medium — measurement-
integrity hole (green output that does not mean what it claims),
conditional bypass needing one more step, or parity gap between the test
double and the deployed shim. **P3** = low — diagnostic accuracy,
label honesty, doc errors. **P4** = cosmetic / test-double fidelity nits.

## Verdict summary

**29 findings: 3 P0, 4 P1, 11 P2, 9 P3, 2 P4.** 11 are confirmed by
execution (deterministic reproductions, transcripts in the method
appendix); the rest are confirmed by code inspection with exact line
references. Three of the P0s are new this iteration (two were conditional
in the iter-8 review and are now confirmed; one — `+reply-all` — is new).
The iter-8 P1 (gate crash fail-open) is carried over and now confirmed by
execution against the real gate as well.

The headline: **the validation suite is green over a protection layer
with at least three complete, confirmed send-path bypasses**
(`+reply-all`, `users drafts send`, `marketplace initiate`) **plus two
whole unshimmed services** (`chat +send`, `calendar +insert`) — and the
audit's red team never fires at any of them. A CLEAN badge today means
"the covered paths hold," not "sends are gated." Separately, the deployed
`egress-gate` still fails open (rc=0, logged "clean") when its detector
dies by signal or exits outside {0,1,2} — confirmed by execution, a direct
contract violation.

---

## P0 — confirmed by execution

### P0-1 — `gmail +reply-all` is a real send subcommand and is completely ungated

**What:** `hatch_gws_cli gmail +reply-all` exists ("Reply-all to a message
(handles threading automatically)") and the real shim's interception list
is `+send|+reply|+forward` — `+reply-all` falls straight through to the
delegate with no gate consultation.

**Where:** `~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli:54`
(`case "$sub" in +send|+reply|+forward)`); the stub mirrors it at
`test/stub-memory-skill/bin/shims/hatch_gws_cli` (`+send|+reply|+forward`
branch); contract `references/gate-interface.md` ("Gmail `+send`,
`+reply`, `+forward`") omits it; `bin/leakage-audit` suite B never tests
it; `references/attack-surface.md` has no scenario for it.

**Reproduction (simulated, fake delegate, synthetic payload):**
`hatch_gws_cli gmail +reply-all --message-id x --body "token
sk-testFakeKeyForRoutingProbeOnly12345 in body"` → **rc=0, delegate
invoked, no gate-log entry**. Control (`+send` with the same body) →
rc=1, delegate silent, gate log records BLOCKED. Deterministic.

**Why it matters:** reply-all is the highest-blast-radius email primitive
(every thread participant). Any agent or cron job that reaches for it —
or any prompt-injection that steers toward it — exfiltrates with zero
gating. The audit's "every send path" language (SKILL.md:36) and the
test-matrix claim "all send subcommands are covered, not just `+send`"
(test-matrix.md:45, README.md:47) are false.

**Remediation:** add `+reply-all` to the interception case in both shims
(real skill owns the fix; this repo owns the contract + audit), add it to
`gate-interface.md`'s interception list, add a red-team case
(`+reply-all` + secret → blocked, delegate silent; + figure → rc=2), and
add attack-surface scenario A1b/A9. Correct the "all send subcommands"
claims.

### P0-2 — `gmail users drafts send` bypasses the gate; combined with A5 it is a full exfiltration chain

**What:** the real shim gates `users messages send` (anywhere-token match
on the literals `messages` + `send`) but `gmail users drafts send` —
" Sends the specified, existing draft to the recipients in the `To`,
`Cc`, and `Bcc` headers" — contains no `messages` token and passes
through ungated.

**Where:** `~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli:96-99`
(token match), `:159` (fall-through `pass_through`); stub shim mirrors the
same match shape; contract omits it; audit never tests it.

**Reproduction:** `hatch_gws_cli gmail users drafts send --params
'{"id":"r123"}'` → **rc=0, delegate invoked, no gate-log entry**.
Deterministic.

**Why it matters:** this closes a two-step chain the catalog itself
enables. A5 (`attack-surface.md`) deliberately leaves draft *creation*
ungated ("drafts never leave the account… gating would be pure friction")
and the audit *pins* that behavior as a passing check (`+send --draft`
with secret → rc=0, invoked=1). `users drafts send` converts that
ungated draft into an ungated send. The chain is: compose secret-bearing
draft via `+send --draft` or `users drafts create` (both ungated, the
first explicitly blessed by a green audit check) → `users drafts send`
(ungated) → secret leaves. Neither step touches the gate. This upgrades
the iter-8 P2-6 (conditional on the CLI exposing it) to confirmed.

**Remediation:** intercept `users drafts send` in both shims. Note that
interception alone is insufficient — the params carry only a draft ID, not
content — so the shim must resolve the draft body (via a read call such
as `users drafts get`, itself ungated) and gate the resolved MIME, or
`drafts send` must require explicit approval (rc=2), or draft creation
must be re-gated (revisit A5's rationale, which is now false). Add the
red-team case, the contract row, and an attack-surface scenario (A10:
draft-send). Until fixed, the A5 "PROTECTED (by non-action)" verdict and
the audit's `--draft` pass-through check are actively misleading: amend
both to name this chain.

### P0-3 — Deployed `egress-gate` fails OPEN (rc=0, logged "clean") when the detector exits outside {0,1,2}

**What:** the real `egress-gate` initializes `verdict="clean"; rc=0` and
only overrides on `grc==1` / `grc==2`. Any other detector exit — 3,
126/127 (missing/not-executable), 137 (SIGKILL/OOM), 139 (SIGSEGV), 143
(SIGTERM) — keeps `verdict=clean, rc=0`, **writes "clean" to the real
audit log**, and exits 0. The shim proceeds on rc==0, so the send goes
through.

**Where:** `~/workspace/skills/personal-memory-system/bin/egress-gate:49-73`
(`verdict="clean"; rc=0` at :49; `if [ "$grc" -eq 1 ]` at :52; `elif [
"$grc" -eq 2 ]` at :59; `exit "$rc"` at :73). The contract
(`references/gate-interface.md`, "Exit codes") requires: "Non-verdict
errors … must fail closed — surface as block (1) or another nonzero
code, but NEVER as 0 (allow) and NEVER as 2 (review)". The stub gates
have the identical fallthrough (`test/stub-memory-skill/bin/egress-gate:25-33`,
`bin/brief-gate:20-25`) and still claim `interface_version=1`.

**Reproduction (simulated, `/tmp` copy of the real gate + stub detector,
synthetic content):** detector `exit 3` → gate **rc=0**, log line
`… | probe:detector-crash | clean`. Detector `kill -9 $$` (rc=137) →
gate **rc=0**, logged clean. Deterministic. (Iter-8 reported this by
inspection for the real gate; this is the execution confirmation.)

**Why it matters:** the single most dangerous shape in a gate: a crashed
detector is indistinguishable from a clean verdict — worse, it is
*logged* as clean, so suite D's log review actively vouches for it. OOM,
a segfault, a missing interpreter after an OS update, or a deliberate
`kill` by a compromised worker all convert to allow. The audit's suite-A
"operational failure fails closed" test only exercises the *handled*
`die()`→exit-1 path (missing blockset) and only against the stub — the
crash shape is green in CI today.

**Remediation:** replace the fallthrough with an explicit case in all
four gates (stub egress/brief + real egress/brief): 0→allow, 1→block,
2→review-or-allow, `*`→fail closed as block (rc=1) with a distinct stderr
message and a distinct log verdict (e.g. `detector-error`, never
`clean`). Add an audit probe: detector replaced by `exit 3` and by
`kill -9 $$`, gate called **with `MOCHI_EGRESS_APPROVED=1`** on a
block-tier fixture, assert rc=1 both times (the approval dimension
matters: a crash must not be approvable, per the contract's "NEVER as 2"
rule). The real-skill fix is out of this repo's diff scope — route it —
but this repo must add the probe so a regression is red, not silent.

---

## P1

### P1-1 — Messenger `marketplace initiate --text-stdin` is an ungated send to an external counterparty

**What:** `hatch_messenger_cli marketplace initiate --listing-id <id>
--text-stdin` sends an initial message to a marketplace listing
counterparty. The messenger shim only gates the `send|edit` subcommands;
`marketplace` falls through to the delegate.

**Where:** `~/workspace/skills/personal-memory-system/bin/shims/hatch_messenger_cli:29`
(`case "${1:-}" in send|edit)`); stub shim mirrors it.

**Reproduction:** `printf '<synthetic secret>' | hatch_messenger_cli
marketplace initiate --listing-id 123 --text-stdin` → **rc=0, delegate
invoked**. Control (`send --cid 999 --text-stdin` with the same secret) →
rc=1, delegate silent. Deterministic.

**Why it matters:** marketplace counterparties are strangers by
definition — the highest-risk recipient class. The `--text-stdin` flag
exists precisely to carry message bodies, and the shim ignores the whole
subcommand. Not in the contract, not in the audit, not in the catalog.

**Remediation:** gate `marketplace initiate`'s message (`--text` /
`--text-stdin`) through `egress-gate` in both shims, mirroring the
`send`/`edit` handling; add contract row, red-team case (secret →
blocked; clean → allowed with byte-identical stdin replay), and scenario
A6b.

### P1-2 — Whole unshimmed services: `chat +send` and `calendar +insert` pass through with zero gating

**What:** the vendored `gws` binary exposes many services (`drive`,
`sheets`, `gmail`, `calendar`, `chat`, `docs`, …). The shim intercepts
only `$1 == gmail` and `$1 == drive`; everything else hits
`pass_through "$@"` at line 164. `chat +send` ("Send a message to a
space") and `calendar +insert` ("create a new event", with
title/description/attendees) are content-bearing outbound primitives.

**Where:** `~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli:44-47`
(drive), `:50` (gmail), `:164` (fall-through).

**Reproduction:** `hatch_gws_cli chat +send --space x --text
"<synthetic secret>"` → **delegate invoked, ungated**;
`hatch_gws_cli calendar +insert --title t --description "<synthetic
secret>"` → **delegate invoked, ungated**. Deterministic (code path is
unconditional; probes confirm).

**Why it matters:** Chat spaces routinely include people outside the
user's surfaces, and calendar invites push content to arbitrary
attendees — both are first-class exfil channels. The attack-surface
catalog has no Chat or Calendar scenario at all, so the suite-C coverage
map — which only checks that *listed* scenarios appear in the matrix —
cannot catch their absence. "A path with no scenario is an unexamined
path" is this skill's own stated failure mode.

**Remediation:** enumerate the `gws` service surface and, for each
content-bearing write primitive (`chat +send`, `chat spaces messages
create`, `calendar +insert` / `events insert|patch|update`, drive already
covered, …), either gate it or add a catalog scenario with an explicit
verdict. Add red-team cases for the gated ones. At minimum, add scenarios
A11 (Chat) and A12 (Calendar) with honest verdicts and audit checks that
fail if a *new* `+send`-like helper appears unlisted (e.g. a check that
dumps `hatch_gws_cli <svc> --help` subcommands and diffs against the
contract's interception list — a tripwire for CLI surface drift).

### P1-3 — Settings-plane exfiltration primitives are ungated and uncatalogued

**What:** `gmail users settings updateAutoForwarding` (forwards *all
future mail* to a forwarding address), `users settings delegates`
(grants another account direct mailbox access), and `users settings
filters create` (filter-based forwarding / auto-label exfil) are settings
writes that the shim passes through. None carry private content in the
command itself, so content-gating is the wrong tool — but they are
classic, high-leverage exfiltration primitives, and the catalog, contract,
and audit are silent about them.

**Where:** same fall-through as P1-2 (`hatch_gws_cli:164`); `users
settings` subcommands confirmed present via read-only `--help`
(`getAutoForwarding`, `updateAutoForwarding`, `delegates`,
`filters`, `forwardingAddresses`, `sendAs`, …).

**Why it matters:** a single `delegates create` or `updateAutoForwarding`
bypasses every content gate permanently for all future mail. A rogue or
injected agent needs no secret in hand — just one settings call. The
threat model in `attack-surface.md` enumerates content paths only; the
settings plane is a whole unexamined category.

**Remediation:** add catalog scenarios (B5: auto-forwarding/delegation —
verdict should be APPROVAL-GATED at minimum, ideally blocked without
explicit approval since these are never routine), intercept the
`updateAutoForwarding` / `delegates create|update` / `filters create`
mutating subcommands in the shim (refuse rc=2 without approval, mirroring
`drive permissions create`), and add red-team cases. Read-only `get*`
subcommands stay pass-through.

### P1-4 — Stub gates still fail open on detector crash (iter-8 P1-1, unfixed at HEAD)

**What/where:** `test/stub-memory-skill/bin/egress-gate:25-33` and
`test/stub-memory-skill/bin/brief-gate:20-25` — `RC=1`→block,
`RC=2 && !APPROVED`→review, otherwise fall through to `exit 0`. Any
detector exit outside {0,1,2} becomes allow. The stub declares
`interface_version=1` while violating the contract's explicit fail-closed
rule (gate-interface.md, "Exit codes").

**Why it matters (for this repo):** the stub is the contract reference
implementation that CI validates the harness against. A reference double
that violates its own contract teaches the wrong shape to every future
implementer and lets the harness's "operational failure fails closed"
story stay green while the crash shape is open. Iter-8 recommended the
explicit-case fix plus an approval-dimensioned crash probe; neither
landed in iteration 8 (the diff touched only the report, the adversarial
runner's timeout accounting, and docs).

**Remediation:** same as P0-3's stub half, in this repo's diff scope:
explicit `case` on the detector rc in both stub gates; suite-A crash
probes (`exit 3` and `kill -9 $$`, each with and without
`MOCHI_EGRESS_APPROVED=1`, asserting rc=1 on a block-tier fixture).

---

## P2

### P2-1 — Catalog incompleteness: the suite-C coverage map cannot catch missing scenarios

**What:** suite C's scenario-coverage check (`bin/leakage-audit`,
"F. scenario coverage map") verifies that every `### XN.` scenario in
`attack-surface.md` has a row in `test-matrix.md`. It cannot detect
scenarios that were never written. P0-1, P0-2, P1-1, P1-2, and P1-3 are
all missing from the catalog — five unexamined paths, zero findings.

**Where:** `bin/leakage-audit` ("F. scenario coverage map" block);
`references/attack-surface.md` (no A-scenario for `+reply-all`,
`drafts send`, `marketplace initiate`, Chat, Calendar, or settings-plane
writes).

**Why it matters:** the catalog's own discipline section says "A path
with no scenario is an unexamined path — that is the failure mode this
skill exists to prevent." The check as built defends the map's
*internal* consistency, not its *completeness*. An attacker only needs one
unlisted path.

**Remediation:** add the missing scenarios (A9 `+reply-all`, A10
`drafts send`, A6b `marketplace initiate`, A11 Chat, A12 Calendar, B5
settings-plane) with honest verdicts, and add a CLI-surface tripwire
(P1-2's remediation): enumerate the vendored CLI's send-like subcommands
and fail the audit if any is neither intercepted nor catalogued. That
converts "completeness" from a human discipline into a mechanical check.

### P2-2 — Contract (gate-interface.md) omits the bypassed paths, so the audit validates against an incomplete contract

**What:** the interception contract lists Gmail `+send`/`+reply`/
`+forward`, raw `users messages send`, `drive permissions create`, and
Messenger `send`/`edit`. It omits `+reply-all`, `users drafts send`,
`marketplace initiate`, `chat +send`, `calendar +insert`, and the
settings-plane mutators. The audit is "contract-shaped" — it can only
prove what the contract names.

**Where:** `references/gate-interface.md` ("Shim interception contract").

**Why it matters:** contract version 1 is enforced as the first suite-A
check with fail-fast on skew — good machinery aimed at an incomplete
spec. Green means "honors contract v1," and v1 does not cover the bypass
paths, so the version enforcement gives false confidence about exactly
the paths that are open.

**Remediation:** extend the contract to v2 (or amend v1 with the new
rows): every send-like primitive and every settings-plane mutator gets
an explicit row — intercepted-with-verdict or explicitly residual with
rationale. Bump `AUDIT_INTERFACE_VERSION` handling accordingly.

### P2-3 — The audit never verifies that gate decisions are actually logged (contract requires it; the stub doesn't log at all)

**What:** `gate-interface.md` requires `egress-gate` to log every
decision to `$MOCHI_EGRESS_LOG`. The stub's `egress-gate` never writes to
the log at all — a contract violation the audit never checks (suite D
only *reviews* a log if one exists; in simulated mode the audit points
`MOCHI_EGRESS_LOG` at a temp file and never asserts a line appeared).

**Where:** `test/stub-memory-skill/bin/egress-gate` (no `MOCHI_EGRESS_LOG`
reference); `bin/leakage-audit` suite B (no log assertion after any
gated send).

**Why it matters:** the audit log is the accountability half of the
system — suite D's "verdict distribution proves the gate is actually
being exercised" and the approved-override surfacing both assume logging
works. A gate that stops logging (disk full, bad path, regression)
silently blinds the human auditor while every other check stays green.
P0-3 showed a crash is *logged as clean*; this shows logging itself is
untested.

**Remediation:** after each suite-B gated send, assert the temp gate log
grew by exactly one line with the expected verdict token; fail the check
otherwise. Add stub `egress-gate` logging (or document the stub's
deviation in the contract). Consider a suite-D assertion that the newest
log line is newer than the audit start (staleness tripwire for real
installations).

### P2-4 — Real shim's undecodable-raw fallback gates encoded bytes as-is; the stub fails closed — untested parity gap

**What:** on a `users messages send` payload whose `raw` is not decodable,
the **stub** shim refuses outright (exit 1, fail closed). The **real**
shim falls back to gating the *encoded* payload text as-is — which matches
no plaintext pattern — and passes the send through if nothing matches.

**Where:** real shim `~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli`
(python fallback: `except Exception: sys.stdout.write(p)` — gates the
envelope, not the content); stub shim
`test/stub-memory-skill/bin/shims/hatch_gws_cli` ("refusing users
messages send (fail closed)"). Contract requires fail-closed on
undecodable payloads.

**Why it matters:** the harness validates a *stricter* shim than the one
deployed (same family as iter-8 P2-5). Practical exploitability is low —
the real Gmail API would likely 400 on undecodable base64 — but the
contract's fail-closed property is unproven on the deployed path, and the
audit has no case that distinguishes the two behaviors (it only tests
decodable card/clean). A future shim edit could widen this silently.

**Remediation:** align the real shim to fail closed on undecodable `raw`
(port the stub's refusal), or amend the contract to specify the
gate-encoded-bytes behavior with rationale; add a red-team case with a
corrupt-base64 `raw` asserting refusal (rc≠0) on both targets.

### P2-5 — No pinned pass/adversarial totals: a gutted corpus yields a fully green pipeline (iter-8 P2-2, still open)

**What:** the audit asserts only `corpus_cases >= 1`; CI pins the skip
set (exactly 4) but no pass total and no adversarial total. Iter-8
demonstrated end-to-end: a 1-case corpus + rebuilt blockset → audit CLEAN
66/0/2, adversarial 1/1, all CI components green.

**Where:** `bin/leakage-audit` ("adversarial corpus has $corpus_cases
cases"); `bin/adversarial-run` (no total assertion);
`.github/workflows/validate.yml` (no `@@@ ADV MATCHED` total pin).

**Why it matters:** coverage erosion is silent. A bad merge, a truncated
file, or a deliberate gutting of the corpus (36→1) is indistinguishable
from healthy in every artifact CI produces.

**Remediation:** pin the expected totals the way the skip set is pinned —
CI asserts `@@@ ADV MATCHED 36/36` exactly and the audit asserts the
corpus case count equals the committed count (or a checked-in manifest).
Any drift fails loudly.

### P2-6 — Report redaction is shape-incomplete: failure evidence can carry payload bytes into the persisted HTML (iter-8 P2-4, still open)

**What:** `scrub()` redacts only email addresses; `scrub_transcript()`
redacts emails + `$HOME`. Secret/phone/figure-shaped tokens are not
redacted. Iter-8 proved the trigger: neuter the detector so a secret
passes, and the secret's bytes land in failure evidence → transcript
`<pre>` → persisted HTML artifact (uploaded from CI, retention 14 days).

**Where:** `bin/leakage-report` (`scrub`, `scrub_transcript`); the
`send_expect` failure-evidence path in `bin/leakage-audit`.

**Why it matters:** suite-B fixtures are synthetic today, so no live
exposure — but the same transcript carries live-fire real-CLI output and
real gate-log lines (suite D), where email-only scrubbing is
insufficient. The artifact is the one place a failure's payload is
*published*.

**Remediation:** extend transcript scrubbing to the secret/phone/figure
shapes from a shared shape manifest (ties to P2-7), and hash stdin bytes
for the replay-integrity comparison/evidence instead of echoing them
(the deferred "messenger stdin-echo hashing" thread).

### P2-7 — Fixture-purity SHAPES and stub candidate patterns have drifted (iter-8 P2-3, still open)

**What:** the purity guarantee rests on two independently maintained
literals — `SHAPES=` in `bin/leakage-audit` and `STUB_SECRET_CAND=` in
`test/stub-memory-skill/bin/patterns.sh` — with only a prose claim of
superset alignment.

**Where:** `bin/leakage-audit` (SHAPES); `test/stub-memory-skill/bin/patterns.sh`.

**Reproduction (differential probe, synthetic tokens):**
`4111-111111111111` and `3782-822463-10005` (mixed-separator card/Amex
shapes) → detected by the stub extractor, invisible to the audit purity
check. A fixture containing such a shape passes purity with no
`SYNTHETIC.txt` declaration. (Iteration 8 widened SHAPES but the
separator-optional variants still diverge: audit requires a separator
between every 4-digit group; the stub's are optional.)

**Remediation:** single-source the shape list (one file both scripts read)
or add a CI step asserting the two literals agree over a shape exercise
set.

### P2-8 — Real shim `--draft` vs `--` end-of-options: conditional bypass (iter-8 P2-5, still open)

**What:** the real `+send` parser sets `is_draft=1` whenever
`--draft`/`--dry-run` appears with an empty `prev`, with no `prev_opt`
tracking; the stub shim tracks it. `hatch_gws_cli gmail +send --body
<secret> -- --draft`: if the underlying CLI honors `--` as end-of-options,
`--draft` is a positional there (not a draft flag) and the send is real
and ungated.

**Where:** `~/workspace/skills/personal-memory-system/bin/shims/hatch_gws_cli:61-70`
(no `prev_opt`); stub shim has the stricter tracking.

**Why it matters:** another instance of the harness validating a
stronger shim than deployed. One verification step (does the vendored
CLI honor `--`?) from P0.

**Remediation:** verify against the real CLI; if yes, port the stub's
`prev_opt` strictness (or explicitly reject `--` in send argv) to the
real shim and add the red-team case from iter-8's recommendation
(`+send -- --draft` with secret → must be blocked).

### P2-9 — "Every send path" / "all send subcommands" claims are false (doc honesty)

**What:** SKILL.md:36 ("synthetic payloads … are fired at every gate and
every send path"), README.md:30 ("synthetic payloads at every gate and
send path"), test-matrix.md:45 and README.md:47 ("all send subcommands
are covered, not just `+send`"). Given P0-1/P0-2/P1-1/P1-2, these are
overclaims.

**Why it matters:** the skill's value proposition is completeness
("enumerate every path private data could leave"). Overclaiming coverage
in the skill's own description is the exact failure the skill exists to
prevent in others.

**Remediation:** qualify the claims to the covered set
(`+send`/`+reply`/`+forward`, raw `messages send`, `drive permissions
create`, Messenger `send`/`edit`) until the gaps are closed; then
re-widen honestly.

### P2-10 — A5's rationale is falsified by the drafts-send bypass (catalog honesty)

**What:** A5 concludes "PROTECTED (by non-action) — drafts never leave
the account, which is a free-share zone, so gating would be pure
friction," and the audit pins `+send --draft` + secret → rc=0/invoked=1
as a *passing* check. P0-2 shows drafts do leave the account via
`users drafts send`, ungated.

**Why it matters:** a green check currently blesses the first half of an
exploit chain. The catalog verdict and the audit expectation must name
the chain until it is closed.

**Remediation:** amend A5 to APPROVAL-GATED-or-OPEN with the
drafts-send chain documented, or gate draft creation; change the audit's
`--draft` expectation to reference the residual.

### P2-11 — Suite B tests neither `+forward` nor Messenger `edit`, though the contract lists both

**What:** the contract's interception list includes `+forward` and
Messenger `edit`; the audit's red team covers `+send`, `+reply`, and
Messenger `send` only.

**Where:** `bin/leakage-audit` suite B (no `+forward`, no `edit` case).

**Why it matters:** contract coverage without test coverage is
declaration without verification — the same shape as the P0s, one
refactor away from a silent regression (e.g. a shim edit that drops
`+forward` from the case list would stay green).

**Remediation:** add both red-team cases (secret → blocked, delegate
silent).

---

## P3

### P3-1 — `[B] [B]` / `[A] [A]` prefix duplication in report Findings titles (iter-8 P3-5, still open)

**What:** `bad()` prefixes the `@@@ CHECK FAIL` sentinel with
`[$SUITE_LETTER]`; the report's findings builder prefixes
`[{s['letter']}]` again → findings render as `[B] [B] gmail +reply ssn
blocked`.

**Where:** `bin/leakage-audit` (`bad()`); `bin/leakage-report:387`.

**Remediation:** strip a leading `^\[[A-Z]\] ` when building finding
titles (or stop adding it in the sentinel).

### P3-2 — Yellow (🟡 "protected through approval") is legend-only, never emitted (iter-8 P3-3, still open)

**What:** the legend defines 🟡 but `callout()` never returns it and no
card class renders it; the only 🟡 occurrences are the legend itself and
the tri-state section header "Approval-gated evidence".

**Where:** `bin/leakage-report` (`callout()`, legend builder at :622).

**Remediation:** emit yellow for approval-gated-dominant cards or drop it
from the legend. (Iteration 8's tri-state work made this more visible, not
less — the legend now promises a treatment that still doesn't exist.)

### P3-3 — "Detection performance" label on stub F-card failure paths (iter-8 P3-4, still open)

**What:** on stub targets, the F-card mismatch and runner-failed callouts
still say "Detection performance: …" (`bin/leakage-report:298,305`);
only the all-matched path says "Stub consistency". A stub mismatch is
harness self-inconsistency, not detector performance.

**Remediation:** qualify all three F branches with the stub wording.

### P3-4 — test-matrix "same six → brief-gate | 1/1/1/2/2/0" is still wrong (iter-8 P3-7, still open)

**What:** the audit runs seven fixtures through each gate
(clean, secret, secret2, ssn, card, figure, phone) expecting
0/1/1/1/1/2/2. The matrix still says "same six" with codes 1/1/1/2/2/0 —
wrong count and wrong code list.

**Where:** `references/test-matrix.md:42`.

**Remediation:** "same seven → brief-gate | 0/1/1/1/1/2/2".

### P3-5 — No duplicate corpus-name enforcement (iter-8 P3-8, still open)

**What:** zero duplicate names today, but nothing enforces uniqueness;
with duplicates, `adversarial-run` counts both rows while the report's
per-case table attributes by first match — silently wrong for the second
row.

**Remediation:** one `sort | uniq -d` assertion in the audit or CI.

### P3-6 — Timeout-budget asymmetry: 30s (audit) vs 10s (adversarial-run) (iter-8 P3-1, still open)

**What:** a 15s-but-correct detector yields rc=124/TIMEOUT-mismatch in
`adversarial-run` and a correct verdict in the audit's `gate_expect` —
the two suites disagree about the same gate.

**Where:** `bin/leakage-audit` (`timeout -k 10 30`); `bin/adversarial-run`
(`timeout -k 5 10`).

**Remediation:** unify the budgets, or document the split and make the
audit treat 10–30s latency as a finding.

### P3-7 — Signal deaths (137/139/143) produce misleading "tighten the pattern" diagnostics (iter-8 P3-2, still open)

**What:** only rc=124 is treated as operational failure; a SIGKILLed gate
(rc=137) falls into verdict comparison → e.g. "want rc=1, got rc=137"
with suggestion "block-tier payload passed the gate. Tighten
SECRET_RE/BLOCK_RE …" — the payload did not pass; the gate was killed.
Compounds P0-3's misdiagnosis (crash currently surfaces as "want rc=1,
got rc=0" with the same wrong suggestion).

**Where:** `gate_expect`, `send_expect`, `live_send_expect` in
`bin/leakage-audit`; `bin/adversarial-run` (terse but honest).

**Remediation:** treat 137/139/143 like 124 — operational failure with
"the gate was killed; investigate the installation," never a
pattern-tightening suggestion.

### P3-8 — Probe-first / membership-oracle surface in stub messages (iter-8 P3-9, still open)

**What:** the stub detector narrates set membership on stdout ("BLOCK —
N declared synthetic block-tier token(s) present" vs "REVIEW —
undeclared …"). Exit codes already distinguish tiers (inherent to the
approval contract), but the messages confirm membership in words —
anyone who can invoke the gate locally can binary-search the blockset.

**Where:** `test/stub-memory-skill/bin/memory-egress-check`.

**Why it matters here:** the stub's set is public, so no confidentiality
is at stake in this repo — but the shape is the reference, and the real
installation's denylist holds real literals. A membership-confirming
message turns the gate into a denylist oracle.

**Remediation:** tier-uniform, non-confirming messages ("refused"); document
the probe-first threat for the planned iter-10 oracle scenarios.

### P3-9 — Real `memory-egress-check`: unreadable `--content-file` scans as empty → "clean"

**What:** `INPUT=$(cat -- "$@" 2>/dev/null)` — if the file exists but is
unreadable, `cat` fails silently and `INPUT` is empty → "clean", exit 0.
`egress-gate` checks existence (`-f`) but not readability.

**Where:** `~/workspace/skills/personal-memory-system/bin/memory-egress-check`
(INPUT capture); `bin/egress-gate` (`[ -f "$CONTENT" ]` check).

**Why it matters:** fail-open on unreadable input. In the shim flow the
tmpfile is shim-created (readable), so reachability is narrow — but the
contract's fail-closed rule covers "missing inputs," and this is one.

**Remediation:** in the detector, fail closed (exit 1) when a named input
file cannot be read; in the gates, check `-r` as well as `-f`.

---

## P4

### P4-1 — Shim `mktemp` files not trap-cleaned on SIGKILL (iter-8 P4-1, still open)

Both stub shims (and the real ones) `mktemp` the gated content and `rm
-f` it after the gate returns; a SIGKILLed shim (e.g. the audit's own
`timeout -k`) leaks the tmpfile — 0600, but containing the secret — until
reboot/tmpwatch. `trap 'rm -f "$tmp" "$stdin_tmp"' EXIT` in the gating
helpers.

### P4-2 — Messenger shim arg-parsing fidelity nits (iter-8 P4-2, still open)

`--text --cid 5` swallows `--cid` as the text value; `--text --text-stdin`
drops the value. Low stakes (stdin form is still gated), but the stub is
the contract reference — document the chosen `--text`-value rule in the
contract.

---

## Iter-8 carryover status

| Iter-8 finding | Status at e35c1bc |
|---|---|
| P1-1 gate crash fail-open | **Still open** — and now confirmed by execution against the real gate (P0-3); stub half unchanged (P1-4) |
| P2-1 badge CLEAN with red F card | **Fixed** — `clean` now requires `adv is not None`, and CLEAN demotes to ATTENTION on adversarial mismatch/None |
| P2-2 no pinned totals | Still open (P2-5) |
| P2-3 SHAPES drift | Still open — narrowed but not closed; differential probe still finds drift (P2-7) |
| P2-4 transcript redaction | Still open (P2-6) |
| P2-5 real shim `--draft` vs `--` | Still open — real shim unchanged (P2-8) |
| P2-6 `users drafts send` (conditional) | **Confirmed → P0-2** (CLI exposes it; shim doesn't intercept; probe shows ungated delegate invocation) |
| P3-1 timeout asymmetry | Still open (P3-6) |
| P3-2 rc=137 diagnostics | Still open (P3-7) |
| P3-3 yellow legend-only | Still open (P3-2) |
| P3-4 F-card "Detection performance" on stub | Still open (P3-3) |
| P3-5 `[B] [B]` dup prefix | Still open (P3-1) |
| P3-6 ev[0] truncation | **Fixed** — all evidence lines now joined into findings |
| P3-7 matrix "same six" | Still open (P3-4) |
| P3-8 duplicate corpus names | Still open (P3-5) |
| P3-9 oracle messages | Still open (P3-8) |
| P3-10 flakiness | Still open (not re-reported as its own item; partially covered by P3-6) |
| P4-1 mktemp trap | Still open (P4-1) |
| P4-2 messenger parsing nits | Still open (P4-2) |

Iteration 8's diff (report integrity + readability) fixed the two report-
honesty items it touched and did not regress anything I could find — but
it also did not touch the gates, shims, contract, catalog, or audit
probes, so every protection-layer finding carries over.

## Docs / CI / maintainability (persona notes)

1. **CI validates the wrong artifact for the P0s.** `validate.yml` is
   well-constructed (pinned actions, `pull_request` not
   `pull_request_target`, `contents: read`, shallow checkout, live-fire
   refusal, fail-at-the-end with sentinel-anchored figures, pinned skip
   set) — but it runs the audit against the stub, and the stub faithfully
   mirrors the real shim's gaps (`+reply-all`, `drafts send`,
   `marketplace initiate` all absent in both). CI green therefore
   certifies a harness that cannot see the bypasses. The stub's fidelity
   to the real shim's *omissions* is the blind spot: consider a
   "contract-vs-CLI-surface" CI job that diffs the vendored CLI's
   send-like subcommands against the contract's interception list (the
   P1-2 tripwire) — that job would have caught P0-1/P1-1/P1-2 at the
   surface, without needing the real installation.
2. **The stub is a reference implementation with contract violations.**
   It declares `interface_version=1` while its gates fail open on crash
   (P1-4) and its `egress-gate` doesn't log (P2-3). Every deviation
   between the double and the contract should be either fixed or listed
   as an explicit, versioned deviation — otherwise the double teaches the
   wrong contract.
3. **`local.env` handling is sound** (gitignored, CI refuses a committed
   copy, live-fire requires inline per-invocation opt-in, stale
   `MOCHI_REAL_*` unset loudly in live-fire). The one gap: CI's refuse
   step doesn't cover `MOCHI_REAL_*` overrides — a PR-modified workflow
   could point the shims at an attacker-controlled "delegate." Low risk
   (no secrets in CI), but cheap to add to the refuse list.
4. **Attack-surface catalog maintenance has no owner or cadence.**
   The discipline section describes the process for adding scenarios but
   nothing ensures the CLI surface is re-enumerated when the vendored
   `gws` binary gains subcommands (as it evidently did — `+reply-all`,
   `marketplace initiate`, chat/calendar helpers). Recommend: a
   `references/cli-surface.md` snapshot regenerated by CI, diffed
   against the contract.
5. **Report honesty is now strong** (sentinel-anchored parsing, no
   hardcoded numbers, ATTENTION demotion, stub banner/title/footer,
   Clopper-Pearson lower bounds with plain-language framing, red cards
   pre-expanded). Remaining honesty debts are P3-1 through P3-4 and
   P2-6 — all label/plumbing, none structural.
6. **The `.egress-allowlist` exemption path is review-tier-only by
   design** (documented in E1/E3) — good. But note the audit has no
   negative test asserting a block-tier-shaped allowlist entry does
   *not* downgrade (the contract says the allowlist "NEVER weakens the
   BLOCK tier"). A regression that applied the allowlist to block-tier
   patterns would be silent. Cheap red-team addition: temporarily append
   a block-tier token to a temp allowlist and assert rc stays 1.

## Notes (non-findings)

- Re-verified as still fixed since iter-8: stdin-form raw MIME gating
  with byte-identical replay; `--subject --draft` token-confusion
  blocked; canonical delegate resolution + self-identity refusal;
  `die()`→exit 1; `interface_version` enforcement with fail-fast;
  live-fire timeouts; approval isolation (block-tier stays rc=1 under
  `MOCHI_EGRESS_APPROVED=1` — confirmed in this run's audit output);
  sentinel forgery resistance (`msent` strips newlines, rewrites `@@@`).
- The iter-8 "Detection performance" mislabel fix holds only on the
  all-matched path (P3-3) — the partial fix is now precisely scoped.
- Real-installation findings (P0-1, P0-2, P0-3, P1-1, P1-2, P1-3, P2-4,
  P2-8, P3-9) are read-only observations for the parent to route to the
  `personal-memory-system` skill: this repo cannot patch that tree, but
  the audit/contract/catalog/probe halves of each are in this repo's
  diff scope.
- Out of scope, not probed: live-fire paths (never armed), the real
  CLIs' network behavior, memory files, `local.env` contents.

## Method appendix — probe transcripts

All probes: simulated mode, fake inert delegates via `MOCHI_REAL_*`,
synthetic payloads only (`sk-testFakeKeyForRoutingProbeOnly12345`,
`123-45-6789`-class shapes), `/tmp` scratch, repo tree unmodified.
Gate-log assertions below refer to the temp `MOCHI_EGRESS_LOG`.

- **P0-1:** `hatch_gws_cli gmail +reply-all --message-id x --body
  "token sk-testFakeKeyForRoutingProbeOnly12345 in body"` → rc=0,
  delegate invoked, no gate-log line. Control `gmail +send` same body →
  rc=1, delegate silent, log `… | gmail +send to a@example.com | BLOCKED`.
- **P0-2:** `hatch_gws_cli gmail users drafts send --params
  '{"id":"r123"}'` → rc=0, delegate invoked, no gate-log line.
- **P1-1:** `printf '<synthetic secret>' | hatch_messenger_cli
  marketplace initiate --listing-id 123 --text-stdin` → rc=0, delegate
  invoked. Control `send --cid 999 --text-stdin` same secret → rc=1,
  delegate silent.
- **P1-2:** `hatch_gws_cli chat +send --space x --text "<synthetic
  secret>"` → delegate invoked, ungated. `hatch_gws_cli calendar
  +insert --title t --description "<synthetic secret>"` → delegate
  invoked, ungated. (`chat`/`calendar` confirmed as vendored services
  via read-only `--help`; shim fall-through at `hatch_gws_cli:164`.)
- **P0-3:** `/tmp` copy of the real `egress-gate` + detector `exit 3` →
  gate rc=0, log verdict `clean`. Detector `kill -9 $$` (rc=137) → gate
  rc=0, log verdict `clean`. Content was benign; the point is the
  verdict mapping, and the log line proves the failure is recorded as a
  clean pass.
- **P2-7:** `4111-111111111111` and `3782-822463-10005` → matched by stub
  `STUB_SECRET_CAND`, unmatched by audit `SHAPES` (separator-optional vs
  separator-required card groups).
- **P3-1/P3-2/P3-3:** confirmed by code inspection at
  `bin/leakage-report:387` (double prefix), `callout()`/legend
  (no 🟡 emission path), `:298,305` (stub mismatch wording).
- **P3-4:** `references/test-matrix.md:42` still reads "same six →
  `brief-gate` | 1/1/1/2/2/0" against seven fixtures expecting
  0/1/1/1/1/2/2.
- Baseline re-run: audit vs stub CLEAN 66/0/2; adversarial 36/36
  (19/19 block, 9/9 review, 8/8 clean) — the green baseline against
  which the above bypasses are invisible.
