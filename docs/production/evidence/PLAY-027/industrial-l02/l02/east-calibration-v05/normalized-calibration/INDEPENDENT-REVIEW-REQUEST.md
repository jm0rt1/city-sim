# PLAY-027 Industrial L2 East v05 normalized calibration review

**Disposition:** PENDING INDEPENDENT VISUAL REVIEW
**Source authority:** false
**Production selected:** false

The sole authorized East Metal capture remains the immutable raw input. Exactly
two fresh no-Metal normalizer processes consumed it with object width `410`
and the frozen `512`-source-pixel registration-diamond reference. No B/C
render, other direction, other family, or additional normalization process was
run.

## Technical result

- Raw file SHA-256:
  `a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8`
- Raw non-chroma support and genuine alpha-positive support both contain
  `147343` pixels with bounds `[509,488]...[1029,906]`.
- Hidden non-magenta RGB: `0`.
- Near-magenta foreground pixels: `0`.
- Block, neighborhood, and city are exact file and decoded-pixel repeats
  across run A/B.
- All three LOD file and decoded-pixel identities are mutually unique.
- Every LOD has zero exact chroma, zero visible magenta spill, zero hidden RGB,
  valid transparent padding, and the frozen `[768,896]` ground pivot.
- Normalizer provenance is byte-identical across both processes.
- The review builder replayed byte-identically in a second no-Metal process.
- Machine disposition:
  `PENDING_INDEPENDENT_VISUAL_REVIEW`.

## Visual review

Please inspect the bound actual-pixel panels under `review/`, especially:

- `FOOTPRINT-NATIVE-2X-L1-V04-V05-COLOR.png`
- `FOOTPRINT-NATIVE-2X-L1-V04-V05-GRAYSCALE.png`
- `BLOCK-ACTUAL-L1-V05-COLOR-GRAYSCALE.png`
- `NEIGHBORHOOD-ACTUAL-L1-V05-COLOR-GRAYSCALE.png`
- `CITY-ACTUAL-L1-V05-COLOR-GRAYSCALE.png`
- the corresponding source-scale and zoom sheets.

The binding visual questions remain whether all three docks/canopies read
separately, the staff entrance cannot be mistaken for a fourth dock, safety
orange stays subordinate, the far-side mass preserves the East frontage, and
v05 remains materially stronger than accepted Industrial L1 and retained v04
in color and grayscale.

This packet requests independent East-only calibration review. It does not
accept source art, authorize N/S/W, select production art, or change renderer
or shipping authority.
