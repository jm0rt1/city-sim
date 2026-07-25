# PLAY-027 schema-2 canonicalizer contract v3

Status: frozen pre-pixel design

Authority: integration approval following residual stage isolation at
`bc5768bbdf870869bec90e189e85e0e1db0a6868`.

## Symmetry gate

The retained 12-run stage packet proves that both final identities are
described by one symmetric same-channel boundary condition:

- target `(732,778)` is prequantized `[4,22,2,255]` and quantized
  `[16,16,16,255]` in every run;
- all local green samples except `(733,778)` are identical;
- `(733,778)` is green 23 in seven runs and green 24 in five runs;
- the frozen step-32/midpoint-offset-8 quantizer maps 23→16 and 24→48;
- support for proposed green 48 is therefore 6/9 or 7/9;
- ImageIO and sips preserve the post-majority result exactly.

`PREIMPLEMENTATION-SYMMETRY-GATE.json` is the binding machine-readable audit.
No counterexample was found.

## Unchanged v2 rule

The ordinary repair threshold remains seven of nine. A center channel is
replaced only when the proposed majority differs by exactly one 32-value
quantization quantum and the complete 3x3 neighborhood is opaque and contains
no exact chroma. Decisions read an immutable quantized buffer and write a
separate output buffer. Alpha is never written.

## Additive v3 boundary assist

Only when ordinary seven-of-nine support is absent may a six-vote majority use
the following additional predicate:

1. stable quantized support is exactly six;
2. the proposed majority and center are adjacent quantizer bins;
3. an immutable prequantized same-channel sample lies at exactly one of the two
   values straddling their quantizer boundary;
4. exactly one such boundary sample exists in the 3x3 neighborhood;
5. that sample is currently quantized outside the proposed majority, so it is
   genuinely one additional vote;
6. six plus that one vote reaches effective support seven;
7. after reclassifying only that vote, no competing quantized value has more
   than two samples;
8. the quantized and prequantized 3x3 neighborhoods are fully opaque and
   contain no exact `#ff00ff`;
9. the immutable prequantized and quantized buffers alone determine the
   decision; no prior output mutation is read.

The quantizer remains step 32 with midpoint offset 8. The boundary band width
is one value on each side of the exact bin boundary. The global majority
threshold is not lowered.

Every assisted mutation records target coordinate/channel, original and
majority values, prequantized vote coordinate/value, quantized vote value,
boundary pair, effective support, competing support, and reason in provenance.

## Frozen boundaries

- Schema 1 remains factor-2 plus SceneKit 4x MSAA.
- Schema-2 contract v1 remains 4x/no-MSAA/Lanczos without repair.
- Schema-2 contract v2 remains the immutable seven-of-nine repair.
- Only contract ID
  `play027-deterministic-4x-no-msaa-lanczos-v3` enables boundary assistance.
- Accepted descriptors, raw sources, normalized sources, and provenance are
  not modified.
- No runtime, shipping, package, shared-manifest, or production-selection
  surface is involved.

Residential L4/full regression and Commercial L4 source-v03 remain frozen
until the 12-process Residential L3 West v3 calibration is byte-identical.
