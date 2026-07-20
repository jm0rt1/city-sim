# PLAY-022 Checkpoint — Authored Strategy Districts

- **Status:** blocked; not ready for integration
- **Authority baseline:** `3e8ffe405b00783121c08a06fadc7e0335d7d7aa`
- **Renderer checkpoint:** `842f04381c07ae8f8dbf2b43a424bee87299b499`
- **Commit title:** `PLAY-022: Author strategy district progression`
- **Branch:** `codex/citysim-world-rendering`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Staged executable:** `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`

## Coherent visual outcome

Commercial and industrial lots no longer choose one unrelated silhouette and
fake density by stretching it. Each family now has three authored density tiers
and three coordinate-stable variants per tier:

- commercial: main-street shop rows, courtyard mixed blocks, and stepped tower
  districts with podiums, roof crowns, and skybridges;
- industrial: fabrication sheds and yards, warehouse/silo logistics forms, and
  process campuses with tanks, stacks, and pipe gantries.

Six density-specific parcel treatments reinforce pedestrian-scale commercial
paving versus hardened industrial yards without relying on recolor or labels.
One decorative commercial banner or industrial windsock adds bounded,
weather-like motion per completed strategy lot; Reduce Motion preserves its
static silhouette with zero action. All identity derives only from authoritative
`kind`, clamped `level`, and coordinate seed.

The retained shipping-renderer frames show a clear non-color architectural
delta: commercial lots read as narrow frontage and vertical mixed blocks, while
industrial lots read as low-wide sheds, loading forms, sawtooth roofs, tanks,
and yards. This is a credible renderer-local improvement, but it is not
self-accepted as the complete PLAY-022 visual leap because the required live
window comparison could not be captured.

## Exact scope

Checkpoint `842f043` changes only world-rendering-owned surfaces:

- `Rendering/AmbientLifeRenderer.swift`
- `Rendering/LotRenderer.swift`
- `Rendering/StrategyDistrictVisualIdentity.swift`
- `Resources/WorldAssets.atlas/manifest.json`
- 18 `place_commercial|industrial_tier_*` PNG assets
- 6 `strategy_ground_commercial|industrial_tier_*` PNG assets
- `WorldRenderingTests.swift`
- `WorldArt/generate_world_assets.py`
- `WorldArt/README.md`
- `docs/production/evidence/PLAY-022/ART-DIRECTION.md`

Atlas schema 2 records original repository-owned Pillow geometry, no external
sources, no sampled concept pixels, stable SHA-256 values, and the existing JFM
Systems repository license. A second generator pass produced no additional
diff, proving deterministic regeneration.

No gameplay, simulation, snapshot, store, SwiftUI, command, package, save,
fingerprint, build-script, or legacy Python surface changed.

## Automated validation

- Focused `WorldRenderingTests`: 16/16 passed in 61.720 seconds.
- Complete native suite: 94/94 passed in 222.875 seconds.
- `bash -n script/build_and_run.sh`: passed.
- Exact `./script/build_and_run.sh --verify`: passed at checkpoint `842f043`;
  staged PID 5048 was verified against the executable above and later stopped
  exactly.
- `git diff --check`: passed before checkpoint commit.
- Thirty-minute-equivalent unchanged soak: 4,286 pulses, 9,014 nodes, 2,430
  drawables, 5 bounded actions, 0 updates, 3,890.397 ms total / 0.9077 ms
  average in the full suite. The independent focused run measured 0.8790 ms
  average with identical node/draw/action counts.
- Ten unchanged full-world pulses reused 5,760 tile roots, updated 0, and
  averaged 1.719 ms.
- Reduce Motion coverage proves zero strategy/lifecycle ambient actions while
  retaining the static non-color architecture and district dressing.
- Existing renderer tests continued to pass road topology, city/neighborhood/
  block LOD, default/compact framing, tile-root reuse, one-tile invalidation,
  overlay-root preservation, construction/condition distinction, selection,
  placement, and hit-testing contracts.

## Evidence that actually exists

- `renderer-strategy-block.png` — deterministic 1,280 x 800 shipping `CityScene`
  block-detail render, SHA-256
  `2a4a542d9ade8331741bc2d024320b0a1ed5910a16c2e4a35d4b5d1cdd832373`.
- `renderer-strategy-compact.png` — deterministic 900 x 600 shipping `CityScene`
  compact render, SHA-256
  `ab599d3d681e2e86953c6870b45453eb19bab3504768c7e1a10c4f619fd03cd8`.
- `ART-DIRECTION.md` — truth, LOD, interaction, deterministic identity, and
  budget boundaries.

These PNGs use the same `CityScene`, `LotRenderer`, and bundled atlas as the app,
but they are renderer-harness frames, not drawable-window screenshots. They do
not satisfy the required same-live-city before/after gate by themselves.

## Live gate failure

The staged app launched successfully and exact PID 5048 remained alive for the
proof attempt. Computer Use could list the exact running bundle, but
`get_app_state` did not return its accessibility tree or screenshot:

1. The first exact-bundle call remained unresponsive until the tool call was
   externally aborted after 5,557.3 seconds.
2. After resetting and successfully reinitializing the Computer Use runtime,
   `list_apps` again found `CitySim [World w5f893ad1da1b]`; the second exact
   `get_app_state` remained unresponsive and was aborted after 26.6 seconds.

No live default screenshot, live 900 x 600 screenshot, same-city live
before/after pair, live city/neighborhood/block sequence, interaction-priority
journey, Reduce Motion live screenshot, accessibility tree, or live RSS reading
is claimed. PID 5048 was stopped only after the failed capture attempts.

## PLAY-041 dependency

PLAY-022 deliberately does not depict localized utility trouble, pollution,
prosperity, strain, or recovery. The proposed PLAY-041 snapshot contract is not
yet approved and integrated. Renderer consumer review requested authoritative
`powerBand`, `waterBand`, `combinedBand`, and `pollutionBand` values and an
explicit rule for vitality events that cross `notApplicable`; otherwise the
renderer/UI would duplicate truth thresholds.

After the approved contract reaches the integration baseline, PLAY-022 must
consume its immutable per-coordinate samples/events, add non-color consequence
layers, rerun deterministic/reuse/performance tests, and prove real live
three-act evolution without fixture mutation.

## Blockers and disposition

Two independent blockers remain:

1. the required real-window evidence/control path is currently unresponsive for
   this exact app despite a successful staged launch;
2. factual consequence rendering is gated on approved and integrated PLAY-041
   spatial truth.

The architectural checkpoint is coherent, committed, and suitable for
integration review as partial progress only. PLAY-022 remains blocked and must
not be marked ready or complete.
