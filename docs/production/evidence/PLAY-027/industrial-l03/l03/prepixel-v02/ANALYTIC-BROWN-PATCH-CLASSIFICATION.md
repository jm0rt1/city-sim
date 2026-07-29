# Analytic brown-patch classification

The rejected v01/v02-development preview showed a small speckled brown patch on
the North and West apron/roof region. It was not a declared surface texture,
chroma remnant, or quantizer output. The CPU analytic preview temporarily
represented an `explicit-cylinder` tank as a box while the authored tank top
was exactly coplanar with an annex roof. That invalid placement produced the
speckled depth diagnostic.

The frozen v02 descriptors move every affected tank into a genuine,
non-overlapping service-yard gap. The structural validator now reports zero
coincident Y boundaries and zero camera-visible coincident material-owner
planes. The remaining solid oxide-colored analytic shapes are intentional
service tanks; the governed renderer will construct them as
`explicit-cylinder` nodes. The rejected speckled placement cannot enter a raw
or normalized source because it is absent from the frozen descriptors and the
raw gate is descriptor-hash bound.

No threshold, mask, or review-only hiding rule was added.
