# PLAY-043 Claim

- **Title:** Restore exact save, relaunch, and load trust
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** Wave 005 integration commit
- **Requirement IDs:** UX-007, TEC-004, REL-004, REL-009, SIM-001
- **Defect authority:** PLAY-051 exact candidate `23d2bf9` with retained primary/backup hashes and readable strategy payload
- **Planned surfaces:** SaveGameService validation/recovery, persistence diagnostics, exact data-root tests and fixtures, staged save/relaunch/load evidence; integration-controlled launch script only by proposal
- **Dependencies:** none beyond Wave 005 baseline; complete before PLAY-044 adoption
- **Validation/proof:** same exact bundle save, terminate, compact relaunch, load paused with exact fingerprint/progression; valid primary remains valid; corrupt-primary backup recovery, legacy fixtures, undo/replay, isolated roots, full suite, retained bytes and diagnostics
- **Status:** ready for integration; published exact-candidate relaunch gate passed with retained bytes and no SaveGameService rejection

Reproduce before editing and identify the exact rejection reason. Do not weaken digest, schema, atomic replacement, or corruption recovery to make the fixture pass. If the root cause is an integration-controlled launch/data-root contract, stop with the smallest proposal and evidence instead of editing the script locally.
