# Iteration-5 security review — muse-leakage-guard (HEAD e4b2af1)

Reviewer: senior security engineer (subagent). Scope: read-only review of
`test/stub-memory-skill/` fail-closed design, `references/attack-surface.md`
coverage, `.github/workflows/validate.yml` safety shape, and residual
silent-fusion risks. All probes used synthetic fixtures only.

Baseline established before probing: `bin/adversarial-run` 36/36 green
(block-tier recall 19/19, review-tier recall 9/9, clean precision 8/8);
`bin/leakage-audit` against the stub: 57 passed, 2 skipped, CLEAN.
`build/build-blockset.sh --check` current (21 tokens). Findings below are
gaps *inside* that green run.

Verified correct (no finding): the approval override (`MOCHI_EGRESS_APPROVED=1`
/ `--approved`) in both stub gates turns rc=2 into 0 but can never turn rc=1
into 0 — the `RC -eq 1` branch exits before the approval check in
`test/stub-memory-skill/bin/egress-gate` and `bin/brief-gate`. CI has no
`pull_request_target`, pins actions by SHA, sets `contents: read` +
`persist-credentials: false`, uses no secrets, refuses live-fire variables
and a committed `local.env`, and keeps `fetch-depth: 1`.

No P0 findings.

---

## P1 — Multi-file scan fuses tokens across file boundaries: block-tier (rc=1) degrades to review-tier (rc=2)

**Evidence:** `test/stub-memory-skill/bin/memory-egress-check:36`
(`for f in "$@"; do ... cat "$f" >> "$INPUT"; done` — no separator between files).
Demonstrated: two files, each holding one declared block-tier token, where the
first file lacks a trailing newline. Scanned together the tokens fuse
(`...T1zsk_test_...`), the greedy extractor pulls a fused candidate whose
sha256 is not in `blockset.txt`, and the second token is swallowed entirely:
result rc=2 REVIEW. The same first file scanned alone: rc=1 BLOCK.

**Recommendation:** Separate concatenated inputs, e.g.
`{ cat "$f"; printf '\n'; } >> "$INPUT"` in the loop (a trailing newline is
harmless to both `grep -oE` extraction and the `-qE` figure/phone checks).
Same latent class in `test/stub-memory-skill/build/build-blockset.sh:39-43`,
which appends fixture files with bare `cat`: currently dormant (every fixture
ends in `\n`, verified), but one editor save dropping a trailing newline
silently fuses/loses tokens and `--check` would bless the corrupted set
because the corruption is deterministic. Add the same newline guard there.

**Residual if not fixed:** any caller using the documented `[file ...]` form
with a newline-less file gets block-tier payloads classified as review-tier;
and the blockset builder remains one keystroke away from reintroducing the
exact iter-4 silent-fusion bug through a different concatenation point.

## P1 — Raw-MIME shim path fails open when python3 is missing or the payload isn't JSON-with-`raw`

**Evidence:** `test/stub-memory-skill/bin/shims/hatch_gws_cli:101-119`. If the
`python3` decode step fails (missing interpreter — note the `2>/dev/null`),
the shim falls back to gating the *encoded* payload (`printf '%s' "$payload" >
"$tmp"`). The same happens when the payload parses as JSON without a `raw`
key, or isn't JSON at all (`sys.stdout.write(p)` in the embedded script):
base64 text carries no recognizable shapes, so the gate returns CLEAN.
Demonstrated: `gmail users messages send --params '{"raw":"<base64 of MIME
containing block-tier SSN 123-45-6789>"}'` with a non-functional python3 →
shim rc=0, delegate invoked. Control with working python3 → rc=1, delegate
not invoked.

**Recommendation:** Fail closed on this path: if the interpreter is missing
or the payload cannot be decoded to MIME, refuse (exit 2, or 1) rather than
gating the encoded bytes. At minimum, `command -v python3` up front and treat
absence as a hard refusal, and drop the silent `2>/dev/null`.

**Residual if not fixed:** attack-surface.md A4 claims PROTECTED for the raw
API path, but that verdict holds only where python3 exists and the payload is
JSON-with-`raw`; anywhere else an encoded secret passes as CLEAN — a fail-open
shaped exactly like the bypass A4 was written to close.

## P1 — Catalog gap: no scenario for out-of-band network egress (curl / webhook / third-party skill CLI)

**Evidence:** absence in `references/attack-surface.md` (verified: no mention
of curl, webhook, or general HTTP egress in the catalog or `bin/leakage-audit`);
meanwhile C5 (`references/attack-surface.md:187-195`) concludes
"PROTECTED (in depth)" on the grounds that "even if an agent were steered,
the send would still hit the egress gate (A1–A4...)". That holds only for the
two shimmed CLIs. A steered agent exfiltrating via `curl --data`, a webhook
call, or any non-shimmed skill CLI (booking, payments, etc.) never touches a
gate.

**Recommendation:** Add the scenario (e.g. C6/A9) with an honest verdict
(OPEN GAP, or POLICY-ONLY at best), and qualify C5's "the send would still hit
the egress gate" to sends through shimmed CLIs. One focused diff: catalog
entry + audit re-report line.

**Residual if not fixed:** the catalog's own coverage discipline ("a path with
no scenario is an unexamined path — that is the failure mode this skill exists
to prevent") is violated for the most obvious non-shim exfil path, and C5
overstates the defense-in-depth claim to anyone reading the catalog as
complete.

---

## P2 — CI step-summary greps are unanchored: attacker-controlled corpus case names can inject summary lines

**Evidence:** `.github/workflows/validate.yml:153-156`
(`grep -aE 'Total: [0-9]+ passed'`, `grep -aE 'adversarial-run: [0-9]+/[0-9]+ cases matched'`,
`grep -aE 'block-tier recall'`). `bin/adversarial-run` prints
`  MISMATCH <name> ...` lines where `<name>` is the attacker-controlled first
field of `bin/adversarial-corpus.txt` — a fork-PR author fully controls the
corpus. A crafted case name containing e.g. `block-tier recall 99/99` (or
`adversarial-run: 36/36 cases matched`) lands verbatim in the log and is then
copied into `$GITHUB_STEP_SUMMARY` as if it were the runner's own output.

**Recommendation:** Anchor the greps to the runner's own summary lines:
`^adversarial-run: ...` / `^block-tier recall` won't match `  MISMATCH` lines;
likewise `^  Total: ` for the audit line (the audit indents it two spaces,
`bin/leakage-audit:217`).

**Residual if not fixed:** low blast radius (no secrets in CI), but the PR
summary is the reviewer's trust surface — injected lines can fake green
counts on a failing run.

## P2 — Undocumented pattern-recognition gaps: phone/figure shapes that bypass to rc=0

**Evidence:** `test/stub-memory-skill/bin/patterns.sh:26` (`STUB_FIGURE_CAND`)
and `:31` (`STUB_PHONE_CAND`). The header claims anything secret/figure/
phone-shaped not in the block set maps to review-tier (fail closed), but
shapes the regexes never match bypass to rc=0, and only two such gaps are
documented (`$1`-style shell params, bare 10-digit phones). Probed and
confirmed rc=0: `(415)555-0132`, `1(415)555-0132` (separator required after
`)`), and `$ 12,500` (space after `$`).

**Recommendation:** Add corpus cases with `want=2` for these shapes (as was
done for `phone_bare10`/`clean_price`), or document them as residuals in
`patterns.sh` like the existing two. Either way the shape space the stub
claims to cover becomes explicit.

**Residual if not fixed:** a green stub run understates the shape space; if
the real gate shares any of these gaps, the harness cannot see it, and the
"fail closed" framing in `patterns.sh` overpromises.

## P2 — A7 "PROTECTED (by audit)" overstates a static string check

**Evidence:** `references/attack-surface.md:78-86` (conclusion PROTECTED);
the audit check is `grep -q 'bin/shims:$PATH'` over cron prompt files
(`bin/leakage-audit:519-527`). A prompt can contain the literal string yet
still send outside the gate: a later `PATH=` reassignment, `env -i`, or
delegation to a wrapper script that drops the shim directory all preserve
the magic string while defeating the protection.

**Recommendation:** Either downgrade A7 to POLICY-ONLY (matching A8's honest
framing) or strengthen the check to flag `PATH=` reassignment / `env -i`
after the export line.

**Residual if not fixed:** the catalog reports as PROTECTED a control that a
prompt can satisfy textually while bypassing functionally — the same class of
overclaim the A7 "real catch" was supposed to have retired.

## P2 — Contract/implementation mismatch: shim gates subject+body, contract says body/to

**Evidence:** `references/gate-interface.md:67` — "Gmail `+send`, `+reply`,
`+forward`: body/to pass `egress-gate`." The stub shim's `+send` branch
(`test/stub-memory-skill/bin/shims/hatch_gws_cli`, `gate_file` call) scans
`subject: ...\n\n<body>` only; `--to` is never passed through the gate.

**Recommendation:** Either include the recipient in the gated payload or fix
the contract wording. One-line-class diff either way.

**Residual if not fixed:** minor — recipient addresses are destinations, not
content, so the practical exposure is nil; this is a harness-fidelity /
documentation inconsistency, not a leak path.

---

## Notes for the iteration-5 diff

- The one focused diff this review supports: (1) newline-separate
  concatenated inputs in `memory-egress-check` and `build-blockset.sh`;
  (2) fail-closed raw-MIME decode in the stub shim; (3) new catalog scenario
  for out-of-band egress + C5 qualification; (4) anchored CI summary greps;
  (5) corpus cases or documented residuals for the phone/figure shape gaps;
  (6) A7 verdict correction; (7) gate-interface wording fix.
- Re-validation after the diff: `build-blockset.sh --check`, `bin/adversarial-run`
  (expect 36/36 plus any new corpus cases), full `bin/leakage-audit` against
  the stub, and re-run of the two empirical probes above (multi-file fusion,
  python3-absent raw send).
