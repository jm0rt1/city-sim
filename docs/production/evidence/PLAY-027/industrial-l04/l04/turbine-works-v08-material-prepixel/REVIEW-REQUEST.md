# PLAY-027 Industrial L4 Turbine v08 pre-pixel review request

Disposition requested: independent renderer and QA review of a non-authority
pre-pixel candidate.

`sourceAuthority=false` and `productionSelected=false`.

## What changed

All review pixels now come from the persisted descriptor geometry and exact
fixed map camera. The footprint, pivot, authored edge, socket, door base,
northwest key, and southeast shadow are projected from those same records.

East and South preserve the technically sound v07 composition. North is an
independent L-shaped foundry with a road-connected loading court. West is an
independent side-loaded foundry court. Each uses three stepped freight faces
and a separate staff entrance; neither is a sibling transform.

The freight material remains the darkest occupied role while moving above the
crushed compact threshold. Orange process heat is unchanged and subordinate.

## Binding results

- two complete replays: byte-identical required 16-file subset and byte-identical
  22-file extended trees
- four unique descriptor hashes and four unique canonical-geometry hashes
- production decode: 4/4
- missing material references: 0
- pivot/contact and footprint projection error: less than 0.00002 source pixel
- socket-to-edge-midpoint error: 0 pixels
- door-base projection error: at most 0.000000000000114 source pixel
- N/E/S/W exact-192 median luminance: 68 / 66 / 68 / 68
- N/E/S/W opaque share at luminance 32 or below: 0 / 0 / 0 / 0
- every freight semantic region: at least 8 compact pixels wide and 8 high
- every staff semantic region: at least 2 compact pixels wide and 4 high
- accepted clay hall ratio: N 4.35, E 3.60, S 3.60, W 4.35
- stack share: 4.6% to 5.5%
- hard gate failures: 0

## Review sheets

- `review/SOURCE-COLOR-NESW.png`
- `review/SOURCE-GRAYSCALE-NESW.png`
- `review/EXACT-192X128-COLOR-NESW.png`
- `review/EXACT-192X128-GRAYSCALE-NESW.png`
- `review/BLOCK-COLOR-NESW.png`
- `review/BLOCK-GRAYSCALE-NESW.png`
- `review/NEIGHBORHOOD-COLOR-NESW.png`
- `review/NEIGHBORHOOD-GRAYSCALE-NESW.png`
- `review/CITY-COLOR-NESW.png`
- `review/CITY-GRAYSCALE-NESW.png`
- `review/CLAY-OVERLAY-NESW.png`
- `review/FREIGHT-STAFF-VISIBILITY-NESW.png`
- `review/FRONTAGE-CONTACT-NESW.png`

Please judge the actual compact color and grayscale hierarchy, the independent
N/W courtyard readability, freight depth, separate staff identity, four-peak
roof rhythm, subordinate stack, and exact descriptor-to-registration proof.
Raw-source generation remains unauthorized.
