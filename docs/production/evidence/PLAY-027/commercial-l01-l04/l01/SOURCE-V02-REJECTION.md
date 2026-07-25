# PLAY-027 Commercial L1 source-v02 rejection

**Disposition:** rejected before normalization

**Production selected:** no

The transaction flush, fixed scene time, synchronous preparation, and two
discarded warm-up snapshots did not produce deterministic output. Three fresh
processes per direction alternated between two byte and canonical-pixel hashes
for every N/E/S/W source. The stable drift occupies the same narrow vertical
corner region in all four views.

The common building descriptor reveals the cause: the
`c01-corner-stone-pier` spans exactly to the main mass's east and north outer
planes. Its stone faces are coplanar with the brick faces across the full
height of the pier, so SceneKit may select either surface as the depth winner.
That also explains why the defect follows the identical building object
rather than a direction-specific camera or frontage definition.

All three raw/process records are retained. The four
`SOURCE-V02-RAW-REPEAT-{direction}.json` reports are binding failures, while
`SOURCE-V02-RAW-UNIQUE.json` confirms that the retained run-A directions still
have unique source pixels.

No source-v02 image is normalized, selected, ingested, packaged, or shipped.
The next revision must separately advance all four scene descriptors and move
the corner pier's authored outer planes beyond the main mass so no coplanar
brick/stone surface remains. Warm-up handling remains as a conservative
exporter prerequisite, but it is not treated as the determinism repair.
