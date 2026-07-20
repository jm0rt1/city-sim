# PLAY-051 Preparation Checkpoint

- **Quality baseline:** `cbcc6fd2b23cb08fc0b937ae1f236c630d499474`
- **Status:** rubric and harness frozen; no final candidate accepted or tested
- **Product changes:** none

Prepared artifacts:

- `ACCEPTANCE-RUBRIC.md` freezes the two full routes, accessibility/persistence variants, operational definitions, G01–G16 hard gates, evidence requirements, and stop conditions.
- `CANDIDATE-HARNESS.md` reuses the accepted CONTRACT-004 launcher and `script/verify_candidate_isolation.sh`, defines immutable route directories, timing/ledger rules, persistence/corruption handling, and a fail-fast Computer Use boundary.
- `session-ledger-template.csv` captures every decision, consequence, dead-time interval, confusion, recovery, and proof reference without reconstructing live times later.
- `strategy-comparison-template.md` prevents post-hoc strategy-equivalence claims and freezes the replay-desire question.

Computer Use remains a disclosed infrastructure risk. Three exact-bundle state requests returned no state and were aborted after 2,275.1, 5,922.0, and 913.1 seconds; the last followed orphan cleanup and ignored a requested 12-second timeout. Final testing therefore requires a fresh session, one 12-second request, and a separate 30-second integration-enforced outer boundary. An unresponsive call blocks live acceptance and is not retried or replaced with prohibited automation.

No app was launched, no final acceptance route was run, no worker was coached, and no product, shared contract, platform fixture, or build script was changed during preparation.
