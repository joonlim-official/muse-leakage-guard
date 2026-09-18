# Iteration-5 review brief — Staff systems engineer

Repository: ~/workspace/skills/muse-leakage-guard (public GitHub repo:
github.com/joonlim-official/muse-leakage-guard). HEAD: e4b2af1
"Iteration 4: CI readiness + synthetic stub skill".

What the repo is: a validation-only harness (bash, ~2–4k lines across
bin/leakage-audit, bin/leakage-report, bin/adversarial-run) that audits
an AI assistant's leakage protection: installation integrity, red-team
gate tests, attack-surface coverage, gate-log review, residual-risk
report, plus a 36-case adversarial corpus. Iteration 4 added the stub
skill, the gate-interface contract, machine-readable audit sentinels
(@@@ lines under MOCHI_AUDIT_MACHINE=1), and a CI workflow.

Your task: review from the staff-systems-engineer perspective and
produce a findings list (each: priority, title, evidence path/line,
recommendation).

Focus for iteration 5:
- Code health of the harness: read bin/leakage-audit, bin/leakage-report,
  bin/adversarial-run and the stub scripts. Flag dead code, duplicated
  logic (e.g. pattern definitions living in both patterns.sh and the
  real skill's gates — is the duplication load-bearing or drift-prone?),
  fragile parsing (the report's legacy text-scrape fallback), and error
  handling gaps (a gate that hangs is caught by timeout in
  adversarial-run — is it caught everywhere?).
- The SHAPES manifest idea (backlog): the audit has an implicit list of
  secret shapes it knows about. Recommend a concrete design for an
  explicit, versioned manifest mapping shapes → tiers → corpus cases →
  fixtures, and where the audit should fail if the manifest and the
  corpus disagree.
- Interface versioning: gate-interface.md declares interface_version=1.
  Assess the versioning story — what happens when the real skill's
  interface moves to v2 while the stub stays v1? Recommend a conformance
  check the audit should run.
- Performance and scale: the audit runs ~58 checks; adversarial-run
  spawns 36 gate invocations. Assess runtime, identify anything
  quadratic or needlessly serial, and recommend a budget.

> Privacy: least privilege. Use only the facts in this brief. If a step
> needs personal details (name, address, phone, email, payment, account
> identifiers, or anything about the user's family or finances), STOP and
> ask for that specific field — do not guess, do not fill it from any
> other context, and do not reuse personal info you may have seen
> elsewhere. Never type private data into a page, message, or form unless
> it was explicitly provided for that step in this task. Details given
> for one step stay in that step.
