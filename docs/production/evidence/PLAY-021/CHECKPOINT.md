# PLAY-021 Checkpoint — Golden-Neighborhood Product Candidate

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** active; product and automated validation complete, live acceptance blocked
- **Integration authority:** `b8cb4740b9cf94aa04482539f9909ffb22dbdbea`
- **Tested product HEAD:** `06496584b2d8eb7b69e9d1c04995bd1dace5348a`
- **Claim:** `docs/production/claims/PLAY-021.world-rendering.md`

PLAY-021 is not ready for integration yet. The exact candidate builds and all
84 native tests pass, but the current macOS session supplies no drawable app
window. The required AFTER live evidence and hands-on flows therefore remain
open. Renderer-generated frames below are evidence for the world component;
they are not represented as real-app acceptance.

## Ordered commits

1. `7e52d3c92a5c2f895685234787b18395474fe5b6` — `PLAY-021: Preserve the rejected world baseline`
2. `a2d7b2e79088e4b9d67c753f2902e769a599b538` — `PLAY-021: Establish the authored world atlas`
3. `57a4d5209b1f3e122a33ecc7ef6fbbc5a4ffe182` — `PLAY-021: Author connected streets and frontages`
4. `ba91fd5f8447ebcd563f708575ee54e9c1f3ba5f` — `PLAY-021: Replace icon lots with authored places`
5. `35baf027f30f424169bb6a537a05685a0d194649` — `PLAY-021: Frame the authored neighborhood`
6. `c51855e7a2ba981137921cb8769b0fff2339d429` — `PLAY-021: Make city outcomes live in the architecture`
7. `06496584b2d8eb7b69e9d1c04995bd1dace5348a` — `PLAY-021: Preserve renderer diagnostics through framing`

No existing PLAY-020 history was rewritten, squashed, reset, pushed, or
integrated. Both `b8cb474` and repaired product ancestor `f9b54fc` are ancestors
of the candidate.

## Product outcome

- A repository-owned SpriteKit resource pipeline now loads a reproducible
  `WorldAssets.atlas` through `Bundle.module`, with linear-filtered textures and
  procedural fallbacks.
- Authored terrain has quieter seeded breakup, a map edge, and sparse detail.
- All 16 road masks form one curb/sidewalk/asphalt/lane/crosswalk language.
  Adjacent lots use road-oriented residential, commercial, industrial, park,
  or civic frontage.
- Residential, commercial, industrial, park, and civic families each ship
  three stable seeded variants with distinct silhouettes, shadows, entrances,
  windows, landscaping, and family-specific props.
- The real starting camera centers the developed bounds at block detail while
  preserving road arms and buildable expansion context. Compact uses a slightly
  wider block-detail lens. City, neighborhood, and block LODs retain stable
  tile roots.
- Construction, growth, decline, and recovery read without floating lifecycle
  labels. Construction uses site silhouettes, excavation, rebar, frame,
  scaffold, crane, progress, and props. Growth uses the accepted level
  silhouette plus renovated facade, pennants, and chevrons. Decline uses a
  sagging profile, patchwork, boarding, dry planters, and rubble. Recovery
  removes those cues and restores maintained frontage and facade activity.
- Ambient life is limited to bounded deterministic vegetation drift on parks
  and residences. It makes no traffic, employment, service, prosperity,
  pollution, or utility claim. Reduce Motion retains the static leaves and all
  state-specific geometry while removing actions.
- Selection, hit testing, placement previews, overlays, camera input,
  incremental tile reuse, and the accepted simulation/store/save contracts are
  preserved.

## Original asset provenance

All shipping world pixels are original repository-owned output from:

- `Native/CitySimNative/WorldArt/generate_world_assets.py`
- `Native/CitySimNative/WorldArt/README.md`

The deterministic Pillow generator creates 46 PNGs plus `manifest.json` in:

- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/`

The atlas is 196 KiB on disk (184 KiB of PNGs). It includes terrain materials,
16 connected-road masks, five frontages, and fifteen three-variant place-family
sprites. `Package.swift` contains only the narrowly pre-approved world-resource
registration. The Imagegen art-direction reference is non-shipping, is clearly
identified in `BEFORE.md`, and contributed no sampled pixels.

## Automated validation

- Focused `WorldRenderingTests`: 12 passed, 0 failures in 61.857 seconds before
  the diagnostics correction; all 12 also passed as part of the final full run.
- Full native suite at `0649658`: 84 passed, 0 failures in 217.719 seconds.
- Exact isolated staged build: `./script/build_and_run.sh --verify` succeeded
  with bundle identifier `com.jfmortensen.citysim.world-rendering` and isolated
  data root `dist/test-data/world-rendering`.
- `git diff --check`: passed.
- First-render creation diagnostics remain intact after camera framing.
- A road mutation intentionally invalidates the road, its connected road
  neighbor, and the adjacent authored frontage; all other tile roots reuse.

## Renderer and performance evidence

- Full 24 x 24 world: 576 tiles, 8,704 nodes, 2,184 drawables, and 3 bounded
  actions. Ten unchanged pulses reused 5,760 tile roots, updated 0, and held
  8,704 final nodes. Measured time was 16.689 ms total / 1.669 ms average.
- Accepted PLAY-020 comparison: 10,373 nodes and 2.038 ms average. PLAY-021 is
  1,669 nodes lower (16.1%) and 0.369 ms faster per unchanged pulse (18.1%).
- Representative construction/decline fixture: 1,594 nodes / 570 drawables /
  0 actions under Reduce Motion. PLAY-020 was 1,906 / 888 / 0.
- Representative recovery fixture: 1,590 nodes / 563 drawables / 0 actions.
- Golden block fixture: 1,358 nodes / 480 drawables / 0 actions under Reduce
  Motion; measured update 4.942 ms.
- Animated fixture: 5 bounded lifecycle/vegetation actions; 12 unchanged pulses
  produced 0 updates and no action accumulation; Reduce Motion produced 0
  actions.
- Thirty-minute equivalent soak: 4,286 unchanged pulses, stable tile identity,
  8,704 nodes, 2,184 drawables, 3 actions, 3,769.451 ms total / 0.8795 ms average.
- RSS is not yet accepted as comparable live evidence. The prior fresh product
  sample was 191,104 KiB versus the fresh rejected baseline's 139,344 KiB. The
  final launch later reached about 537,120 KiB while SpriteKit repeatedly
  reported that no drawables were available; that no-window session is recorded
  as an environment failure, not a shipping memory benchmark.

## Preserved BEFORE evidence

- `before-default-live.jpeg` — source `b8cb474`, SHA-256
  `ebb7a395c3d1d3e196144c2e92c68f4bb52ad350e2d58e99a2e3f7d75e85e858`
- `before-same-camera-live.jpeg` — source `b8cb474`, SHA-256
  `7add34095886f20165065267abbdde8521f336f4ed697978136ad7ee52ef353d`

Immutable PLAY-020 default, compact, city, and block references and their hashes
are recorded in `BEFORE.md`. None were modified or relabeled as later UI proof.

## Candidate renderer proof

Golden-neighborhood LOD and compact frames:

- `golden-city.png`
- `golden-neighborhood.png`
- `golden-block.png`
- `golden-compact.png`

Lifecycle frames:

- `lifecycle-construction-decline.png`
- `lifecycle-recovery.png`
- `lifecycle-city.png`
- `lifecycle-block.png`
- `lifecycle-compact.png`

Their SHA-256 values are stable in the milestone commit and can be recomputed
with `shasum -a 256`.

## Exact remaining live gate

The candidate process launches and stays alive, but the current GUI session is
not usable for acceptance:

- System Events reports `visible=true`, `frontmost=false`, and `0` windows for
  `CitySimNative`.
- App logs repeatedly report `SKView: no drawables available for rendering.`
- `/usr/sbin/screencapture` fails with `could not create image from display`.
- Activating the exact bundle does not produce an accessible window.

No AFTER live image has been created. Completion still requires the exact
candidate staged app at default and 900 x 600, same-camera comparison, city /
neighborhood / block LOD, overlay, selection, valid and invalid placement,
Reduce Motion, accessibility inspection, and a comparable drawable-window RSS
sample. The claim remains active until those flows pass visual review.

## Truthful contract limitation

Accepted state still has no approved per-coordinate utility service,
prosperity, or pollution analytics. PLAY-021 does not infer or fake those facts.
Localized utility trouble, prosperity, and pollution architecture cues remain
blocked on an integration-approved immutable spatial presentation input. The
accepted pollution overlay remains available and must be exercised in the
pending live flow; no new snapshot or simulation contract is proposed here.
