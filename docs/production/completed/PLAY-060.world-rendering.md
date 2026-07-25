# PLAY-060 Commercial Skyline Production Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** ready for independent PLAY-061 disposition; not self-accepted
- **Published authority:** `91f885925fd601786fa95dbb969b71fefef5ddcd`
- **Accepted comparison baseline:** `64dd47500fe5e2d4a32a64f6298ded5789d3b773`
- **Accepted Commercial source authority:** `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`
- **Exact product:** `4473f5a1fe827e143701fea6386299db1116ed45`
- **Exact evidence:** `528f0e03911b521a2100b9191b4864f2be29631d`
- **Candidate ID:** `world-rendering-w5f893ad1da1b`
- **Bundle ID:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Evidence packet:** `docs/production/evidence/PLAY-060/candidate-4473f5a/`

## Ordered task commits

1. `d21a96ede4522b3f0aa568f774a59597b280a7a2` — bind the renderer-lead ingestion audit to the exact independently accepted 16-source Commercial inventory.
2. `4473f5a1fe827e143701fea6386299db1116ed45` — ship deterministic Commercial packing, strict catalog loading, authoritative level/frontage selection, and focused tests.
3. `528f0e03911b521a2100b9191b4864f2be29631d` — retain the exact pack/geometry/test/staged/live/accessibility/Reduce Motion/RSS evidence packet.
4. This completion commit adds only this completion record. The integration-owned active claim is intentionally not edited without integration approval.

## Player-visible outcome

Normal CitySim play now selects one of 16 distinct accepted Commercial sources from two pieces of gameplay truth:

- authoritative Commercial logical level L1 through L4; and
- an actual adjacent road edge north, east, south, or west.

The skyline now progresses from a low main-street storefront through successively taller mixed-use blocks to an unmistakable L4 tower. Each direction has an authored entrance/frontage view. The renderer does not mirror, rotate, synthesize, repair, alias, or borrow a Residential or Industrial asset.

The exact selected logical identity remains stable through unchanged pulses, save/load, undo, camera changes, and city/neighborhood/block LOD. A level or road-frontage change invalidates the affected lot; a roadless Commercial lot produces one explicit bounded diagnostic instead of a silent fallback.

## Product and pipeline surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-060-commercial-directions.json`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/pack_world_atlas.py`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py`

No gameplay, simulation, save/schema/fingerprint, public store, command, SwiftUI HUD, accessibility contract, `Package.swift`, build-script, legacy Python, Industrial source, Residential source, or accepted Commercial source-art byte changed.

## Exact source and resource identity

- Commercial selections: 16/16.
- Unique accepted raw source hashes: 16/16.
- Unique normalized city/neighborhood/block hashes: 48/48.
- Commercial/Residential accepted source-hash intersection: empty.
- Generated-v4 source/staged manifest:
  `c9351451928e035c0631b074d38fc55156325e5fcd19d3ebd4b104c5f90d8aa8`.
- Staged executable:
  `c3203904afbaf08414315735c8fa314ca9e9a7d1fa728f2b5f1a66a5e2f50485`.
- Staged candidate manifest:
  `31b8046de769b61aa225be0f12ecf632957ab11b09f6aea50c1a5d2d11ac0f45`.

Two clean pack builds were byte-identical. Packing remains deterministic, non-rotating, and within the existing four-page ceiling. The source/staged atlas parity validator passes.

## Automated validation

- Focused `WorldRenderingTests`: 52/52 passed in 27.304 seconds.
- Full native suite: 223/223 passed in 108.014 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed from exact product `4473f5a`.
- Bundled-Python generated-v4 validator: passed 180 payload digests, 180 extrusion checks, 4,411 packed-overlap checks, all 16 Commercial identities, all 48 normalized payloads, source/staged parity, and zero failures.
- Bundled-Python production geometry: `result: pass`; 6,724 reciprocal-ground checks, 164 building-road checks, and 628 entrance/prop neighbor-exclusion checks with zero collisions.
- Runtime 4×4 matrix, all-LOD identity, exact frontage, roadless explicit failure, save/load/undo, construction, condition, selection, overlay, input, AX, and Reduce Motion suites all passed.

## Exact staged app and live flows

The exact packaged `.app` was operated with Computer Use in isolated data roots:

- regular uncropped 1,278×768 decorated window;
- exact 900×600 compact app content in its uncropped 900×652 decorated window;
- city, neighborhood, and block captures with distinct hashes;
- pointer-selected displayed Commercial block 14,12;
- AX-announced `Commercial Level 1 Operational`;
- authoritative south-road frontage for underlying coordinate 13,11;
- keyboard Left to road 13,12 and Right back to the same Commercial lot;
- occupied invalid reason and open-land valid placement;
- Return construction commit at 0%, then toolbar Undo;
- Save followed by Load with paused truth preserved; and
- isolated compact Reduce Motion with equivalent static identity and meaning.

The color, grayscale, pre-ingestion, and production 4×4 matrices show the complete L1→L4 and north/east/south/west authored catalog. The matrix is supporting renderer evidence, not a substitute for the staged-app interaction journey.

The accepted `64dd475` park, terrain, street furniture, vegetation, five overlays, and Focus City composition remain visibly intact. PLAY-060 changes no public-realm or HUD surface.

## Budgets

- Cold world update: 3.741 ms.
- Cold asset decode: zero loads / 0.000 ms.
- Cold total render: 5.355 ms.
- Default: 1,407 nodes / 594 drawables.
- Exact compact: 1,383 nodes / 570 drawables.
- Thirty-minute-equivalent unchanged-pulse soak: 4,286 pulses, stable identity, two bounded actions, 0.0006 ms average.
- Generated-v4 repeated-LOD high-water: 41,943,040 decoded bytes; zero fallbacks.
- Regular live RSS after three LOD cycles: 62,528 KiB.
- Compact live RSS after three LOD cycles: 201,696 KiB.
- Compact Reduce Motion live RSS: 275,136 KiB.
- All live RSS samples are below the 333.8 MiB ceiling.

## Limitations and handoff

The current production story corpus contains Commercial lots only at L1. The exact staged app therefore proves real L1 authoritative frontage and the complete interaction lifecycle. The complete L1→L4 and four-direction outcome is proved by the candidate runtime matrix plus exhaustive all-LOD tests rather than a fabricated higher-level save.

No shared-contract proposal is required. Hand the clean exact candidate to independent PLAY-061 for disposition. This lane does not self-score, self-accept, push, or integrate.
