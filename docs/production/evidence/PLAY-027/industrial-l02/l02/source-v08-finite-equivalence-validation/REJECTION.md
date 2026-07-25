# PLAY-027 Industrial L2 East finite-equivalence validation rejection

**Disposition:** Rejected and frozen
**Pre-render authority:** `53ecccdd4a02a6d5e3ab464b32aa8fa5a4c8e3ed`
**Direction:** Industrial L2 variant-zero East only
**Production selected:** `false`

Exactly three authorized fresh Metal-visible processes were run. Each used
the immutable source-v06 descriptor and materials, the frozen 57-coordinate
table, SceneKit antialiasing none, descriptor-authored disabled shadows and
constant lighting, 4× oversampling, software Lanczos, and the existing
quantizer/compositor/canonicalizer. No validation tuple was added to the
table, and no rerender occurred.

## Binding failure

The first failed identity gate is the complete mapped pre-Lanczos 4× frame:

- runs a/c decoded SHA:
  `fa69deb012fd6b4d6aecbfa8846db17692c000aa39bafc8173065757bbecef38`;
- run b decoded SHA:
  `3290f2fac6150708010bafb41d9e807617602feb6980828508a5de7f9314201a`;
- run b differs from a/c at 7 pixels and 16 RGB channels, with zero alpha
  changes;
- difference bounds are 4× coordinates `[3359,1742,3417,1797)`;
- exact differing coordinates are `(3415,1742)`, `(3416,1742)`,
  `(3415,1743)`, `(3416,1743)`, `(3359,1766)`, `(3415,1796)`, and
  `(3416,1796)`;
- all seven coordinates lie outside the frozen table, whose maximum governed
  x coordinate is 3296.

The divergence survives software Lanczos as two single-channel source pixels:

- `(838,697)` green is 100 in a/c and 99 in b;
- `(855,705)` blue is 108 in a/c and 107 in b;
- source-space difference bounds are `[838,697,856,706)`.

Quantization later collapses the split: quantized-before-majority,
post-majority, ImageIO, and sips outputs are identical across all three runs.
Every final raw is byte-for-byte frozen source-v06:

- file SHA:
  `f59566ff0dad474e499fbfd2d719e54fae3c432133b5e17b158ded8ebc609503`;
- decoded RGBA SHA:
  `dd0fe1b05c3c8d65a10ca2cfa8fac0bb368117acd0db750dbea160115787d249`;
- occupied bounds: `[619,597,1029,906)`;
- color, grayscale, alpha, silhouette, contact/frontage, and registration
  difference: zero.

Final convergence does not rescue the experiment because mapped 4× and
post-Lanczos identity were binding requirements.

## Evidence

- `VALIDATION-TRIPLET-RESULT.json` contains the complete file and decoded
  inventory, per-run mapping metrics, provenance hashes, and disposition.
- `DOWNSTREAM-STAGE-IDENTITY.json` records every retained stage in run order.
- `review/MAPPED-4X-IDENTITY-FAILURE.{json,png}` records the first divergent
  stage and literal occupied-pixel zoom.
- `review/POST-LANCZOS-PREQUANTIZED-IDENTITY-FAILURE.{json,png}` records the
  two surviving source pixels.
- `review/PRE-MAP-4X-INPUT-DIFFERENCES.{json,png}` preserves the incoming
  SceneKit variation.
- `diagnostics/run-{a,b,c}/` retain each complete pre-map frame, mapped frame,
  post-Lanczos prequantized output, stage record, ImageIO output, final output,
  and provenance.

This is a rejected offline experiment. It is not source acceptance, source-v08
production pixels, normalization authority, or production selection.
