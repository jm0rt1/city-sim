# PLAY-040 Claim

- **Title:** Establish deterministic simulation and recovery contracts
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base commit:** Baseline publication commit containing this claim
- **Claimed:** July 19, 2026
- **Planned surfaces:** save/recovery services, deterministic fixtures, hashes, snapshots, diagnostics, platform tests
- **Dependencies:** Approved `CONTRACT-003`, `CONTRACT-004`, and PLAY-010/050 fixture inputs
- **Validation/proof:** Repeated hashes, save/load/undo/recovery invariants, measured performance, full tests
- **Status:** ready-for-integration

## July 20 PLAY-011 companion

Integration explicitly authorized this lane to merge gameplay product candidate `dd49ea5f6d5d2ea13d726e4b5083b4b52bbefb2d` over master `71a113855dd41ab9d6576e3755183994a74c6118`, independently validate its deterministic state changes, and advance only the affected frozen platform fixtures. The merged validation baseline is `1d494dbb743d77f4e03bd8ababb9804c0eb6202e`; the focused frozen-fixture outcome is `106bbf4e90968eeef7f9c8663174254dfbaafd7f`.
