# CitySim Accepted Baseline

**Status:** BASELINE READY

**Published:** July 25, 2026

**Integration branch:** `master`

**Accepted product candidate:** `f928696a84676032b20c6306b14d943592e219fb`
(independently accepted directional Residential, Commercial, and Industrial
L1 product)

**Independent evidence and published tip:**
`1b883ca684b07ba38c5c755b616723bde0cd2230`

**Industrial L1 product commit:** `02612e414912fdabcab858b0ca97e1f5edbc2757`

**Accepted Industrial L1 source authority:** `79668c347e58d602f9627c73cb09e3272a83ef57`

**Industrial source integration merge:** `d34345720bd1ffff7858928ad5d5c428acd57f3d`

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
- The shipping generated-v4 world now contains 16 separately authored
  Residential L1–L4 N/E/S/W identities and 48 unique normalized LOD payloads.
  Runtime selection derives from authoritative adjacent-road frontage with no
  mirror, rotation, alias, cross-level substitution, or fallback.
- The shipping generated-v4 world also contains 16 separately authored
  Commercial L1–L4 N/E/S/W identities and 48 unique normalized LOD payloads.
  PLAY-061 independently approved the exact combined product 20/20 with every
  category 4/4, zero P0/P1 defects, and zero automatic rejects.
- Industrial L1 now ships as four separately authored, repeat-identical
  N/E/S/W factory identities and 12 unique normalized LOD payloads. Runtime
  selection uses authoritative road frontage with no transform, alias,
  fallback, or cross-family substitution. PLAY-063 independently approved the
  exact combined candidate 20/20 with every category 4/4.
- The readable command surface uses responsive HUD composition with 11-point
  critical/action typography, 10-point decision-support typography, complete
  compact Overview and Journal content, and a world-first 60.2% closed /
  45.2% open map aperture.
- Independent PLAY-055 scored the exact accepted product 20/20, with every
  category at 4/4, zero P0/P1 defects, zero automatic rejects, and material
  preference over the frozen baseline in both regular and compact layouts.
- The complete native suite passes with 226 tests and no failures. The accepted
  renderer passes 55 focused tests, reports zero fallback assets and zero
  geometry collisions, uses four pages with a stable 41,943,040-byte
  repeated-cycle high-water, and remains within declared render and RSS
  ceilings.
- Independent PLAY-050 completed a fresh no-coaching pointer-and-keyboard journey in 9:55.966, made the first meaningful placement at 96.784 seconds, earned the permanent Town Charter, and save/resumed the exact paused fingerprint.
- Retained acceptance evidence is under `docs/production/evidence/`, especially `PLAY-021`, `PLAY-031`, `PLAY-040`, and `PLAY-050/f75ab91-sustained-session-accepted`.

## Known limitations carried forward

- Accepted PLAY-055 RSS remained bounded below the 333.8 MiB ceiling:
  194.52 MiB regular, 175.83 MiB compact, and 194.25 MiB Reduce Motion.
  Continued profiling remains release work.
- Industrial directional breadth above L1 remains incomplete. Industrial L2
  source authoring is under a level-by-level deterministic review gate, while
  L3/L4 remain blocked. No higher level may enter the shipping pack before
  independent source review and a separate renderer/quality gate.
- Spoken VoiceOver audio was not recorded for PLAY-055. Live AX actions, AX
  trees, and Full Keyboard Access were exercised successfully.
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
- Exact product `7b432c4` passed 206/206 native tests, 47/47 renderer tests,
  staged source/resource parity, four-page deterministic residency, zero
  fallback, zero collisions across 2,972 geometry checks, and independent
  real-app pointer, keyboard, AX, Full Keyboard Access, Reduce Motion, regular,
  and exact 900 x 600 compact routes.
- Exact Commercial product `1799fbc` passed 223/223 native tests, 52/52
  renderer tests, deterministic source/staged pack identity, four-page bounded
  residency, zero fallback, zero geometry collisions, staged regular and exact
  compact pointer/keyboard/FKA/AX/Reduce Motion/save-load/undo journeys, and
  independent PLAY-061 approval at 20/20.
- Exact Industrial L1 combined candidate `f928696` passed 226/226 native
  tests, 55/55 renderer tests, deterministic four-page pack parity, zero
  fallback and geometry collisions, regular/compact/Reduce Motion
  pointer-keyboard-AX-save-undo journeys, and independent PLAY-063 approval at
  20/20 with zero P0/P1 defects and zero automatic rejects.
- Non-shipping Industrial L1 source authority `79668c3` passed four-direction
  three-process raw identity, 12/12 unique two-run normalized LOD identity,
  registration/frontage/alpha/chroma/padding checks, accepted-source byte
  preservation, and independent color/grayscale family review.
- The integrated non-shipping Residential L1–L4 source catalog at
  `32e5d1dec2857f8617ecc3cd3c194c98d35b2d6b` passed 201/201 native tests,
  43/43 renderer tests, `git diff --check`, script syntax validation, and an
  exact staged `./script/build_and_run.sh --verify`. The accepted L2–L4 source
  candidate is `8f928ed5dd01453ff9d4d9910858d8bf786afa9d`;
  `8b6b16bad5c033f3036ed5b3a0c31fabad57051a` adds only the scope-truth
  documentation repair.
- The binding acceptance packet is
  `docs/production/evidence/PLAY-055/candidate-7b432c4/`; the quality completion
  is `docs/production/completed/PLAY-055.playtest-quality.md`.

Workers must branch from the exact publication commit sent by integration, confirm clean ancestry, read `AGENTS.md` and their lane skill, and keep coherent progress committed continuously.

## Wave-two authority

The next production round is defined by `docs/production/WAVE-002-AWESOME.md`. Its shared contracts are:

- `CONTRACT-002`: one command catalog and store intent route for non-spatial actions;
- `CONTRACT-003`: canonical state fingerprints, backward-compatible versioned saves, recovery, injected roots, snapshots, and narrow fixture commands;
- `CONTRACT-004`: unique staged bundle/process/data identity for every worktree.

Wave 002 passed integration and PLAY-050. Waves 003–005 established the
current gameplay, simulation, persistence, HUD, and generated-v4 platform.
Wave 006 remains the governing world-excellence program under
`docs/production/WAVE-006-WORLD-EXCELLENCE.md`. PLAY-028/054/055 are now
accepted in the product baseline. PLAY-027/CONTRACT-011 remains the active
visual-breadth continuation for Commercial and Industrial source production.
Wave 008 is the active combined product program under
`docs/production/WAVE-008-CITY-WITH-A-SECOND-ACT.md`.
