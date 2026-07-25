# PLAY-027 Industrial L1 source-v05 raw batch gate

Disposition: **technical raw gate passed; normalization authorized by the
integration dispatch, source art not accepted**.

The literal probe raws committed at `7feeabe` are process A. Processes B and C
were launched as eight additional fresh native SceneKit processes from the
unchanged descriptor/renderer boundary
`e2690f524dbf468255605cfe77a236404a015fa9`.

## Repeat identity

Each direction has one unique file SHA-256 and one unique decoded pixel
SHA-256 across primary/A, B, and C:

| Direction | File SHA-256 | Pixel SHA-256 |
|---|---|---|
| North | `5ca93afa57157ddf686ef5740f1907da03f513906b9c703bc556ed75e2516728` | `159ff8476fc7b06126dc2426c151668e73790e985cba00b746957b15e1bfc0fa` |
| East | `f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f` | `4e287c4f2afd7642a64660399d16e04a2c9d7e8d30ecf3e3cea0ae64b2d0bfa6` |
| South | `f3588cf71e689055a2bd0a184262b24df0af8c4e41be1665af5c8eb6f8edca2e` | `19c82cf3470bd70b54f8801fc873a3045da4ac81d1f9b6eec543e03a98131b38` |
| West | `9fa5759f88e2efd2f3eef36f66089f0e8e978dc4e052d08d919b9f1a40aa331a` | `0f995014b5df1742fdc42c5eb878f87db20b1081354cb02dd5a05ccaceecad05` |

The four primary raw pixel identities are unique. All twelve raw outputs pass
flat opaque chroma, alpha range, occupied-area/bounds, and padding inspection.
The four exact primary PNGs additionally pass RGB/alpha-visible bounds
equality, visibility ratio `1.0`, and zero hidden non-magenta pixels.

No descriptor, geometry, camera, threshold, sampler, accepted
Residential/Commercial source, normalized output, or production-selection
surface changed during this checkpoint.
