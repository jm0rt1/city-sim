# PLAY-027 Residential L3 scene design checkpoint

## Density story

Residential L3 is a five-floor stepped courtyard mid-rise. Two full-height
brick wings frame a south-open court and are joined by a lower honey-stone
north bridge. Flat parapets, a lower green bridge roof, one small copper roof
pavilion, paired courtyard-wing windows, and balcony stacks replace L2's
cross-gabled walk-up silhouette and rhythm.

## Directional frontage

Each direction owns an explicit scene descriptor, geometry ID, facade entrance
flag, entrance base, frontage edge/socket, prop IDs, and occlusion exclusion.
North and west elect a visible grounded return through a positive lateral
portal offset. East uses a direct wing portal. South places its portal in the
center of the open courtyard threshold. No sibling mirror, rotation, raster
transform, or source reference is declared.

## Frozen contracts

The L1/L2 camera, 72-by-72 footprint, ground pivot, contact polygon, 2:1
projection, northwest light, southeast shadow, and residential material family
remain unchanged. Scene validation reports four unique descriptor hashes, four
unique geometry IDs, 53 explicit window centers per direction, and no failures.

The first render revision is `source-v01`. Rendering may begin only from this
durable input checkpoint.
