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

## Source-v03 four-view set

**Disposition:** rejected after normalization

All four raw sources passed byte identity against two additional native
processes per direction. Raw validation passed four unique pixels, opaque
chroma fields, flat corners, and common non-chroma bounds. The unchanged
deterministic normalizer also produced twelve unique, repeatable LOD files.
Native validation then found three visible magenta-spill pixels in each block
LOD. Neighborhood and city LODs had zero spill, but the block failure rejects
the complete normalized set.

All raw, normalized, renderer, normalizer, and validation evidence is retained.
The nearest-entry repair changed the established palette and exposed the edge
regression. The next repair keeps the established midpoint palette but shifts
its bucket boundary by eight values, which still converges the observed
`191/192` unstable pair. No geometry, material, camera, light, shadow,
registration, normalizer, or review-tool change is permitted. The coherent set
advances to `source-v04`.

## Source-v04 four-view set

**Disposition:** technically valid; rejected at local art review

The full raw and normalized set passes repeat-run identity, unique hashes,
alpha, chroma, padding, and source registration checks. Exact native-2x and
zoomed normalized-alpha sheets show clear east and south walk-up entrances.
North and west fail the level gate: each hidden road-facing plane exposes only
a narrow return frame, so the grounded door itself disappears at game scale.
That is two direction failures and freezes L2 for local redesign.

All v04 raw, normalized, provenance, validation, and six-sheet review evidence
is retained. The redesign adds a real green door, warm surround, lintel, and
grounded stoop on each independently authored visible return plane elected by
the north/west lateral offset. It does not move the contracted frontage socket,
pivot, contact polygon, camera, light, shadow, or shared massing; east and south
retain their direct facade entrances. The coherent set advances to
`source-v05`.
