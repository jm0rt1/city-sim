# PLAY-027 Industrial L3 source-v06 raw review disposition

- Disposition: `PENDING_INDEPENDENT_RAW_REVIEW`
- Resolver checkpoint:
  `d2649fc8f43d68360757031ff4d1c5ed856de089`
- Logical key: `industrial_l03/variant-0/source-v06`
- New directions: North and West only
- Immutable comparison directions: East and South
- SceneKit/Metal processes: exactly 6
- Normalizer processes: 0
- Source authority: `false`
- Family authority: `false`
- Production selected: `false`

## Repeat and published-diagnostic identity

| Direction | Runs | File SHA-256 | Decoded RGBA SHA-256 | Result |
|---|---:|---|---|---|
| North | 3 | `91b3fb983e294eeff288b13f6d89a19366393cfaf084b52527633e88ed0507ea` | `ca087fb06b5bcc67ea101f661ac07a5a1b263d5b3b32db4d1c6d8aa7d18764af` | exact A/B/C and exact published N2 diagnostic |
| West | 3 | `ceaa2948be0f37cbd8f6288c9c125f15502a864ce683bc3eaa1cd0d7563477d4` | `f66b4fe3cde165e0c3852ce5aa0863ec7380824f46e81708804428b6717be310` | exact A/B/C and exact published W1 diagnostic |

North and West occupy `[509,387,1027,896]`, remain unclipped, contain
159,510 non-chroma pixels each, have minimum non-chroma alpha 255, and contain
zero hidden-RGB or zero-alpha non-chroma pixels. Pivot, road socket, door-base
midpoint, footprint, light, southeast authored shadow, and
`orientationTransform:none` are preserved in all six provenance records.
North, East, South, and West retain four unique file and decoded-pixel
identities. The new North/West identities have an empty SHA intersection with
the five accepted generated-v4 catalogs.

The retained actual-pixel panels show the two complete dark loading-bay
rectangles and separate staff entrance required by the published raw gate.
Native-2x and compact grayscale retain the warm/dark Industrial L3 material
hierarchy and distinct directional frontage. This is a review candidate only;
normalization is intentionally unrun.

## Evidence

- Machine manifest:
  `review/RAW-REVIEW-MANIFEST.json`
- Source-scale North/West:
  `review/SOURCE-SCALE-NW-COLOR.png`,
  `review/SOURCE-SCALE-NW-GRAYSCALE.png`
- Native-2x North/West:
  `review/NATIVE-2X-NW-COLOR.png`,
  `review/NATIVE-2X-NW-GRAYSCALE.png`
- Occupied crop:
  `review/OCCUPIED-CROP-NW-COLOR.png`
- Four-direction compact:
  `review/COMPACT-NESW-COLOR.png`,
  `review/COMPACT-NESW-GRAYSCALE.png`

The review builder compiled with warnings-as-errors. Builder source SHA-256 is
`c2507db56b225105f7313774097bad941d09db5fc44cbc9240c8ee6f627b059d`;
binary SHA-256 is
`41001c895ca615857a63bc085a9e5b9892e25130b2854dcb4c3a92a2df66af24`.
Two no-Metal replays reproduced every panel byte-for-byte and the canonical
machine report byte-for-byte after replacing only the replay output-root
path.
