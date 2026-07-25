# PLAY-027 offline scene calibration architecture

**Published authority:** `bd0ce8461e4b9c56db7afa9196b5f3f1243dd967`

**Preserved capability-limit ancestor:**
`2b4da0778ff7955c7565798a4aef3d8f83c5be2a`

**Merged lane authority:** `96e321e808e1c9fc66482d4438a123dc6ad10d40`

**Disposition:** first CONTRACT-011 checkpoint passes; no source render has
yet been accepted

## Toolchain fingerprint

The regenerable native fingerprint records:

- macOS 26.4.1 build 25E253 on arm64;
- Xcode 26.6 build 17F113;
- Apple Swift 6.3.3;
- macOS SDK 26.5 build 25F70;
- SceneKit 608.300;
- Model I/O 268.2.2;
- Core Image 1592.80.2;
- Core Graphics 1965.4.5.

The fingerprint SHA-256 is
`f94a79643255f486f3841b436f4c974918bfb83c8a5fa73d538c9a48afdf20a1`.
Two consecutive runs reproduced it byte-for-byte.

## Frozen source architecture

The task-owned offline pipeline decodes one explicit scene descriptor, builds
native mesh and scene-graph state, renders a fixed 2:1 orthographic source at
2x oversampling, downsamples with Core Image, registers and composites with
Core Graphics, and writes metadata-stripped source PNG plus a sorted render
record.

No product target, package manifest, build script, application runtime,
renderer, shipping atlas, production selection, gameplay, simulation, UI,
save, PLAY-024, or PLAY-053 surface is part of the architecture.

The scene schema SHA-256 is
`07205d27f46b7ff8800373cbf7209748a326c205dfa54c69d4cac5f1df2624e1`.
The numeric residential material library SHA-256 is
`2bb75980dc934faf952ceec665db0072d84d1ddfb5fc1c2481be84f928671117`.
No ImageGen material swatch is needed for this calibration checkpoint.

## Four explicit scenes

Each scene independently contains all facade planes, 17 explicit window bays,
one direction-owned entrance, two props, and an entrance occlusion exclusion.
Every descriptor declares no sibling source, mirror, rotation, or transform.

| Direction | Scene SHA-256 | Entrance base world | Source socket |
|---|---|---|---|
| north | `184a7f9f932a55976507688e623c6fdbf5fb02fb39d3803feeafd330411b2b83` | `(0,3,-28)` | `(896,704)` |
| east | `e3592a478a5834ca2cf9e618181850be818090867dcd85e1dd1ba89cd1464fbc` | `(28,3,0)` | `(896,832)` |
| south | `7e96d146462ea99ead132cc3638ff246447d3a7cb49446cdaa29733b14f3c057` | `(0,3,28)` | `(640,832)` |
| west | `f364507c435a2bb7a8b1117960a8416e4dbc786897ff776b2d887608c3cf1f1f` | `(-28,3,0)` | `(640,704)` |

All four descriptor hashes and geometry IDs are unique.

## Deterministic validation

The standalone Swift validator checks:

- calibration identity and path direction;
- no sibling derivation, mirror, rotation, or transform;
- exact schema, toolchain, style-anchor, and material hashes;
- 72 x 36 point basis, 1 x 1 contact, footprint, pivot, envelope, named edge,
  edge-midpoint socket, and centered door-base registration;
- identical camera, building envelope, contact polygon, northwest light, and
  southeast shadow across directions;
- four explicit facades, exactly one entrance-bearing facade, and a world-space
  entrance base at that facade's midpoint;
- unique scene descriptor and scene geometry identities;
- non-shipping preview and production-selection state.

The retained report passes with zero failures. Two consecutive validator runs
produced report SHA-256
`9edeeaadb1f5a1b6cbe3f08c0e3cab8b67be9ed043fce40d51df91e7af28ae99`.

## Preview plan

The frozen preview plan SHA-256 is
`ba28cb7f627d122749472a5c27af66023b2a60de7c0087976183aa31deb33587`.
It requires row-major N/E/S/W, unlabeled 2 x 2 sheets at:

- source scale: four 1536 x 1024 panels in a 3072 x 2048 sheet;
- native-2x actual scale: source scale `0.28125`, four 432 x 288 panels in an
  864 x 576 sheet, where the 512 x 256 source diamond becomes 144 x 72;
- grayscale: the same native-2x sheet with fixed saturation zero.

Raw rendering, normalization, alpha/chroma inspection, pixel determinism,
contact sheets, grayscale recognition, and independent art disposition remain
unrun at this architecture checkpoint.
