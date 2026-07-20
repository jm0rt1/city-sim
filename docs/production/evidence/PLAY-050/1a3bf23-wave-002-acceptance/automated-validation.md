# PLAY-050 Wave 002 Automated Validation — 1a3bf23

Validation used a fresh SwiftPM scratch path at `/private/tmp/citysim-play050-build-1a3bf23`.

- Full native suite: **89/89 passed** in 233.269 seconds.
- Renderer diagnostic: 9,004 nodes; ten-pulse average 1.961 ms.
- Dense fixture fingerprint: `7b6454` (matched the integration-published expectation).
- Soak: 4,286 pulses, 9,004 nodes, 2,424 drawables, three actions, 0.9009 ms average, no node/drawable growth.
- Motion diagnostic: five ambient actions normally and zero with Reduce Motion.
- Staged `script/build_and_run.sh --verify`: passed before live execution.
- Same-lane `script/verify_candidate_isolation.sh`: passed with two simultaneous candidates.
- `git diff --check` and script syntax checks: passed.

Green automation is recorded as supporting evidence only. The accompanying live session record supplies the required staged-app checks.
