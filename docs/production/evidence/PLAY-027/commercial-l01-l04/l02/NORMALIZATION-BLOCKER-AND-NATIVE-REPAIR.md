# PLAY-027 Commercial L2 normalization blocker and native repair

## Blocker

The repository's existing shared Python normalizer rejected
`commercial_l02` because it has no registration rule for that logical asset.
That is a future ingestion concern, not authority for PLAY-027 to edit the
shared normalizer, add Pillow, change `Package.swift`, or alter any renderer,
shipping, package, build, or shared-manifest surface.

The source renderer also reported `SceneKit could not prepare the complete
scene graph` when invoked in the restricted sandbox. An unchanged accepted
Commercial L1 control failed in the same execution context and succeeded in a
normal host process. The retained L2 renders therefore used the already
accepted offline renderer in fresh host processes; no camera, geometry,
descriptor, or renderer-source change was made to work around the sandbox.

## Task-owned native normalization

`Tools/NormalizeOfflineSource.swift` is a standalone macOS-native source tool
under the PLAY-027 ownership boundary. It uses Core Graphics, ImageIO,
CryptoKit, and Uniform Type Identifiers already present on the approved host.
It is not a package target or product dependency.

The tool:

- decodes the exact retained 1536 x 1024 PNG through ImageIO;
- removes only border-connected magenta matte;
- despills retained edges and zeros RGB wherever alpha is zero;
- registers every direction against ground pivot `(768,896)`;
- applies one cross-direction scale, `410 / 234 =
  1.7521367521367521`, rather than normalizing every silhouette to an
  independently inferred width;
- emits deterministic 1024 x 683 block, 512 x 342 neighborhood, and
  256 x 171 city PNGs;
- writes a sorted task-owned provenance record with source and output hashes;
- keeps `productionSelected: false`.

The reference subject width is `234` source pixels and the registered object
width is `410` pixels. The resulting primary registration is:

| Direction | Decoded subject bounds | Target size | Target origin |
|---|---|---|---|
| north | `[668,596,902,818]` | `[410,389]` | `[563,507]` |
| east | `[668,596,902,818]` | `[410,389]` | `[563,507]` |
| south | `[668,596,868,831]` | `[350,412]` | `[593,484]` |
| west | `[668,596,868,818]` | `[350,389]` | `[593,507]` |

The directional width differences are retained visual geometry, not sibling
transforms. All four descriptors and rasters have
`orientationTransform: none`.

## Determinism and boundary disposition

Each direction was normalized twice into independent directories. All twelve
direction/LOD comparisons have `uniquePixelHashCount: 1` and pass exact pixel
identity. The twelve primary normalized outputs have twelve unique pixel
hashes, with zero opaque chroma pixels, zero visible magenta-spill pixels,
passing padding, and non-empty alpha bounds.

The shared-normalizer registration gap is recorded but does not block this
non-shipping source-art candidate. Renderer ingestion, shipping normalization,
atlas packing, and production selection remain outside PLAY-027.
