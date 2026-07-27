# PLAY-027 Industrial L4 North v09 pre-pixel disposition

`PENDING_INDEPENDENT_PREPIXEL_REVIEW`

The third and final materially distinct v09 roof layout passes the tightened
literal-192 gates. Four descriptor-camera-projected pyramid roof modules are
staggered across the supported hall roof plane, yielding three visible internal
valleys without changing the 56×56 footprint, pivot, socket, frontage, contact
polygon, authored NW light, or SE shadow.

Measured at exact 192×128:

- peak count: 4
- internal valley widths: 4, 3, 3 pixels
- internal valley depths: 2, 4, 3 pixels
- adjacent peak-center separations: 10.5, 10.5, 10 pixels
- roof/hall median luma: 65 / 111; absolute separation 46
- NW/SE roof-slope median luma: 133 / 93; NW advantage 40
- staff entrance bounds: 5×7 pixels
- combined freight bounds: 35×18 pixels; each authored bay remains preserved

Both complete generator replays, including persisted descriptor/material
production decode and all 15 review PNGs, are byte-identical. The comparison
panels use the retained v08 run-A raw SHA
`3750d0d3fac54923936347579be65ed96461c4721142d73ed0cff31acad9818e`
and show the rejected single-gable collapse beside the v09 cadence.

No SceneKit/Metal raw source process or normalizer process ran.
`sourceAuthority=false`; `productionSelected=false`.
