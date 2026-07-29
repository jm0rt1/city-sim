# PLAY-073 authored-district checkpoint

## Disposition

This is a durable renderer checkpoint, not PLAY-073 completion or
self-acceptance. Product commit
`53c0ee1c5214eddd57488080e6f54551b00ca411` materially improves the occupied
district ground, parcel-to-road frontage, adjacent lot treatment, terrain seam
behavior, and deterministic developed-core camera. It preserves authoritative
roads, lots, frontage, hit geometry, overlays, selection, and generated-v4
identity.

The exact regular and compact three-LOD packet remains available for combined
integration review. The regular default composition is substantially stronger,
but the compact default still has an unresolved cross-lane aperture problem:
the renderer receives a stale/deep bottom inset consistent with the details
surface while the visible command deck is closed. Fitting the complete
authoritative priority bounds to that supplied 226-point map aperture creates
the rejected toy-island frame retained under `rejected/`; retaining the
district scale can place its north/south extent beneath persistent HUD chrome.
PLAY-073 does not classify either result as accepted.

## Exact identity

- Base authority: `e38059e721dae05c8df421754e3cb63ddf3fa153`.
- Baseline evidence: `8f33580be7189b74303548b6cd872e3bbd8dabc5`.
- Product checkpoint: `53c0ee1c5214eddd57488080e6f54551b00ca411`.
- Candidate ID: `world-rendering-w5f893ad1da1b`.
- Executable SHA-256:
  `269ed90c0e870fe6a8e95ad144f9178d71ca1ee7edeeac75db1f139c0e5858a9`.
- Staging manifest SHA-256:
  `31ed8104e3e538d5ded697a74b16ddc0589df65d3e20318e5a1c0d48e5c0afb2`.
- Source/staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.
- Frozen Day-33 quicksave SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`.

`bash -n script/build_and_run.sh` and
`./script/build_and_run.sh --verify` passed. Every live route used a separate
process and isolated data root, invoked Command-O, verified Day 33 paused,
`$34,037`, 332 residents, Freight strategy, and 12 notices, then allowed the
load toast to expire.

## Renderer validation

`swift test --package-path Native/CitySimNative --filter WorldRenderingTests`
passed 60/60 on the product checkpoint.

- Representative nodes/drawables: 1,500 / 673.
- Compact nodes/drawables: 1,476 / 649.
- Active generated-v4 residency: 3 textures / 41,943,040 bytes.
- Generated-v4 fallback count: 0.
- Governed cold world update: 4.642 ms.
- Total render: 7.809 ms.
- Thirty-minute-equivalent unchanged-pulse average: 0.0006 ms.

## Same-state LOD evidence

Regular uncropped 1278 x 768 frames:

- `live/regular/city.png` at `0.85`;
- `live/regular/neighborhood.png` at `0.65`;
- `live/regular/block.png` at `0.50`.

Compact routes retain uncropped 900 x 652 decorated windows and exact
900 x 600 content crops:

- `live/compact/city-*` at `0.576345682144165`;
- `live/compact/neighborhood-*` at `0.52`;
- `live/compact/block-*` at `0.45`.

Full AX trees accompany every route. `DEVELOPED-OCCUPANCY.csv` applies the
frozen baseline method. The same-camera increase is modest at regular City LOD
and material at compact LOD; it does not by itself close the city-not-board
visual gate.

## Compact camera ownership finding

The current renderer golden records the industrial priority bounds as
`(-144, -522, 288, 215.42871094)`.

- Regular 1280 x 800: scale `0.39217203855514526`, priority occupancy
  `0.59608083 x 1.02485439`.
- Compact 900 x 600 with `top 138 / bottom 236`: scale
  `0.576345682144165`, priority occupancy
  `0.57969850 x 1.65391086`.

The closed compact HUD contract separately expects approximately
`top 136 / bottom 116`; the staged closed-deck frame visibly exposes more map
than the 226-point aperture implied by `138 / 236`. A renderer experiment that
trusted the deeper insets required scale `1.08512497` and collapsed the city
into a toy island. A closed-aperture experiment required scale `0.70470756`
and crossed to City LOD, producing the same visual failure. These are retained
as rejected evidence, not product behavior.

The renderer cannot safely guess which UI chrome is visible. Integration must
exercise this exact candidate with PLAY-074 so the supplied viewport inset
matches the true visible SpriteKit aperture. Until then, compact district-end
visibility is explicitly unresolved.
