# PLAY-027 Residential L2 attempt rejections

## Source-v01 four-view set

**Disposition:** rejected before normalization

The four independently authored scenes rendered complete three-floor walk-up
massing, a readable corner stair bay, unique pixels, clear east/south
frontages, and grounded north/west frontage returns. The transverse
cross-gable used charcoal slate across too much of the roof, however, creating
another broad dark plane that visually echoed the accepted L1 silhouette
defect this density slice is required to avoid.

All four raw PNGs and provenance records are retained. The geometry, windows,
entrances, props, registration, camera, light, and shadow remain unchanged.
The shared cross-gabled roof advances to green slate on both intersecting
volumes, while only the small corner stair-bay cap changes to copper. All four
scenes advance to `source-v02` before another render.

## Source-v02 four-view set

**Disposition:** rejected before normalization

The roof hierarchy repair passed visual inspection and preserved four unique
raw hashes. Repeat-run validation then exposed one actual channel mismatch in
the east source at source pixel `(793, 807)`: two otherwise identical native
processes produced blue-channel values `176` and `208`. Decoded BMP comparison
proved this was one pixel rather than PNG metadata; north, south, and west were
byte-identical across the same repeated process boundary.

All four raw PNGs and provenance records are retained. The scene renderer's
deterministic quantizer advances from floor-bucket midpoints to nearest
32-value palette entries so the observed SceneKit `191/192` boundary pair
converges. No scene geometry, materials, camera, light, shadow, registration,
or compositor layout changes. The coherent set advances to `source-v03` and
must pass fresh cross-process identity before normalization.
