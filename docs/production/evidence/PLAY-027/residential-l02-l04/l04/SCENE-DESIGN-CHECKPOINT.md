# PLAY-027 Residential L4 scene design checkpoint

## Density story

Residential L4 is a seven-floor urban residential tower. A two-floor honey
stone podium supports a setback terracotta tower and a lower side wing. A
copper hipped crown, green podium parapet, dark wing roof, strong limestone
belts, narrow vertical window rhythm, and tower balcony stack distinguish it
from L2's cross-gabled walk-up and L3's U-courtyard parapets.

## Directional frontage

Every direction has its own geometry ID, facade entrance flag, frontage
registration, entrance base, lobby clearance, and prop IDs. North and west use
grounded visible return doors from explicit positive lateral offsets. East and
south use direct urban lobbies. No sibling scene, mirror, rotation, or raster
transform is declared.

## Frozen contracts

The 72-by-72 residential footprint, contact polygon, ground pivot, fixed
orthographic camera, northwest light, southeast shadow, and family material
library remain unchanged. Scene validation passes four unique descriptors,
four geometry IDs, 81 explicit window centers per direction, and no failures.

The first render revision is `source-v01`. Rendering may begin only from this
durable input checkpoint.
