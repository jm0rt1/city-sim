# PLAY-027 Industrial L2 source-v04 East locality disposition

**Disposition:** causal diagnostic input only; source-v04 remains rejected and
frozen. This packet does not authorize normalization, a source-v05 revision,
production selection, or any mutation of the governed East gate.

## Immutable inputs

- East descriptor SHA-256:
  `08f17a9478d417f5f30d14ec231af02fb4c74a36108ab49ce5dd33940db0b6af`
- Industrial material library SHA-256:
  `166a19d5569a927d6ccdbaf1b29131835238bb3622e66d3b376d9eb33008f1ef`
- Primary/C PNG SHA-256:
  `c17349b7b711cf4d3786ff8ea040d2e5f8d706eb85fe353a418bb37bfd16fa23`
- B PNG SHA-256:
  `1a22b9a6bddfad198de8b585c7f319569902c26b63324be2e2ef8eb74b5a2ebc`
- Exact-byte comparator source SHA-256:
  `c7f4e50de99bf62713113fc1d98e64fbf64df0d0df4271153ed77fde7632d880`

## Exact decoded-pixel result

The standard ImageIO RGBA decode is 1536 x 1024 with top-left coordinate
origin. Primary and C are exact file and pixel matches. B differs from both at
604 pixels and 737 RGB channel samples inside the exclusive source bounds
`[682, 687, 779, 781]`. Alpha differs at zero pixels; every changed sample has
alpha 255. The occupied building bounds remain identical at
`[619, 597, 1029, 906]` (410 x 309).

Channel changes from primary/C to B are:

- green: 385 samples;
- blue: 351 samples;
- red: 1 sample;
- alpha: 0 samples.

The quantized delta distribution is:

- `[0, +32, 0, 0]`: 252 pixels;
- `[0, 0, +32, 0]`: 217 pixels;
- `[0, +32, +32, 0]`: 133 pixels;
- `[-32, 0, 0, 0]`: 1 pixel;
- `[0, 0, -32, 0]`: 1 pixel.

The exact retained-byte JSON records every coordinate, primary/B/C RGBA tuple,
and differing channel. Its SHA-256 is
`98381d309a096b994c7150a84fd0af4588f44fbf2baebd99b27c7b9deb6f8c8d`.

## Spatial and authored-region contact

The changed pixels form three separated vertical bands:

- 30 pixels in `[707, 687, 712, 696]`, on the literal upper
  process-tower/roof-trim treatment;
- 573 pixels in `[682, 712, 779, 778]`, spanning the literal brick process
  tower and annex facade, corrugated assembly-hall facade, clerestory/window
  treatment, concrete datum/trim, and East loading-frontage material region;
- 1 pixel at `[710, 780, 711, 781]`, on the lower facade/trim boundary.

This is a literal decoded-crop classification, not a reverse-projected geometry
claim. The comparison sheet places the exact primary crop, exact B crop, and
binary difference mask side by side at nearest-neighbor 12x. The mask contacts
multiple facade materials and lit surfaces rather than a silhouette, alpha,
registration, or single-node edge. That signature supports a lighting-stage
isolation while leaving the descriptor, geometry, materials, compositor,
quantizer, and authored contact shadow frozen.

## Evidence

- `EAST-PRIMARY-B-C-PIXEL-LOCALITY.json`
- `EAST-PRIMARY-VS-B-LOCALITY-ZOOM.png`

The zoom sheet SHA-256 is
`0d54efbb3ae4404736c4228b8aaa017bc20db44164a7e9384016e5f71e26f69c`.
