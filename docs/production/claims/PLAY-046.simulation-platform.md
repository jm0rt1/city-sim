# PLAY-046 Claim

- **Title:** Adopt terminal Charter victory into runtime trust
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** integration commit containing this claim, based on accepted master `ab722bd`
- **Gameplay source:** `0e3e68e5cac31d9f4b340eba18a6aa6bf8608232`
- **Requirement IDs:** SIM-001, SIM-002, SIM-004, SIM-006, TEC-004, REL-002, REL-004
- **Planned surfaces:** platform-owned deterministic command/checkpoint fixtures and digests, won-state persistence/replay/undo/backup/snapshot tests, focused evidence, and completion record
- **Dependencies:** PLAY-015 frozen product; accepted PLAY-044; preserve completed PLAY-045 commits
- **Validation/proof:** exact four-route terminal fingerprints, rejected post-terminal commands, authentic legacy schema-0/schema-1 compatibility, awarded-playing next-boundary normalization, save/resume/replay/undo/backup/snapshot equality, frozen pre-victory digests, focused/full suite, budgets, and exact staged won-state relaunch where practical
- **Status:** active

Adopt the accepted PLAY-015 terminal semantics without changing gameplay rules.
Update only platform-owned expectations and add the smallest missing runtime
trust coverage. Preserve schema 1, fingerprint version 1, authentic fixture
bytes, pre-victory identities, completed PLAY-045 work, and every existing
budget. Do not edit UI, renderer, gameplay implementation, task authority, or
general replay architecture.
