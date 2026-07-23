# PLAY-045 Claim

- **Title:** Make last-known-good backup recovery reachable
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** integration commit containing this claim, based on accepted master `643fd1a`
- **Requirement IDs:** SIM-001, TEC-004, UX-007, REL-004, REL-009
- **Planned surfaces:** `SaveGameService` availability, narrow default-preserving `CityGameStore` service adoption, isolated persistence/store tests and fixtures, staged recovery evidence, and completion record
- **Dependencies:** accepted PLAY-043/044
- **Validation/proof:** empty/primary-only/backup-only/invalid-backup cases; schema-0/schema-1; four recovery identities; exact paused state/fingerprint/analytics/snapshot/continuation; two-probe and 1,000-call budgets; full suite; isolated Cmd-O or command-guide proof
- **Status:** active

Make Load availability reflect a surviving primary or backup without decoding,
repairing, promoting, deleting, or fabricating files. Keep `load()` authoritative
and preserve schema 1, fingerprint version 1, authentic fixtures, existing
recovery feedback, paused load, and cleared undo. Do not expand into generic
error redesign, durable undo, replay persistence, gameplay, renderer, or HUD
work.
