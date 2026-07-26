# PLAY-027 Industrial L2 source-v05 East stage disposition

## Result

**PASS causal classification; FAIL raw determinism; diagnostic only.**

The recurring East facade-band split is already present in the immutable
prequantized in-memory RGB buffer at source coordinate `(707,687)`. Run A and
run C are identical at every captured stage. Run B is distinct at every
captured stage.

At the target, the prequantized identities are:

- run A: `[126,76,50,255]`
- run B: `[124,93,68,255]`
- run C: `[126,76,50,255]`

Quantization maps these to `[144,80,48,255]`, `[144,112,80,255]`, and
`[144,80,48,255]`, respectively. The target is neither eligible for nor
mutated by the majority canonicalizer in any run. Within every run,
post-majority decoded RGBA equals ImageIO-decoded RGBA, and ImageIO-decoded
RGBA equals final sips-decoded RGBA.

Therefore the quantizer, majority repair, ImageIO, and sips faithfully retain
an identity split that already exists before quantization. This packet does
not yet distinguish the SceneKit 4x render buffer from the software Lanczos
downsample inside that prequantized boundary.

## Preserved authority

The Industrial L2 source-v05 descriptor and materials are unchanged. Geometry,
camera, registration, lighting, shadows, sampler, and compositor are
unchanged. The exact source-v05 pre-pixel, rejected raw-gate, and prior
diagnostic trees remain `963e774a7a94693c88b33987aef742a98fb60d9b`,
`b575801c6862f9354b9ad356d155fa1a1f887942`, and
`d51bf035bff82175f53a6b79be75698068e869b4`.

No normalization or source revision was created. `productionSelected` remains
false.

## Stop

No further probe or repair is executed in this packet.
