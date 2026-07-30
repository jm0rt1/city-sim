# PLAY-088 Claim — phase A

- **Title:** Prove storm-recovery persistence without rewriting history
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** Next published clean Integration commit containing this
  claim and CONTRACT-022
- **Planned phase-A surfaces:** `docs/production/evidence/PLAY-088/` only
- **Reserved phase-B surfaces:** One new simulation-owned
  `StormRecoveryPlatformTests.swift`, task-local validators,
  `docs/production/evidence/PLAY-088/`, and
  `docs/production/completed/PLAY-088.simulation-platform.md`
- **Dependencies:** CONTRACT-022 now; exact integrated PLAY-085 revision-2
  product before phase B
- **Validation/proof:** Current canonical-byte/fingerprint inventory;
  candidate-neutral acceptance matrix; later two-root, save/load/backup,
  replay/fingerprint/snapshot/Undo and fail-closed proof
- **Status:** Phase A ready for exact published-baseline synchronization;
  phase B blocked on integrated PLAY-085

Phase A must remain product- and test-read-only. Freeze exact current new-city,
legacy, accepted-fixture, schema, fingerprint, replay, save, backup, snapshot,
and Undo inputs plus the future candidate acceptance matrix. Do not add types
or tests that fail to compile before PLAY-085 exists.

Phase B may begin only after a new Integration authority binds one exact
integrated PLAY-085 commit. It may add only the reserved platform test and
task-owned evidence/validators.

Do not edit CityGameState, CitySimulation, SaveGameService, existing fixtures,
manifests, schema/fingerprint versions, gameplay/UI/renderer/art,
package/build files, other claims, or legacy Python. Do not push, integrate,
pin, self-score, or self-accept.
