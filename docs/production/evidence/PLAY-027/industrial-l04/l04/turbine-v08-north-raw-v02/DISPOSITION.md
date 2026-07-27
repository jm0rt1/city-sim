# PLAY-027 Industrial L4 Turbine v08 North raw disposition

Final disposition: `REJECTED_VISUAL_GATE`

Source authority: `false`

Production selected: `false`

## Passing governed gates

- The published North-only resolver replayed byte-identically and rejected all
  twenty retained mutations.
- Exactly three fresh native North processes ran. Their raw PNGs are
  byte-identical at
  `3750d0d3fac54923936347579be65ed96461c4721142d73ed0cff31acad9818e`.
- Canonical decoded RGBA is identical at
  `b9bf1034639f0ca5858d24bc4f1dc23fa680fd1867db58960648158679ec7337`.
- Occupancy is 108,020 non-chroma pixels with half-open bounds
  `[509,517,1027,898]`; minimum bounds and area pass.
- Descriptor, material, camera, geometry, pivot, socket, frontage, door,
  contact, northwest light, southeast shadow, independent-authorship, and
  no-transform bindings pass.
- All three freight recesses survive the literal 192-by-128 raster at
  10, 10, and 11 pixels wide. The staff entrance survives at the exact
  two-pixel compact minimum.
- Four sawtooth roof volumes and one subordinate stack remain present in the
  immutable descriptor. The stack, freight depth, and staff entrance are
  visible in retained raw panels.
- The task-owned no-Metal review replayed twice with complete byte identity.

Raw flat-chroma accounting is disclosed rather than treated as normalized
quality: 1,464,844 exact-chroma pixels, 1,703 non-exact near-chroma edge
pixels, zero alpha-zero hidden RGB, and no normalization process.

## Binding visual failure

The actual native pixels do not preserve the accepted four-peak sawtooth
cadence. In `SOURCE-SCALE-GRAYSCALE.png`, `NATIVE-2X-GRAYSCALE.png`, and
`EXACT-192X128-GRAYSCALE.png`, the four authored roof volumes merge into one
broad gable plane. The hall and roof also collapse into one uninterrupted
value family, so the required northwest-authored roof-versus-hall hierarchy is
not independently readable.

This is an actual-pixel source-quality failure, not an identity,
registration, resolver, or semantic-frontage failure. Descriptor roof count
does not waive the missing visible cadence.

No rerender, material/geometry/descriptor repair, normalization, sibling
direction, renderer/shipping/package/manifest mutation, source authority, or
production selection was attempted after classification. The full A/B/C
packet is preserved for independent review.

## Primary review evidence

- `review/RAW-REVIEW.json`
- `review/ALPHA-OCCUPANCY.png`
- `review/SOURCE-SCALE-COLOR.png`
- `review/SOURCE-SCALE-GRAYSCALE.png`
- `review/NATIVE-2X-COLOR.png`
- `review/NATIVE-2X-GRAYSCALE.png`
- `review/EXACT-192X128-COLOR.png`
- `review/EXACT-192X128-GRAYSCALE.png`
- `review/OCCUPIED-CROP-COLOR.png`
- `review/FOOTPRINT-CONTACT.png`
- `review/SEMANTIC-VISIBILITY.png`
