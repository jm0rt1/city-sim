# PLAY-065 Claim

- **Title:** Give the city authoritative local activity
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** Published `1b883ca684b07ba38c5c755b616723bde0cd2230`
- **Planned surfaces:** `CitySpatialConsequence` snapshot derivation, deterministic/performance tests, exact compatibility evidence, and `docs/production/evidence/PLAY-065/`
- **Dependencies:** accepted PLAY-041/048/059, CONTRACT-016, exact published baseline
- **Validation/proof:** applicability/nil boundaries; monotonic connection/occupancy/condition/service/recovery fixtures; repeat identity; no state mutation; exact save/fingerprint/undo/replay compatibility; bounded snapshot time and memory; focused/full suites
- **Status:** ready for integration at product commit
  `aadbc3e4b0192d1c8aec1a753817c57ca5ff0f01`

Add only the transient `streetActivityIndex` and `placeActivityIndex` channels
approved by CONTRACT-016. Derive them from existing authoritative state and
make zero/nil meaning explicit for renderer adoption.

Do not simulate people, vehicles, trips, routes, or schedules; rebalance the
economy; edit renderer/UI/gameplay code; persist the values; regenerate legacy
fixtures; push; integrate; self-accept; or pin the thread. Commit product/tests
and evidence/completion separately.
