# Changelog

Brief per-iteration notes. Each iteration: all 10 personas review in
parallel → synthesis → one focused diff → full validation → one commit.

## Iteration 1 — Opt-in live-fire mode + synthetic-data purge

- **Live-fire mode** (`MOCHI_LIVE_FIRE=1`): suite B runs a small
  representative subset for real — shim → gate → genuine binaries —
  instead of the fake-binary simulation. Default stays simulated (safe
  for CI/contributors); live-fire is never the default.
- Real sends go to the owner's own accounts **only, ever**: email target
  `MOCHI_TEST_EMAIL` (default owner's own address); Messenger target is
  auto-discovered as an owner-only chat, and an explicit
  `MOCHI_TEST_MESSENGER_CID` that doesn't resolve to such a chat fails
  closed. Payloads stay synthetic. Drive share tests stay simulated.
- Block-tier assertions unchanged (exit 1, real binary never invoked);
  verified live: block-tier email refused and never arrived; clean and
  approval-tier emails delivered end-to-end.
- Audit header, summary, and HTML report label the mode
  (`SIMULATED` vs `LIVE-FIRE`); report footer is mode-aware.
- **Synthetic-data purge**: replaced a real booking confirmation number
  and a real ZIP in the public adversarial corpus with fictional values,
  and de-personalized the profile path in `local.env.example`.
- README: new "Live-fire mode" section, config table entries, corrected
  dependency line (`bash` + `python3`).

Validation: `bash -n` clean on all touched scripts; `bin/leakage-audit`
58 passed / 0 failed / 1 skipped (CLEAN) in simulated mode;
`bin/adversarial-run` 36/36; live-fire run exit 0 with arrival/non-arrival
verified in the owner's own inbox.
