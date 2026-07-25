# CitySim Accepted Baseline

**Status:** BASELINE READY

**Published:** July 25, 2026

**Integration branch:** `master`

**Accepted product tip:** `ad2f35314bb471a07923c41653374b05ace51ee3`
(independently accepted Wave 006 world/HUD candidate)

**Baseline ref:** the `master` commit that contains this document, the active backlog, and the five first-wave claims.

## Accepted capabilities

- Native SwiftUI/SpriteKit app builds, stages, and launches through `./script/build_and_run.sh --verify`.
- The authored SpriteKit world opens on a dense golden neighborhood with connected road atlas, five place families, deterministic variation, ambient life, lifecycle truth, camera LOD, and stable incremental reuse.
- The map-first command-center HUD, compact arbitration, typed 32-row command catalog, menus, command guide, complete non-spatial shortcut coverage, and accessible focus rules are accepted.
- Onboarding freezes the exact authored start, contains pointer/keyboard commands, fits default and 900 x 600 layouts, and hands focus directly to the map after keyboard or pointer dismissal.
- Commercial and industrial strategies deliver warned opportunities, recoverable setbacks, distinct payoffs, costed utility guidance, and a durable Town Charter path with player interaction margin.
- Schema-1 saves, schema-0 compatibility, canonical v1 fingerprints, exact undo, backup recovery, immutable snapshots, injected roots, and unique worktree app identity are accepted.
- Every map coordinate now exposes one immutable, deterministic presentation sample for independent power/water service, pollution exposure, vitality, and replay-safe worsening/recovery transitions. The derived contract changes no save bytes, schema, or canonical state fingerprint.
- The generated-v4 city now uses coherent connected streets, continuous
  terrain/public-realm composition, grounded environmental detail, sparse
  non-obscuring consequence marks, and deterministic default/compact framing
  centered on the developed pressured district.
- The accepted non-shipping world-art catalog now contains separately authored
  Residential L1–L4 N/E/S/W variant-zero sources. Independent review accepted
  L2 at 26/28, L3 at 25/28, L4 at 26/28, and cross-level identity at 19/20;
  all 12 new raw sources and 36 normalized LOD outputs are unique. PLAY-028
  owns production selection and live renderer ingestion.
- Independent PLAY-053 scored the exact accepted product 19/20, with 4/4
  composition, 4/4 projection/material/light/street coherence, no category
  below 3, zero automatic rejects, and materially preferred regular and
  compact city/pollution comparisons.
- The complete native suite passes with 201 tests and no failures. The accepted
  renderer passes 43 focused tests, retains stable node identity across its
  unchanged-pulse soak, reports zero fallback assets and zero geometry
  collisions, and remains within declared cold-render, residency, and RSS
  ceilings.
- Independent PLAY-050 completed a fresh no-coaching pointer-and-keyboard journey in 9:55.966, made the first meaningful placement at 96.784 seconds, earned the permanent Town Charter, and save/resumed the exact paused fingerprint.
- Retained acceptance evidence is under `docs/production/evidence/`, especially `PLAY-021`, `PLAY-031`, `PLAY-040`, and `PLAY-050/f75ab91-sustained-session-accepted`.

## Known limitations carried forward

- Accepted PLAY-053 RSS remained bounded below the 333.8 MiB ceiling:
  126,320 KiB regular, 213,984 KiB compact interaction, and 229,808 KiB
  Reduce Motion. Continued profiling remains release work.
- Live authored building-family and N/E/S/W directional breadth remains
  visibly narrow and scored 3/4. PLAY-027 and CONTRACT-011 own the separately
  authored offline-scene catalog; PLAY-028 owns production selection of the
  accepted Residential L1–L4 source set. No incomplete source is
  production-selected.
- Deeper game identity, content breadth, audio, delight, progression beyond
  the first Charter, and continued world/HUD richness remain active production
  goals.

## Baseline gate evidence

- `swift test --package-path Native/CitySimNative`: 100 passed, 0 failed on exact integration commit `36774db` (228.953 seconds).
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: built, staged, and launched exact integration commit `36774db` as `dist/CitySim.app`.
- PLAY-041 spatial derivation averaged 1.153 ms, peaked at 1.242 ms, diffed transitions in 0.150 ms, and retained 46,080 sample bytes across the six-fixture gate.
- PLAY-050 independently passed onboarding containment/focus, authored-world interactions, the frozen 32-command inventory, compact/accessibility routes, save/load/undo/corruption recovery, same-lane isolation, Reduce Motion, and the sustained playable-session outcome.
- Accepted final state was Day 236 / tick 941, treasury $14,702.455, +$366 per cycle, population 535, happiness 54.964%, jobs 350, power +148, water +135, progression 12/awarded, digest `2dfb6b084ec13b9fb8d2048d8908bf66efee2022d09cbe339b3ce63afcd8adb4`.
- Wave 006 exact product `ad2f353` passed 201/201 native tests,
  43/43 renderer tests, staged source/resource parity, 324 reciprocal ground
  contacts, 36 road setbacks, 256 entrance/prop exclusions, zero collisions,
  3.749 ms cold world update / 4.973 ms total render, and independent real-app
  pointer, keyboard, AX, Full Keyboard Access, Reduce Motion, regular, and
  exact 900 x 600 compact routes.
- The integrated non-shipping Residential L1–L4 source catalog at
  `32e5d1dec2857f8617ecc3cd3c194c98d35b2d6b` passed 201/201 native tests,
  43/43 renderer tests, `git diff --check`, script syntax validation, and an
  exact staged `./script/build_and_run.sh --verify`. The accepted L2–L4 source
  candidate is `8f928ed5dd01453ff9d4d9910858d8bf786afa9d`;
  `8b6b16bad5c033f3036ed5b3a0c31fabad57051a` adds only the scope-truth
  documentation repair.
- The binding acceptance packet is
  `docs/production/evidence/PLAY-053/rescore-ad2f353/`; the quality completion
  is `docs/production/completed/PLAY-053.playtest-quality.md`.

Workers must branch from the exact publication commit sent by integration, confirm clean ancestry, read `AGENTS.md` and their lane skill, and keep coherent progress committed continuously.

## Wave-two authority

The next production round is defined by `docs/production/WAVE-002-AWESOME.md`. Its shared contracts are:

- `CONTRACT-002`: one command catalog and store intent route for non-spatial actions;
- `CONTRACT-003`: canonical state fingerprints, backward-compatible versioned saves, recovery, injected roots, snapshots, and narrow fixture commands;
- `CONTRACT-004`: unique staged bundle/process/data identity for every worktree.

Wave 002 passed integration and PLAY-050. Waves 003–005 established the
current gameplay, simulation, persistence, HUD, and generated-v4 platform.
Wave 006 is now accepted under
`docs/production/WAVE-006-WORLD-EXCELLENCE.md`. PLAY-027/CONTRACT-011 is the
active visual-breadth continuation. Residential L1–L4 source art is accepted
as a non-shipping input; PLAY-028 must still prove deterministic ingestion and
materially better live presentation before it becomes part of the accepted
product.
