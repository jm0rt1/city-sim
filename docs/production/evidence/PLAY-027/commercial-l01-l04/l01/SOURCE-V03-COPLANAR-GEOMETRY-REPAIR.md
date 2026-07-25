# PLAY-027 Commercial L1 source-v03 coplanar geometry repair

**Scope:** Commercial L1 variant-zero N/E/S/W only

**Production selected:** no

Source-v02 localized the repeat drift to the shared corner pier. Its original
12 x 34 x 12 volume at `(20,19,-20)` ended exactly at `x=26` and `z=-26`,
coplanar with the main 52 x 30 x 52 commercial mass. The competing stone and
brick faces occupied the same depth plane across the pier height.

Each independently authored direction now explicitly declares a
13.2 x 34 x 13.2 corner pier at `(20.6,19,-20.6)`. Its outer planes are
`x=27.2` and `z=-27.2`: distinct from the main mass (`26`), storefront cornice
(`26.5`), parapet (`27`), roof coping band (`27.5`), and foundation (`28`).
The inner overlap remains hidden inside the main mass and creates no exposed
coplanar face.

All four descriptors advance to `source-v03` and unique geometry-v2 IDs. No
camera, footprint, pivot, frontage socket, light, shadow, material library,
normalizer, sibling source, mirror, rotation, transform, runtime, shipping
surface, or package definition changes.

The next render is a hard probe: three fresh processes must be byte-identical
per direction and every raw must visibly retain the complete building,
footprint plate, southeast shadow, and target-face storefront frontage.
