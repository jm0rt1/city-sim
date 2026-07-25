# PLAY-027 third calibration attempt rejections

## North source-v05

**Raw SHA-256:** `de300e8472cab771dae48ebbdfbd4100df62c14145fda3c4bc6b00722aaa6bdf`

**Disposition:** rejected before sibling rendering

The lowered roof and warmer material hierarchy worked as intended, but the
22-world-unit north porch remained centered behind the near building mass.
Only a thin far edge survived while the unrelated near-side bay projection
became the dominant grounded feature. At native scale this would not identify
the north road-facing frontage.

The raw PNG and provenance record are retained. The repair advances only the
north scene to `source-v06` / geometry v5 and adds an explicit positive
14-world-unit porch lateral offset. The 30-world-unit porch still overlaps the
declared north door but extends around the east corner where its deck, roof,
columns, and rails can remain grounded and visible. West receives the same
independently declared southward return before its first v03 render. No sibling
raster or scene is mirrored, rotated, or transformed.

## North source-v06

**Raw SHA-256:** `564ffd29f7213e1262a28a22764d05d12ae391999c91f1c25d50d0324102dc4b`

**Disposition:** rejected as a deterministic source-tool failure

The first porch-return render retained only the porch edge and shadow. A
diagnostic render bypassing the new matte-safe object pass reproduced the
complete building and the grounded return, isolating the defect to an invalid
alpha threshold rather than scene geometry or SceneKit preparation. SceneKit
reports semitransparent snapshot coverage for opaque prepared geometry, so the
threshold incorrectly discarded most of the building.

The raw PNG, provenance record, and byte-identical repeat are retained. The
renderer repair preserves every nonzero object-coverage pixel, unpremultiplies
its color, and hard-mattes it before the flat chroma field. North advances to
`source-v07`; its geometry v5 remains unchanged.

## North source-v07

**Raw SHA-256:** `7b15c482e2e588f6a0598795531a8dcd1d76a3ed579094cf7dd9254d6018797b`

**Disposition:** rejected as a second deterministic source-tool failure

Lowering the coverage threshold retained more of the building but still
discarded large prepared-geometry regions. This confirms that SceneKit
snapshot alpha cannot be reinterpreted as a binary object mask in the raw
source compositor.

The raw PNG and provenance record are retained. The source renderer returns
to preserving native oversampled coverage on the required chroma field, while
the existing deterministic normalizer remains the only authority for alpha,
despill, and hidden RGB. The review tool consumes those normalized-alpha
outputs directly. North advances to `source-v08`; geometry v5 is unchanged.

## North source-v08

**Raw SHA-256:** `d8cb0b45cdf966f2d79a5902b4554dc22f799728dea81902280494646891cca0`

**Normalized block SHA-256:** `5256bafcaa24716be0234f33c711507d0725713ded613a0c93bad25c75f64bc2`

**Normalized neighborhood SHA-256:** `85e6e12293c0bcdc13ad0883bcdde244d7e3c76421d6f2b163c7e86752f7a37e`

**Normalized city SHA-256:** `63701a434737d6380e4bb77d18f6072ca7c3febff3d9c13fd926e975cf81543c`

**Disposition:** rejected after normalized-alpha edge validation

Returning the raw compositor to native oversampled coverage restored the
complete building and passed deterministic normalization. The normalized block
has alpha range 0...255, zero opaque chroma pixels, zero visible
magenta-dominant spill pixels, and valid padding. It therefore preserves the
first final-edge proof for the third calibration.

The art remains rejected: the far grounded porch return reads as an unlit
black opening and the warm masonry remains too underlit at actual scale.
Before the next render, the independently authored north and west porch
returns gain a grounded post-and-lintel frame with a warm return lantern, and
all four descriptors advance to a warmer ambient field. The material library
adds low masonry emission to retain facade value separation without altering
the northwest key or southeast shadow contract. North advances to
`source-v09` / geometry v6; west advances to geometry v6 before its first v03
render.
