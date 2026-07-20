# PLAY-050 Final Wave 002 Candidate — Automated Validation

- Product candidate supplied by integration: `1084ba6ef624f9928d80f30829fe9f651ed68166`.
- Frozen playtest merge HEAD: `d947b7d660d5778dcf34c165e750db293e060236`.
- Candidate ancestry: `git merge-base --is-ancestor 1084ba6ef624f9928d80f30829fe9f651ed68166 d947b7d660d5778dcf34c165e750db293e060236` passed.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/verify_candidate_isolation.sh`: passed.
- Fresh independent native suite, using `/private/tmp/citysim-play050-build-d947b7d`: **87/87 passed in 222.526 seconds**.
- `./script/build_and_run.sh --verify`: passed and launched exact PID `39809`; the explicit compact rerun launched exact PID `40734`.
- Dense fixture: `dense-24x24-terminal-wave2-v2`, 400 attempts, tick 44, `.lost`, fingerprint `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`, 135,456 bytes.
- Renderer: 9,004 nodes; 5,760 unchanged tile reuses and zero updates; 1.745 ms average across ten pulses.
- Thirty-minute renderer-equivalent soak: 4,286 pulses, 9,004 nodes, 2,424 drawables, 3 bounded actions, 0.8748 ms average with no growth.
- The first sandboxed test attempt is not candidate evidence: SwiftPM encountered a read-only stale `.build` database and the stale xctest binary exited by signal 11. The fresh scratch build above replaced it and passed completely.

Automated success does not override the live D006 focus failure.

## Independent confirmation after disposition

The rejection evidence was independently revalidated from the same product tree after the evidence-only disposition commit. A second full native run passed **87/87 tests with zero failures in 227.872 seconds**. It reported 9,004 renderer nodes, 5,760 unchanged tile reuses, zero updates, a 1.751 ms ten-pulse average, a 0.8703 ms 30-minute-equivalent soak average, and the same dense fixture digest `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`. This confirms that D006 is a live focus-handoff failure not detected by the green automated suite.
