# Narrow next diagnostic proposal — not authorized or executed

Use unchanged Industrial L2 source-v05 **East only** and the existing
diagnostic-stage capture path at source coordinate `(707,687)`, where the
retained vertical-band identities differ between `[144,80,48,255]` and
`[144,112,80,255]`.

Run exactly three fresh Metal-visible processes with the same explicit
`none/current/current` options and capture:

1. prequantized in-memory RGBA and local 3x3;
2. quantized-before-majority RGBA and local 3x3;
3. post-majority in-memory RGBA and eligibility/mutation reason;
4. ImageIO pre-sips decoded RGBA;
5. final sips-decoded RGBA.

The sole question is whether East's recurring band divergence is already
present in SceneKit's prequantized RGB or first appears through
quantizer/canonicalizer support. Preserve the descriptor, materials, geometry,
camera, registration, lighting, shadows, sampler, and compositor. Do not
normalize or create a source revision.

This proposal is intentionally not executed without a new integration
disposition.
