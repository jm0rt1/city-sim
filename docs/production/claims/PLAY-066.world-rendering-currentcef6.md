# PLAY-066 Current-Baseline Claim — Distinguish the Developed Public Realm

- **Task:** PLAY-066 — Finish the space between the buildings
- **Lane:** World rendering
- **Owner:** Agent 401, thread `019fec7c-28ee-7691-80fd-6ee62f33212c`
- **Branch:** `codex/citysim-world-rendering-play066-currentcef6`
- **Worktree:** `/private/tmp/citysim-play066-public-realm-currentcef6`
- **Product baseline:** `cef63edb11eb473aa4be63a0bce8f921df60f684`
- **Status:** One bounded outcome lease authorized after the read-only
  current-baseline comparison.

## Player-visible deficiency

At regular and exact 900 x 600 city, neighborhood, and block views, the
existing developed-district public-realm envelope is too close in color and
opacity to macro turf. Road-enclosed vacant blocks and the space around
civic/service buildings remain visually indistinguishable from countryside,
making developed roads and structures appear to float on one broad green
field.

## Mutable paths

- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-066/currentcef6/`
- `docs/production/completed/PLAY-066.world-rendering.md`

The allowlist is a maximum; stage only paths with meaningful changes.

## Frozen behavior

Tune only the existing `district.fabric.authored-envelope`,
`expansion-band`, and `public-realm-envelope` material or opacity values.
Do not add geometry, nodes, assets, parcels, roads, lots, gameplay cells, or
new simulation truth. Preserve buildability, inverse hit mapping, road and lot
geometry, node/draw counts, camera framing, selection, asset pixels,
interaction, accessibility, and all existing CityScene/PLAY-073 bytes.

Do not touch `RoadRenderer`, `LotRenderer`, camera code, palette contracts,
art/source intake, simulation, UI/input, persistence, packages, build scripts,
the excluded dirty PLAY-073 worktree, or unrelated evidence.

## Focused proof and stop

Run one focused `WorldRenderingTests` invocation covering:

- `testMacroTerrainReplacesTheRepeatedCellPlateAndKeepsEmptyLotsInteractive`
- `testRoadEnclosedCommonsStayVacantAndJoinTheAuthoritativeFrontageNetwork`
- `testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs`

Capture same-state Day-53 regular and exact 900 x 600 city, neighborhood, and
block frames through the existing test-owned export surface. One bounded local
repair is permitted only within the same material/opacity values and focused
assertions.

Stop without commit on any geometry, hit mapping, buildability, draw/node,
camera, selection, asset, truth, path, or focused-proof drift, or if the final
regular/compact frames still lack a clearly readable developed-fabric
boundary. On PASS, stage explicit meaningful paths and create one coherent
`PLAY-066:` commit. No aggregate, stage-only app build, real-app QA, source
intake, push, release, integration, or self-acceptance.
