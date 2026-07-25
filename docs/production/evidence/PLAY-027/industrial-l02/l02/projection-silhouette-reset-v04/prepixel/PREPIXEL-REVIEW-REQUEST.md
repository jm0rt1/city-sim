# PLAY-027 Industrial L2 East v04 pre-pixel review request

Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`

This checkpoint diagnoses the frozen East v03 rejection and freezes an
East-only v04 material, light, and alpha-compositor contract. It creates no new
rendered pixels and grants no source authority.

## Causal findings

- CPU projection assigned 99.23279683105332% of the genuine pre-chroma alpha
  support and 99.82281251628562% of opaque pixels to the frozen visible
  component faces.
- Visible declared material bases had weighted p25 106, IQR 67, and p95 207.
  SceneKit Lambert/key/ambient response compressed the same opaque pixels to
  p25 48, IQR 37, and p95 141 before chroma composition.
- The frozen quantizer/compositor/canonicalizer ended at p25 48, IQR 39, and
  p95 148. Quantization preserved the pre-existing compression; it was not the
  primary cause.
- Six referenced v03 pattern names are absent from the frozen renderer's
  pattern dispatch, leaving their large surfaces as base-color fills.
- All 8,460 non-exact near-magenta raw pixels coincide with genuine partial
  pre-chroma alpha. None coincide with zero or fully opaque pre-chroma alpha,
  and the retained neutral alpha composite has zero magenta-family pixels.
  The fringe is therefore an opaque-chroma composition defect separate from
  the lighting/material compression.

## Frozen v04 boundary

- V04 descriptor SHA-256:
  `fdb92d39acb8847178a95d1e0f6315332a93eda01df71388e54582fe1e6f12bf`
- V04 material-library SHA-256:
  `31f500488b7d143e88015bf71b53db4d1a4b19076563dc3d774d61f00c8b83a3`
- Canonical v03/v04 geometry SHA-256:
  `478254a6228ae5bcc4d81ae87ec1f43bfc433b606f95b87a440ca3d41cdf34a3`
- Alpha-compositor contract SHA-256:
  `351aed1910d7b680991815a479897fb4849060dd19798d662fe8c03f494f64e9`
- Predicted value-ledger SHA-256:
  `60da32f89de16cd4706675dac83dc6dbd0395305acbb5a9cd1ee0f2ef67cb77e`

The main production hall alone receives the medium blue-gray supported
corrugation. The foundation/loading spine use pale formed concrete; the
administration wing remains a separate warm pale concrete; roof, apron,
recess, doors, glazing, safety trim, and process metal each retain distinct
roles. All chosen pattern names are implemented by the frozen renderer.

The empirical analytic model predicts p25 112, IQR 96, p95 240, seven occupied
step-32 bins, maximum-bin share 0.33547877061223275, and identity-bearing
minimum bin 80. These are pre-pixel predictions only; literal future pixels
remain binding.

## Preserved scale and registration

- Building-only span: 514 source pixels / 144.5625 native-2x pixels
- Core-form span: 422 source pixels / 118.6875 native-2x pixels
- Minimum identity feature: 17.15625 native-2x pixels
- Camera, footprint, pivot, East socket, door bases, contact polygon, authored
  southeast shadow, component dimensions, and component positions are
  canonical-hash identical to v03.

## Future probe blocker and proposed gate

The only blocker is independent approval to consume one future Metal-visible
East v04 process. A future task-owned probe must bind the exact descriptor,
material, validation, and alpha-contract hashes; implement the compositor only
inside that v04 probe; retain the governed flat-chroma raw plus genuine
pre-chroma and neutral evidence; and stop after one process.

That probe must reject unless literal pixels meet p25 at least 80, IQR greater
than 48, p95 at least 192, at least five occupied step-32 bins, maximum major
facade-bin share below 35%, zero near-magenta opaque fringe, unchanged
registration and spans, and a clearly separated industrial hierarchy at
source and native-2x scale.

Current counters: Metal processes 0, SceneKit snapshots 0, new pixel files 0,
normalization runs 0, `productionSelected=false`.
