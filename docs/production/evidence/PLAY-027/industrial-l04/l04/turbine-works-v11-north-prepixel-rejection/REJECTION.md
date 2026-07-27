# PLAY-027 Industrial L4 North v11 pre-pixel rejection

- Base: `5171f490453686acd2c9fedd88ef71f4236bf4e5`
- Revision: `source-v11-prepixel`
- Disposition: `REJECTED_PREPIXEL_GATE`
- Layout attempts consumed: `2 / 2`
- Source authority: `false`
- Production selected: `false`
- Raw / SceneKit / Metal / normalizer processes: `0 / 0 / 0 / 0`

## Binding outcome

Neither permitted layout makes four sawtooth maxima and three valleys readable
in the complete stack-excluded building silhouette at literal 192×128. Both
retain one connected roof component, the v10 palette and shared spring/eave,
valid freight/staff semantics, unchanged registration, and passing roof-only
geometry/luma gates. Both fail the independent-viewer gate without relying on
the diagnostic roof mask.

### Layout 01 — full-depth widened band

- Descriptor SHA-256:
  `d3e1005f7700a4976d404f330d2148cc4ac53bb3d8829b34fd94aa92df57ebce`
- Material SHA-256:
  `39ca58e2b8f854c198f0fc713be363673d03c4ae91664232840c6770b11e71e0`
- Canonical geometry SHA-256:
  `bf313f2e55bfb9624ff3a4ad821c6e757e27a44bc5e08ce7eb3582c67bea8882`
- Peak spacing: `6.28571477175123–6.285714771751245` compact pixels
- Roof-only valley depth: `[11, 11, 11]`
- All-building peak top Y: `[72, 72, 73, 71]`
- All-building valley top Y: `[71, 74, 72]`
- All-building valley depth: `[-1, 1, -1]`
- Failure:
  `allBuildingFourVisibleMaxima`,
  `allBuildingValleysAtLeast2Deep`

The widened 44-world-unit, 14-world-unit-amplitude band clears the lowered rear
mass analytically by `11.8975` compact pixels, but its full-depth projected
planes overlap in the North camera and do not form four top extrema.

### Layout 02 — camera-facing shortened tooth depth

- Descriptor SHA-256:
  `4c2d2d85f1e90d5788784dce4b256c1a9c49a204501b1dbca80413d6978ae02e`
- Material SHA-256:
  `39ca58e2b8f854c198f0fc713be363673d03c4ae91664232840c6770b11e71e0`
- Canonical geometry SHA-256:
  `ae02d353b80b15890501bae8397f8d341d0825a775077ed085979869b4d6bb38`
- Peak spacing: `6.28571477175123–6.285714771751245` compact pixels
- Roof-only valley depth: `[11, 11, 11]`
- All-building peak top Y: `[73, 76, 74, 71]`
- All-building valley top Y: `[73, 76, 73]`
- All-building valley depth: `[-3, 0, -1]`
- Failure:
  `allBuildingFourVisibleMaxima`,
  `allBuildingValleysAtLeast2Deep`

Shortening the visible tooth depth from 18 to 10 world units reduces overlap
but does not restore the required complete-building top cadence. Literal
exact-192 color and grayscale remain generic-warehouse ambiguous.

## Preserved invariants

Both attempts retain:

- one connected roof component;
- three integrated roof-only valleys at least 2 pixels wide and deep;
- roof/hall luma separation `31`;
- northwest/southeast slope separation `25`;
- staff entrance `5×7`;
- combined freight region `35×18`;
- 56×56 footprint, pivot `[768,896]`, socket `[896,704]`;
- unchanged v10 palette roles, L-shaped court, freight, staff, stack, contact,
  light, shadow, envelopes, and atlas budget.

## Architectural limitation

The axis-aligned continuous-band primitive extrudes each sawtooth slope through
depth. Under the fixed 45° North camera, those projected planes and the
remaining hall envelope overlap the complete-building top boundary. Roof-only
points remain mathematically distinct, but the player-visible top silhouette
does not.

Correcting this requires a separately authorized roof primitive/profile or a
more fundamental North composition that exposes four extrema in the actual
camera. Widening thresholds, using the roof-only mask as authority, or further
coordinate nudging would not satisfy the player-recognition requirement.

No further layout, descriptor repair, raw render, normalization, resolver,
sibling, renderer, shipping, package, product, push, integration, authority,
or self-acceptance work was performed.
