# PLAY-027 Industrial L1 source-v05 single-probe review request

Candidate type: **one-process-per-direction raw representation probe**.
This is not repeat-determinism evidence, normalized source authority, production
selection, or self-acceptance.

Renderer source commit:
`e2690f524dbf468255605cfe77a236404a015fa9`.

## Exact retained raw results

| Direction | Raw SHA-256 | Occupied pixels | Occupied bounds |
|---|---|---:|---:|
| North | `5ca93afa57157ddf686ef5740f1907da03f513906b9c703bc556ed75e2516728` | 63,746 | 410 x 307 |
| East | `f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f` | 61,634 | 410 x 296 |
| South | `f3588cf71e689055a2bd0a184262b24df0af8c4e41be1665af5c8eb6f8edca2e` | 61,572 | 410 x 269 |
| West | `9fa5759f88e2efd2f3eef36f66089f0e8e978dc4e052d08d919b9f1a40aa331a` | 62,490 | 410 x 307 |

All four exceed the unchanged 50,000-pixel and 400-by-260 raw completeness
floors. Four raw pixel hashes are unique. Exact retained-byte decoding reports
flat opaque chroma corners, RGB/alpha-visible bounds equality, visibility ratio
`1.0`, and zero hidden non-magenta pixels for every direction.

## Literal crop observations submitted for review

Review:
`EXACT-RGBA-OCCUPIED-CROPS-SINGLE-PROBE.png`.

- North: the two high-bay wings frame a recessed throat; the connected gantry
  posts and elevated hazard crown identify the exact far frontage without
  claiming the hidden door plane is exposed.
- East: the near loading bay, canopy, gantry, hazard crown, and apron read as
  one connected frontage hierarchy.
- South: the near loading bay remains grounded and legible beneath the
  independently authored gantry.
- West: the gantry and hazard crown rise beyond the far roof silhouette, the
  split hall forms a loading throat, and the authored vertical mass raises the
  retained occupied height from the rejected 253 pixels to 307 pixels.

The fixed camera, 2:1 footprint, pivot, contact, N/E/S/W socket, light, shadow,
schema-2 v3 sampler, and accepted Residential/Commercial bytes are unchanged.
No mirror, rotation, sibling transform, threshold relaxation, padding, scale
change, plate manipulation, or camera trick was used.

## Requested disposition

Integration should independently inspect the exact crop and retained raws for
correct frontage, complete grounded silhouette, material hierarchy, and
occlusion honesty. If the four-view probe is approved, the next authorized
step is the already-scoped three-process raw repeat gate followed by two
normalization runs and the full review packet. Until then, repeat rendering and
normalization remain blocked.
