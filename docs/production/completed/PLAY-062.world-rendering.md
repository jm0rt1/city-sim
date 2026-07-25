# PLAY-062 Directional Industrial L1 Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** ready for independent PLAY-063 disposition; not self-accepted
- **Published authority:** `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`
- **Accepted Industrial L1 source authority:** `79668c347e58d602f9627c73cb09e3272a83ef57`
- **PLAY-063 preregistration:** `b9f2aed` (published independently by integration; not merged into this frozen candidate)
- **Exact product:** `02612e414912fdabcab858b0ca97e1f5edbc2757`
- **Exact evidence:** `7ea9971f58f9c86cb17c1b978c7af3ae9b230cae`
- **Candidate ID:** `world-rendering-w5f893ad1da1b`
- **Bundle ID:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Evidence packet:** `docs/production/evidence/PLAY-062/candidate-02612e4/`

## Ordered task commits

1. `d9494765a162b427de33a0928ea512e956de03e7` — bind the
   renderer-lead ingestion audit to the exact accepted Industrial L1
   source-v05 inventory.
2. `02612e414912fdabcab858b0ca97e1f5edbc2757` — ship deterministic
   Industrial L1 packing, strict catalog loading, authoritative frontage
   selection, three-LOD presentation, and focused tests.
3. `7ea9971f58f9c86cb17c1b978c7af3ae9b230cae` — retain exact
   source/pack/geometry/test/staged/live/accessibility/Reduce Motion/RSS
   evidence.
4. This completion commit adds only this completion record. The
   integration-owned active claim remains unchanged.

## Player-visible outcome

Normal CitySim play now resolves an Industrial L1 lot to one of four distinct
accepted authored sources from its actual adjacent road:

- `industrial_l01_v0_north`
- `industrial_l01_v0_east`
- `industrial_l01_v0_south`
- `industrial_l01_v0_west`

The selected frontage and entrance socket use the same authoritative road
edge. Camera, pointer position, draw order, and local presentation state do not
participate. Multi-road priority remains deterministic
(`south, north, east, west`). Roadless Industrial L1 produces an explicit
bounded missing-identity diagnostic instead of a silent visual fallback.

The renderer does not mirror, rotate, recolor, synthesize, repair, alias, or
borrow a Residential or Commercial asset. Every direction preserves its
independently accepted source-v05 bytes and stable pivot, footprint, socket,
shadow, alpha, and padding.

## Product and pipeline surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-062-industrial-l1-directions.json`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py`

No accepted PLAY-027 source-art byte changed. No gameplay, simulation,
save/schema/fingerprint, public store, command, SwiftUI HUD, accessibility
contract, `Package.swift`, build script, Residential source, Commercial
source, or Industrial L2-L4 surface changed.

## Exact resource identity

- Industrial production selections: 4/4.
- Unique accepted raw source hashes: 4/4.
- Unique normalized city/neighborhood/block hashes: 12/12.
- Industrial/Residential/Commercial normalized-hash intersection: empty.
- Generated-v4 source/staged manifest:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.
- Staged executable:
  `10c15c76b62ce7440e919e770536a7a719c18d5c157e5a713b95fbbc02e6bf2b`.
- Staged candidate manifest:
  `4cc2f86348460eb9282eee0e49fcfd4d7810e4a1741ad83baff4fd3a4d73c584`.

Two fresh generated-v4 builds were byte-identical to one another and the
committed production outputs. The source/staged atlas parity validator passes.
Packing remains deterministic, non-rotating, within four pages, and under the
accepted active-plus-adjacent decoded-byte ceiling.

## Automated validation

- Focused `WorldRenderingTests`: 55/55 passed in 30.506 seconds.
- Full native suite: 226/226 passed in 113.221 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed from exact product `02612e4`.
- Generated-v4 validator: 192 payload digests, 192 extrusion checks,
  5,033 packed-overlap checks, exact source/staged parity, and zero failures.
- Production geometry: `result: pass`; 8,100 reciprocal-ground checks,
  180 building-road checks, and 692 entrance/prop exclusion checks with zero
  collisions.
- Runtime direction, all-LOD identity, frontage, explicit roadless failure,
  unchanged-pulse reuse, save/load, undo, construction, condition, selection,
  overlay, input, accessibility, and Reduce Motion checks pass.

## Exact staged app and live flows

The exact packaged `.app` was operated with Computer Use:

- uncropped regular 1,278×768 decorated window;
- exact 900×600 compact content in an uncropped 900×652 decorated window;
- distinct city, neighborhood, and block captures at both sizes;
- pointer-selected displayed Industrial block 15,12;
- AX-announced `Industrial Level 1 Operational`;
- authoritative south-road frontage for underlying coordinate 14,11;
- keyboard and pointer hit-truth agreement;
- occupied invalid reason and open-land valid placement;
- Return construction commit at 0%, then Undo;
- Save followed by Load with Day 53 paused truth preserved;
- Land Value, Traffic, Utilities, Happiness, and Pollution overlays;
- Focus City with Industrial selection and overlay truth retained; and
- isolated compact Reduce Motion with equivalent static identity, selection,
  and AX meaning.

The packed 4×3 color/grayscale matrix proves all four authored directions at
city, neighborhood, and block LOD. The family comparison materially
distinguishes Industrial from Residential and Commercial in color and
grayscale. These matrices support but do not replace the staged-app journey.

## Budgets

- Cold world update: 3.758 ms.
- Cold asset decode: zero loads / 0.000 ms.
- Cold total render: 5.384 ms.
- Default: 1,407 nodes / 594 drawables.
- Exact compact: 1,383 nodes / 570 drawables.
- Thirty-minute-equivalent unchanged-pulse soak: 4,286 pulses, stable
  identity, two bounded actions, 0.0006 ms average.
- Repeated-LOD high-water: 41,943,040 decoded bytes; zero fallbacks.
- Regular live RSS after repeated LOD cycling: 183,824 KiB.
- Exact compact Reduce Motion live RSS: 135,696 KiB.
- All live samples are below the 333.8 MiB ceiling.

## Limitations and handoff

The authoritative live save contains an Industrial L1 lot with a road directly
south. The staged app therefore proves real south-facing frontage and the full
interaction lifecycle. North/east/west are proved by the exact candidate
packed matrix and exhaustive runtime/geometry tests rather than a fabricated
save.

Industrial L2-L4 remain unmodified and unclaimed. No shared-contract proposal
is required.

Hand the clean exact candidate to independent PLAY-063 for disposition. This
lane does not self-score, self-accept, push, or integrate.
