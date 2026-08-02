# PLAY-073 R4-F3 Developed-Core Camera Repair Authority

## Disposition

The exact R4-F product candidate `fc996a287f5d0d16f58c13bc6ee2abadf4d64972`
is materially better and remains the only product base. Its independent R4-F
journey automatically returned the candidate after reproducing a viewport-
transition defect: the maximized regular layout leaves the authored road and
public-realm envelope below the frozen `0.60` safe-width threshold, while
Focus City immediately restores the same authoritative district above the
threshold. This localizes the defect to automatic camera invalidation rather
than world topology, renderer art, fixture state, or HUD ownership.

## Frozen diagnosis

`CityScene.resize(to:)` and `CityScene.updateViewportInsets(_:)` can run in
either order while AppKit settles the map aperture. Each currently requests a
developed-core refit. During that sequence, `applyDevelopedCoreCamera(_:)` may
observe temporarily unavailable composition bounds and call `fitCity(_:)`,
discarding the last valid developed-core scale and position. Focus City later
recomputes valid bounds, which explains the observed recovery without any
world mutation.

## Authorized implementation

Own only:

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`

Retain the last valid authoritative developed composition across automatic
`resize` and `updateViewportInsets` invalidations. Coalesce automatic refits
so the settled aperture receives one deterministic developed-core camera.
A transient incomplete composition may not replace a previously valid camera
with whole-board `fitCity`. Explicit player intent through `frameCity()` and
Focus City must still recompute from current authoritative state. A genuinely
empty city may still use the existing whole-board fallback.

Do not change terrain, roads, lots, assets, LOD rendering, world topology,
hit geometry, commands, HUD, gameplay, simulation, persistence, resources,
build scripts, claims, shared contracts, or evidence outside the worker-owned
R4-F3 root.

## Focused acceptance

Add deterministic permutation coverage for:

1. regular to maximized;
2. compact to maximized;
3. resize before viewport insets;
4. viewport insets before resize;
5. Focus City entry; and
6. Focus City exit.

At each settled aperture, require:

- non-null developed and camera-priority bounds;
- identical camera-priority coordinates for the unchanged state;
- developed occupied width at least `0.60` of safe viewport width;
- camera-priority width at least `0.60` of safe viewport width;
- no whole-board-fit fallback; and
- identical final camera position and scale for equivalent final inputs.

Retain and run these existing focused regressions:

- `testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs`
- `testOpeningCameraRefitsOnceAfterTheShippingViewportSettles`
- `testIndustrialStrainCameraPrioritizesTheDominantDistrictWithoutHidingRemoteTruth`

The worker returns one coherent implementation commit plus a compact
machine-readable R4-F3 result. Integration owns the full Swift suite and exact
staged build. A new independent PLAY-075 exact-candidate journey owns final
visual and interaction acceptance. Tests, source inspection, or worker prose
cannot substitute for that journey.
