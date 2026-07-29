# PLAY-027 Industrial L4 Turbine Works material pre-pixel review

## Requested disposition

Independent pre-pixel review only. This packet is not raw source authority,
normalization authority, renderer ingestion, or production selection.

- `sourceAuthority=false`
- `productionSelected=false`
- SceneKit/Metal source processes: `0`
- normalizer processes: `0`
- ImageGen calls: `0`

## Technical result

- disposition: `PASS_PENDING_INDEPENDENT_PREPIXEL_REVIEW`
- deterministic replay: two complete 16-file trees, byte-identical
- replay tree SHA-256:
  `8f66d5c5f730a5dadeb3a77362d2bf02a46ef40f0487167d2b3c5e80bcf8c048`
- validation SHA-256:
  `24bef8a966f983068b9d94c5617a954c0df899c13d2be3aaf10c34d4f048a41c`
- feasibility SHA-256:
  `b5edb0642f4ad3eed1d9281b27a16166a56a6b9a6183d5c52fa6f71a3aa2d269`
- material library SHA-256:
  `153d5790aac5a2d5eff378929ad394f4e5858c572f0eb9d20eb11d8c0ea36b7f`
- four unique descriptor hashes and four unique canonical geometry hashes
- production `SceneDescriptor` decode: PASS N/E/S/W
- material references: complete
- accepted-catalog descriptor/geometry intersections: empty
- exact footprint, pivot, frontage socket, contact polygon, northwest light,
  southeast shadow, and directional road-edge bindings: PASS
- hall visible-width ratio: `3.6` in all directions
- non-stack maximum height: `22`
- stack silhouette share: `6.21–6.43%`
- roof peaks: `4`
- control-wing/hall height ratio: `0.5`
- three freight openings: `9.3815` compact pixels each
- conservative residency: `5.25 MiB`, 12 sprites, no more than four pages,
  below the `50.3 MiB` ceiling

## Visual review

Inspect the files under `review/` at original size. The author review found:

- the long, low sawtooth high-bay hall remains dominant in N/E/S/W;
- the single offset oxide stack remains subordinate;
- three deep freight openings and the separate warm-brick staff/control wing
  survive at exact `192×128` in color and literal grayscale;
- the weathered warm brick, dark blue-green/charcoal steel, oxidized machinery,
  restrained green, orange process heat, deep recess, apron, and glazing roles
  remain distinct without sterile white/cyan/cream planes;
- the clay overlay preserves the accepted v06 massing;
- the frontage/socket overlays align with each direction's authoritative road
  edge;
- block, neighborhood, and city panels retain a recognizable industrial
  silhouette without a compact-office-tower read.

Please independently inspect:

- `review/SOURCE-COLOR-NESW.png`
- `review/SOURCE-GRAYSCALE-NESW.png`
- `review/CLAY-OVERLAY-NESW.png`
- `review/FRONTAGE-SOCKET-NESW.png`
- `review/BLOCK-COLOR-NESW.png`
- `review/NEIGHBORHOOD-COLOR-NESW.png`
- `review/CITY-COLOR-NESW.png`
- `review/EXACT-192X128-COLOR-NESW.png`
- `review/EXACT-192X128-GRAYSCALE-NESW.png`

The derived-panel failure trail is retained in `REJECTION-TRAIL.md`.
