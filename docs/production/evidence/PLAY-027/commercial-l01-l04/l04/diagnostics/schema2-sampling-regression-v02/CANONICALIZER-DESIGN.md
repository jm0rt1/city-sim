# PLAY-027 schema-2 canonicalizer v2 design

Status: implementation and unit-test boundary; no pixels yet.

Authority: integration repair authorization after the preserved raw failure at
`b4df359a46f2baed7fe961367260d132fe5d71e1` and the prequantization locality
checkpoint at `f529279bf5a05f3b18a252409263d1d8f0cb5141`.

## Immutable compatibility boundary

- Schema 1 is unchanged: factor 2, SceneKit 4x MSAA, no post-quantization
  canonicalizer.
- Schema-2 contract v1 remains decodable and reproducible without the repair.
- Schema-2 contract v2 retains no MSAA, factor 4, software Core Image Lanczos
  scale 0.25, the existing step-32/midpoint-offset-8 palette, and the existing
  PNG encoder/canonicalizer.
- Accepted scenes, sources, normalized LODs, provenance, source revisions,
  geometry, registration, alpha, and shipping/runtime surfaces are unchanged.

## Authorized canonicalizer

Contract ID:
`play027-deterministic-4x-no-msaa-lanczos-v2`.

Algorithm ID:
`opaque-isolated-one-quantum-majority-3x3`, version 2.

For every non-edge center pixel and each RGB channel independently:

1. Read the center and all eight neighbors from an immutable quantized RGBA
   buffer.
2. Require all nine alpha values to equal 255.
3. Require all nine RGBA pixels to contain zero exact `#ff00ff` chroma pixels.
4. Require at least 7 of the 9 channel values to equal one majority value.
5. Require the center to differ from that majority by exactly the frozen
   quantization quantum, 32.
6. Write only that center RGB channel to a separate output buffer.

Alpha is never written. Exact chroma and any chroma-adjacent center are never
written. Scan order cannot cascade because decisions never read the output
buffer. There is no median filter, global coarsening, neighborhood averaging,
geometry change, or silhouette repair.

## Frozen tests

The standalone test executable binds:

- one-quantum isolated RGB repair;
- 6/9 majority rejection;
- two-quantum rejection;
- non-opaque-neighborhood rejection;
- exact-chroma preservation;
- chroma-neighbor exclusion where 7/9 would otherwise repair;
- immutable-buffer non-cascade behavior;
- RGB channel isolation and alpha preservation.

The next gate is at least 12 fresh processes of Residential L3 West. Every run
must report its mutation count, and all final PNG file/pixel hashes, occupied
bounds, alpha, and registration must match. Source-scale, native-2x, grayscale,
and zoom comparisons must show no perceptual degradation before the full
authorized regression can restart.
