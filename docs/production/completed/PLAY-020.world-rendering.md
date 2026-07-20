# PLAY-020 Completion — Readable City Consequences

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** ready-for-integration
- **Wave 002 baseline:** `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- **Claim:** `docs/production/claims/PLAY-020.world-rendering.md`

## Player-visible outcome

Construction, healthy growth, stress/decline, and recovery now read as different physical states of the city instead of palette swaps. Site preparation has excavated ground, earth piles, tracks, and survey stakes; foundations add slabs, rebar, and materials; structures add frames, pallets, and a moving crane; finishing adds the real building silhouette, scaffolds, wrap, and finish props. Maintained multi-level lots show healthy-growth chevrons and planted frontage. Stressed and distressed lots suppress growth cues and instead show sagging silhouettes, cracks, patching or boarded facades, caution ribbon, dry planters, and rubble. Recovery removes those distress props and restores maintained/growth cues.

Neighborhood detail supplies short text labels, city detail strips labels and small props, and block detail reveals the full prop layer. Silhouettes, geometry, props, labels, and motion make every state legible without depending on color. Deterministic coordinate/kind seeds keep variation stable. Unchanged simulation pulses preserve tile-root identity and do not accumulate actions.

## Ordered commits

1. `2400b88b855a5a7a36a8ba2827c71800a4a1fc7e` — `PLAY-020: Make lot lifecycle consequences readable`
2. `3bb03c2ef3784532dcb06d097fb3446bd174d0cb` — preserved merge of the accepted PLAY-010 baseline
3. `9f7a8bd562f949bee05a77e94b5e471d93c9ab81` — preserved merge of Wave 002 authority `efe23ee`
4. `68fcb3e0ce56a691ae2fe5f963e81b65796ef8e6` — `PLAY-020: Bring lot lifecycles to life`

The completion/evidence commit containing this record follows those commits and is reported to integration by exact hash. No history was rewritten, squashed, reset, pushed, or integrated.

## Exact product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotConsequencePresentation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotLifecycleRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`

Only accepted `CityTile` state is consumed: coordinate, kind, construction progress, level, and condition. Occupancy is deliberately not interpreted as prosperity. Legacy Python, simulation rules, analytics, store intent, HUD/views, save services, package topology, and build scripts were not changed.

## Automated validation

- `env CLANG_MODULE_CACHE_PATH=/tmp/citysim-play020-wave2-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/citysim-play020-wave2-swift swift test --package-path Native/CitySimNative --filter WorldRenderingTests`
  - 6 tests passed, 0 failures in 2.330 seconds.
  - Covers authoritative-field mapping, four construction silhouettes, maintained/stressed/distressed/recovered states, camera layers, deterministic proof export, motion, Reduce Motion, unchanged-pulse reuse, and lifecycle-band-only invalidation.
- `env CLANG_MODULE_CACHE_PATH=/tmp/citysim-play020-wave2-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/citysim-play020-wave2-swift swift test --package-path Native/CitySimNative`
  - 51 tests passed, 0 failures in 33.039 seconds.
- `bash -n script/build_and_run.sh`
  - Passed with no output.
- `./script/build_and_run.sh --verify`
  - Built the staged bundle, launched `dist/CitySim.app`, and verified the process remained alive.
- `git diff --check`
  - Passed with no output.

## Renderer and motion diagnostics

- Full 24×24 world: 576 initial tiles, 10,373 nodes, 5,760 tile-root reuses across ten unchanged pulses, 0 updates, 20.382 ms total / 2.038 ms average, and 10,373 final nodes.
- The preserved checkpoint baseline was 10,309 nodes and 1.808 ms average: Wave 002 adds 64 nodes to this representative scene and measured +0.230 ms per unchanged pulse, with no accumulation.
- Animated lifecycle fixture: 3 active bounded actions, 12 unchanged pulses, 0 updates, stable action count; Reduce Motion rebuilds the affected lot and leaves 0 actions while retaining static props.
- Representative lifecycle fixture: 1,906 nodes / 888 drawables / 0 actions under Reduce Motion; update 8.794 ms.
- Recovery fixture: 1,892 nodes / 873 drawables / 0 actions; update 8.766 ms.
- Existing overlay transition: 64 overlay updates and 1,565 overlay nodes.
- Live observational process snapshots ranged from about 118–237 MiB RSS across fresh, settled, regular, and compact staged instances. These are disclosed observations rather than a stable memory benchmark. Every exact-path process from this worktree was terminated after proof; other lanes' processes were untouched.

## Staged real-app flow

1. Built and launched the exact repository bundle, paused with Space, and observed the city advance from Day 12 to Day 20 with a visible `HEALTHY GROWTH` state in the map and accessibility tree.
2. Zoomed out three steps to city detail and verified lifecycle labels/fine props disappeared while building and construction silhouettes remained readable.
3. Zoomed in four steps to block detail and verified planted frontage and lifecycle props returned, then panned the map by pointer drag.
4. Inspected City Hall and confirmed the Command Center exposed the selected landmark, protected status, and authoritative 100% condition.
5. Entered Build mode, exercised a blocked occupied-tile preview (`Demolish the existing structure before building here.`), placed a valid $120 road tile, observed treasury/cashflow change, and used Undo to restore both with `Last construction action undone`.
6. Enabled the accepted pollution overlay and verified its legend coexisted with selection and valid placement feedback.
7. Relaunched with no competing instance from this worktree and the repo's debug-only `CITYSIM_COMPACT_WINDOW=1` configuration, which calls `setContentSize(900×600)`. The real compact capture is 900×652 pixels including 52 pixels of native window chrome, and its accessibility tree exposes every status metric, speed, notice, build, detail, data-layer, and demand control. The deterministic compact renderer proof is the exact 900×600 content viewport at 2× (1800×1200 pixels).

No Save command was invoked. The only live construction mutation was undone before the staged processes were closed.

## Proof artifacts

Deterministic renderer proof:

- `docs/visuals/citysim-play020-lifecycle.png`
- `docs/visuals/citysim-play020-recovery.png`
- `docs/visuals/citysim-play020-wave2-lifecycle.png`
- `docs/visuals/citysim-play020-wave2-recovery.png`
- `docs/visuals/citysim-play020-wave2-compact.png`
- `docs/visuals/citysim-play020-wave2-city.png`
- `docs/visuals/citysim-play020-wave2-block.png`

Real staged app proof:

- `docs/visuals/citysim-play020-wave2-default-live.jpeg`
- `docs/visuals/citysim-play020-wave2-compact-live.jpeg`
- `docs/visuals/citysim-play020-wave2-city-live.jpeg`
- `docs/visuals/citysim-play020-wave2-block-live.jpeg`
- `docs/visuals/citysim-play020-wave2-overlay-live.jpeg`

## Accessibility, compatibility, and contract consequences

- State remains non-color-only through silhouette, geometry, props, and concise SpriteKit accessibility labels (`CONSTRUCTION`, stage names, `HEALTHY GROWTH`, `STRESS`, and `DECLINE`).
- Reduce Motion removes every lifecycle action while preserving the state-specific static scene.
- Stable visual seeds are independent of simulation seeds. Camera changes use existing detail layers, and unchanged pulses reuse existing nodes.
- No save schema, simulation cadence, analytics, public snapshot, public command, HUD, or view contract changed. No shared-contract proposal is required for this completed slice.

## Truthful limitations and deferred inputs

- Accepted state has no approved per-coordinate utility service, prosperity, or pollution analytics. PLAY-020 therefore adds no renderer-owned spatial claims for those concepts. The existing accepted pollution overlay was exercised but not broadened. Utility trouble, lot prosperity, and localized pollution cues remain blocked on an integration-approved immutable presentation input under CONTRACT-003 or a later contract.
- The accepted live simulation can build and complete lots but does not currently author stressed/distressed/recovered condition transitions for a short staged journey. Those states are proven through the deterministic native renderer fixture using real `CityTile.condition` values; the live app proof demonstrates healthy growth, camera layering, selection, placement, overlay, and undo. No fake transition was added to SpriteKit.
- CONTRACT-004 specifies isolated proof bundles/data roots, but its implementation was not present in this baseline. Before the first staged launch, no CitySim process was present. Later proof launches used the exact worktree bundle path, and shutdown targeted only verified process IDs from this worktree. The completion claim does not represent these launches as contract-isolated.

## Integration note

Integration can merge the branch as-is after `68fcb3e` plus the completion/evidence commit. CONTRACT-003/004 work may land independently: PLAY-020 neither depends on a new snapshot contract nor modifies those surfaces. If future immutable spatial analytics are approved, this renderer should consume them through a typed presentation adapter rather than infer gameplay truth from occupancy or visual state.
