# PLAY-027 Industrial L2 East finite equivalence proposal

## Result

Recommend authorizing a separate three-process validation triplet for this
proposal. This packet is diagnostic/freeze evidence only; it does not implement
a production source revision and does not consume that validation triplet.

Three fresh Metal-visible processes retained complete uncanonicalized
source-v06 East 4x frames. Their exact decoded identities differ, but all
100,663,296 bytes per frame round-trip through the retained PNGs exactly. The
frames differ at only 57 aligned coordinates within 4x bounds
`[2727,1575,3297,1954]`. Every unstable pixel is fully opaque and non-chroma.

The finite proposal contains:

- 57 exact 4x coordinates;
- two finite equivalence classes;
- 15 observed RGB tuples;
- one uniquely most-observed representative per class;
- a per-coordinate list of allowed tuples and its class;
- rejection on descriptor/input/table hash drift, duplicate or ambiguous
  classes, non-opaque/chroma input, or an unknown tuple at a governed
  coordinate;
- byte-exact pass-through at every coordinate outside the table;
- RGB-only writes, immutable input decisions, and no cross-run state at
  application time.

Applied independently to the three retained frames, the proposal changes only
34, 46, and 34 pixels respectively (97, 119, and 97 RGB channel writes). It
produces one exact mapped 4x decoded identity:

`fa69deb012fd6b4d6aecbfa8846db17692c000aa39bafc8173065757bbecef38`

All three downstream outputs are byte-for-byte identical to frozen source-v06:

- decoded RGBA SHA-256:
  `dd0fe1b05c3c8d65a10ca2cfa8fac0bb368117acd0db750dbea160115787d249`
- PNG SHA-256:
  `f59566ff0dad474e499fbfd2d719e54fae3c432133b5e17b158ded8ebc609503`
- occupied bounds: `[619,597,1029,906]`
- color, grayscale, alpha, chroma, silhouette, contact shadow, and registration
  comparison differences: zero.

## Frozen artifacts

- table: `proposal/FINITE-RGB-EQUIVALENCE-TABLE.json`
- derivation/application report:
  `proposal/DERIVATION-AND-APPLICATION.json`
- native-2x color:
  `proposal/review/NATIVE-2X-COLOR-FROZEN-V06-VS-PROPOSAL.png`
- native-2x grayscale:
  `proposal/review/NATIVE-2X-GRAYSCALE-FROZEN-V06-VS-PROPOSAL.png`
- native-2x amplified difference:
  `proposal/review/NATIVE-2X-DIFFERENCE-X8.png`
- source-scale comparison:
  `proposal/review/SOURCE-SCALE-FROZEN-V06-VS-PROPOSAL-DIFFERENCE-X8.png`

The table SHA-256 is
`7c2d5940b8fca22d1e2cb15fa248ab678e8b8266fb3ed453332d82474284ed31`.
The derivation/application report SHA-256 is
`e4ec88ed7f1e2dda214166c9c96b63a4962f2cd23725c571f7d38dccc0bcfdb3`.
The frozen derivation/application tool source SHA-256 is
`4d461392a9467e16f5325e80b89c7fbee515744ef56866e4b77ffa2ce8be771c`
and its compiled binary SHA-256 is
`30fddb775291c614e6d1ff5f802d6e5d9a2a60a0ae5c4b06a97af879598318e3`.
The review tool source SHA-256 is
`9f7965971de3fd6a416257ff927a86e2f9073e82968f351d65ab968b4d1d0ece`
and its compiled binary SHA-256 is
`16070fb15f2cafd57d8ec465234253605663ee30ebc9271b8dcd181f2891e82f`.

## Boundaries

No source-v08 descriptor or governed production pixel exists. No
normalization, N/S/W work, source/material/topology/camera/light/shadow change,
shipping/runtime/shared-manifest edit, production selection, push, or
self-acceptance occurred. Integration retains the decision whether this finite
coordinate-scoped table merits a separately authorized validation triplet.
