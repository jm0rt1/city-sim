# PLAY-027 Industrial L3 source-v03 pre-pixel capability

Disposition: `PASS_PREPIXEL_SAMPLING_REPAIR`

Industrial L3 variant-zero N/E/S/W source-v03 descriptors derive mechanically
from the frozen source-v02 descriptors. The only value changes are:

1. `sourceRevision`: `source-v02` to `source-v03`;
2. `sampling.sourceRevisionBinding`: `source-v02` to `source-v03`;
3. the complete accepted Industrial L2 source-v07 East
   `rgb-step32-midpoint8-preserve-alpha-chroma-v1` pre-Lanczos block.

Removing those three changes reproduces each source-v02 canonical JSON value
exactly. The v02 material library remains
`3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`.
Geometry, camera, pivot, footprint, frontage, light, authored shadow, and the
post-quantization v3 contract are unchanged.

## Frozen source-v03 descriptors

- north: `11b559a3b2ba4c679a22cd063f94cec56c06c4f46c9c93af2832d31eb06b6bf9`
- east: `1a4687b3ac6db8492ee8030f44dc04d99db163d460c5b923fb628a72d8279448`
- south: `e0d286c55bfd79527faf87b3c5c75b725ec5dea4394b2d3e1af13b57642f9126`
- west: `46cfb19f041bb3303cf4fd5d84a84e111c5892122512859202bfe2b59410bfaf`

Resolver source changed from
`34c0bced859f2716b1ca04a0f576aa463022ff1b3e7e10056717458daba239e2`
to
`88b6e9d30f666eff5d0527abae4722f027150ac4b93734df40b681160e395d58`.
It admits pre-Lanczos canonicalization only for the existing Industrial L2
source-v07 East identity or Industrial L3 variant-zero source-v03 N/E/S/W
source-authority descriptors under the exact schema-2 v3 contract.

## Validation

- Four hash-bound source-v03 positives resolve to the exact v3 effective
  contract.
- Twenty mutations fail closed: logical ID, variant, revision, direction,
  purpose, contract ID, missing pre-Lanczos block, and every frozen
  pre-Lanczos field.
- The source-v02 L3 capability still passes 4 positives and 7 negatives.
- Accepted reproduction passes 36/36 byte-identical descriptors with zero
  mutation against `9290d7f53e7ea75d5011c19c48388084e2cbe6af`.
- Industrial L2 source-v04 shadow, source-v05 lighting, and source-v07 East
  pre-Lanczos capture contract tests pass from the modified resolver.
- The descriptor builder and sampling validator each replay byte-identically.
- All standalone compilations use `-parse-as-library -warnings-as-errors` and
  task-local module caches.

Evidence hashes:

- descriptor advance report:
  `bb5ffde3acef35c7ed148ede69d8feee2bbbf3efed6c3ee9a4359068d028fb21`
- sampling validation report:
  `19b706d5e3508a141825e04202e9fd17e037e206e425a6fb3c4cc4eabc0b06a0`
- accepted reproduction report:
  `bb02b17507c568ab5eb51e2b02f54559a630d9ba5ef4ff6d6e84ceb4fbb0caee`

No SceneKit/Metal source process, normalization, material edit, product
runtime, shipping surface, package, or production selection is part of this
checkpoint. `sourceAuthority=false`; `productionSelected=false`.
