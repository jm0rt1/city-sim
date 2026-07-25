# PLAY-027 Residential L2 source-v05 N/W return redesign

## Trigger

Source-v04 passed all technical gates but failed exact-scale entrance
readability in north and west. Both road-facing door planes are behind the
shared mass from the fixed contract camera. The existing canopy return proved
directional authorship but not a grounded entrance.

## Frozen repair

- North keeps its explicit north facade entrance and positive eastward porch
  offset. That offset now authors an east-facing return door, surround, lintel,
  and stoop at the grounded corner.
- West keeps its explicit west facade entrance and positive southward porch
  offset. That offset now authors a south-facing return door, surround, lintel,
  and stoop at the grounded corner.
- East and south remain direct facade entrances and receive no return geometry.
- Return doors reuse the family green door and warm limestone hierarchy.
- No camera, sibling scene, raster, mirror, rotation, registration, footprint,
  pivot, light, shadow, material library, or normalizer change is allowed.

## Acceptance probe

The next coherent N/E/S/W render is `source-v05`. It must show a grounded green
door and warm stoop for north and west in the normalized-alpha native-2x sheet,
retain clear east and south entrances, and pass repeat-run identity before
normalization. Any further two-direction frontage failure stops L2 again.
