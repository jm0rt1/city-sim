# PLAY-027 Industrial L3 North residual stage isolation

Disposition: `FAIL_PREQUANTIZED_IN_MEMORY_IDENTITY`

Exactly three fresh North-only processes used frozen descriptor
`78803712...`, material library `3a9b0d97...`, and renderer binary
`cbbbf9bb...`. No sampling, antialiasing, shadow, lighting, material, or
diagnostic-contract override was supplied.

The first retained stage already differs across A/B/C:

- prequantized-in-memory: three unique decoded-RGBA hashes;
- quantized-before-majority: three unique hashes;
- post-majority: three unique hashes;
- ImageIO pre-sips: three unique hashes;
- final sips: three unique hashes.

Within each run, post-majority equals ImageIO decoded pixels and ImageIO equals
final-sips decoded pixels. Those downstream encoding stages are faithful.

At source coordinate `(656,468)`, A/C enter quantization as
`[41,55,63,255]`; B enters as `[41,54,62,255]`. All three quantize the target
to `[48,48,80,255]`. In A/C the prequantized green value 55 supplies the
single frozen boundary vote, so v3 mutates green to 80. In B the green value 54
does not supply that vote, so the target remains green 48. Total post-majority
mutation counts are 4,947 / 4,947 / 4,949.

This localizes the first observed divergence to the post-Lanczos
prequantized-in-memory buffer and exonerates the quantizer/canonicalizer as the
origin. The authorized capture does not separate SceneKit draw from Lanczos,
so no stronger cause is claimed. No repair, additional process, direction,
normalization, source authority, or production selection was attempted.
