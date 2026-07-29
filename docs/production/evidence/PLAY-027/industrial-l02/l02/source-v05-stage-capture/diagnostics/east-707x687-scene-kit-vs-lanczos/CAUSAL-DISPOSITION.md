# PLAY-027 Industrial L2 source-v05 East SceneKit/Lanczos disposition

## Result

**PASS causal classification; FAIL raw determinism; diagnostic only.**

The immutable 33×33 SceneKit 4× support window feeding source coordinate
`(707,687)` has two identities across the exact three fresh Metal processes.
Run A differs from runs B and C by 141 of 1,089 pixels and 422 RGB channels,
with zero alpha differences. Runs B and C have identical support-window bytes.
The post-Lanczos 3×3 follows the same A-versus-B/C grouping.

This proves the target split exists in SceneKit draw/coverage before
`CILanczosScaleTransform`. Software Lanczos, quantization, majority repair,
ImageIO, and sips do not first introduce it.

The pixel values identify the competing material owners. Run A exposes
`[128,77,51,255]`, the exact 8-bit brick-northwest value used by
`i02-east-process-tower`. Runs B/C expose `[117,138,117,255]`, the exact
corrugated-northwest value used by `i02-east-high-assembly-hall`. Both boxes
terminate on the same camera-visible positive-z plane at world `z=25`, with an
overlap spanning `x=-23…-7`, `y=2.5…44`.

## Preserved authority

The descriptor, materials, geometry, camera, registration, constant-light
mode, disabled SceneKit shadows, no-MSAA/4× sampling, quantizer,
canonicalizer, and compositor are unchanged. Prior pre-pixel, rejected raw,
diagnostic, and stage-capture trees retain their exact Git tree identities.

No normalization or source revision was created. `productionSelected` remains
false.

## Stop

No further render, repair, or source revision is executed in this packet.
