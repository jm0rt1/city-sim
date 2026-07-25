# PLAY-062 candidate validation

## Identity

- Product commit: `02612e414912fdabcab858b0ca97e1f5edbc2757`
- Published authority ancestor: `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`
- Accepted Industrial L1 source ancestor: `79668c347e58d602f9627c73cb09e3272a83ef57`
- Branch: `codex/citysim-world-rendering`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle identifier: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged executable SHA-256:
  `10c15c76b62ce7440e919e770536a7a719c18d5c157e5a713b95fbbc02e6bf2b`
- Staging manifest SHA-256:
  `4cc2f86348460eb9282eee0e49fcfd4d7810e4a1741ad83baff4fd3a4d73c584`
- Source and staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`

`candidate.manifest` retains the exact bundle, executable, packaged
resource-bundle, preference-domain, data-root, and product identity emitted by
`./script/build_and_run.sh --verify`.

## Source, catalog, and pack

- Exact production identities: 4
  (`industrial_l01_v0_north/east/south/west`)
- Accepted source revision: `source-v05` for every direction
- Unique accepted raw-source hashes: 4/4
- Unique accepted normalized hashes: 12/12
  (`4 directions × city/neighborhood/block`)
- Industrial/Residential/Commercial normalized-hash intersections: empty
- Runtime mirror, rotation, sibling alias, cross-family fallback, and
  source-repair paths: zero
- Industrial L1 production fallback count: zero
- Fresh-build determinism: two output trees byte-identical to each other and
  the committed generated production files; see `DETERMINISTIC-PACK.md`

The retained pack validator
`diagnostics/asset-pack-validation.json` passed:

- 48 total registered assets;
- 192 payload digest checks;
- 192 extrusion checks;
- 5,033 packed-overlap checks;
- 4 Industrial directional identities and 12 unique Industrial payloads;
- source/staged atlas parity; and
- zero failures.

The retained geometry validator
`diagnostics/production-geometry-validation.json` reports `result: pass`:

- 8,100 reciprocal-ground checks / zero collisions;
- 180 building-road setback checks / zero collisions;
- 692 entrance/prop neighbor-exclusion checks / zero collisions;
- zero orphan or missing inventory entries; and
- stable registered pivots, bounds, sockets, shadows, alpha, and padding
  across all three LODs.

Generated pages remain within the accepted four-page ceiling:

| Page | SHA-256 | Decoded bytes |
|---|---|---:|
| `block-00` | `90aeb2c8e56bfc95d8279581ebee60f3dc692e45407aff4e364a0ba087bbff1a` | 33,554,432 block total |
| `block-01` | `9c8c5fa6dce3b31b89ded5a7cac0c3dad822c74092d48c197b3b6c28b3b2d4dc` | included above |
| `city-00` | `7f3ce7f818f49dedabca13046e7f01e837e5d0dd4d12456ee0a9732dcad8e964` | 4,194,304 |
| `neighborhood-00` | `2e35efbac673adb8d8297700c7129dbfc5cb5cc9226149b062bd30011defbef0` | 8,388,608 |

## Native and staged validation

- Focused `WorldRenderingTests`: 55/55 passed in 30.506 seconds; retained at
  `diagnostics/focused-world-rendering-tests.log`.
- Full native suite: 226/226 passed in 113.221 seconds; retained at
  `diagnostics/full-native-tests.log`.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed from exact product `02612e4`.
- Exact generated-v4 content loaded from the staged
  `CitySimNative_CitySimNative.bundle/WorldAssets.atlas`; it was not loaded
  from the build directory.

Focused coverage proves:

- all four Industrial L1 directions resolve to their exact manifest logical
  identity;
- selected frontage and entrance equal the actual adjacent authoritative road;
- multi-road priority is deterministic;
- all three LODs preserve the same source identity;
- unchanged pulses, JSON save/load, condition mutation/restoration, undo, and
  camera/LOD changes preserve or restore identity;
- roadless Industrial L1 fails explicitly rather than choosing an asset
  fallback; and
- Industrial levels L2-L4 retain the pre-existing non-directional behavior
  and were not ingested by this claim.

## Rendering, residency, and timing

Latest focused candidate diagnostics:

- cold backdrop: 0.157 ms
- preparation: 0.009 ms
- tile build: 3.591 ms
- tree metrics: 0.186 ms
- world update: 3.758 ms
- asset decode loads: 0
- asset decode: 0.000 ms
- cold total: 5.384 ms
- golden render: 842 nodes / 376 drawables / 0 actions / 5.405 ms total
- default: 1,407 nodes / 594 drawables
- exact compact: 1,383 nodes / 570 drawables
- unchanged-pulse soak: 4,286 pulses, 1,407 nodes, 594 drawables, 2 bounded
  actions, 0.0006 ms average
- generated-v4 repeated-LOD high-water: 41,943,040 decoded bytes
- generated-v4 fallbacks: 0

Hands-on staged RSS:

- regular after repeated LOD cycling: 183,824 KiB
- later settled regular sample: 86,592 KiB
- exact compact Reduce Motion after load and Industrial selection:
  135,696 KiB

Every live sample is below the established 333.8 MiB ceiling.

## Visual identity

`matrix/industrial-l1-production-4x3-color.png` and its grayscale companion
crop the exact committed packed atlas rectangles. They prove distinct authored
north/east/south/west views at city, neighborhood, and block LOD with no
runtime transform.

`matrix/l1-family-south-color.png` and its grayscale companion compare the
same-direction Residential, Commercial, and Industrial L1 production sources.
Normalized image differences remain material:

- Residential versus Industrial: color RMS
  `[52.368168, 31.732202, 20.996122]`; grayscale RMS `34.826606`
- Commercial versus Industrial: color RMS
  `[81.103335, 55.542588, 32.979724]`; grayscale RMS `59.506325`

These sheets are supporting pack evidence. The staged app evidence remains the
acceptance-relevant proof.

## Honest limitation

The authoritative story/save state used for hands-on proof contains an
Industrial L1 lot with a road directly south. The exact staged app therefore
proves real south-facing frontage plus the complete selection/build/undo/
save-load/overlay lifecycle. North/east/west are proved by exact candidate
packed matrices and exhaustive runtime/geometry tests rather than fabricated
gameplay state.

Industrial L2-L4 remain explicitly outside PLAY-062. No shared-contract
proposal is required.
