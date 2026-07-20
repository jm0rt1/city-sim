# CitySim Accepted Baseline

**Status:** BASELINE READY

**Published:** July 19, 2026

**Integration branch:** `master`

**Accepted product tip:** `6736c67` (`PLAY-010` gameplay integration, including the accepted `PLAY-001` foundation)

**Baseline ref:** the `master` commit that contains this document, the active backlog, and the five first-wave claims.

## Accepted capabilities

- Native SwiftUI/SpriteKit app builds, stages, and launches through `./script/build_and_run.sh --verify`.
- The programmatic top-down world renderer, map-first shell, command-center HUD, build/inspect/bulldoze modes, overlays, undo, and labeled simulation speeds are present.
- New Arcadia opens under readable budget, employment, and utility pressure; ignored growth worsens into a warned but recoverable squeeze.
- Two deterministic strategies can earn a durable Town Charter after 12 consecutive qualifying days and remain viable through exactly 2,800 ticks / approximately 19.6 minutes at 1× cadence.
- The complete native suite passes with 45 tests and no failures.
- Retained default, compact, placement, overlay, diagnostics, and HUD proof is under `docs/visuals/`.

## Known limitations carried into wave 1

- World consequences need authoritative simulation inputs and stronger authored visual storytelling.
- Every non-spatial action needs one governed command registry and verified shortcut route; keyboard world navigation remains a separate design problem.
- Save/replay/determinism, schema recovery, immutable snapshots, and performance evidence remain incomplete.
- A fresh uninterrupted keyboard/accessibility soak and complete 20-minute playable-session gate remain required.

## Baseline gate evidence

- `swift test --package-path Native/CitySimNative`: 45 passed, 0 failed after PLAY-010 integration.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: built, staged, and launched `dist/CitySim.app`.
- Live inspection confirmed the command-center controls and gameplay surfaces. A keyboard sequence was interrupted by an external staged-bundle change, so the fresh soak is assigned to `PLAY-050`.
- PLAY-010 live inspection confirmed objective blockers, budget/reserve/hiring warnings, 3× selection with `3`, and Space-to-pause with focus intact. Retained evidence is under `docs/production/evidence/`.

Workers must branch from the exact publication commit sent by integration, confirm clean ancestry, read `AGENTS.md` and their lane skill, and keep coherent progress committed continuously.

## Wave-two authority

The next production round is defined by `docs/production/WAVE-002-AWESOME.md`. Its shared contracts are:

- `CONTRACT-002`: one command catalog and store intent route for non-spatial actions;
- `CONTRACT-003`: canonical state fingerprints, backward-compatible versioned saves, recovery, injected roots, snapshots, and narrow fixture commands;
- `CONTRACT-004`: unique staged bundle/process/data identity for every worktree.

The accepted product tip remains `6736c67` until wave-two candidates pass integration and PLAY-050. The baseline publication commit containing these decisions is management authority, not a claim that the current game has passed the playable-session gate.
