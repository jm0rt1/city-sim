# PLAY-027 Commercial L2 source-v01 review candidate

**Candidate:** `commercial_l02/variant-0` north/east/south/west `source-v01`

**Review disposition:** pending independent source-art review

**Production selected:** no

**Expansion boundary:** Commercial L3/L4 remain blocked until this exact clean
candidate is independently reviewed and integration sends new authority.

## Retained raw source identity

| Direction | Raw SHA-256 | Pixel SHA-256 |
|---|---|---|
| north | `fdf75f3d40c1e4274c1153493d94e188ff24840ed2ad06cc98ce01ff9127bc47` | `52716692e60a660eb9063a1fb3ad9706330df754dc44c2552428e161bedd7063` |
| east | `94fb7430bbc23efa7c081983434445bc52faa4a2dc4226fad9b1f40579e8766a` | `1ff9889409b2a2ed15e2c95bb9dcb6cbafb700d31f2fda24bf71cca9b5819f84` |
| south | `eed9dd92f593a860abf8c24cdccaf5a7e59574c761c95628b467ac1ac1c85efa` | `5400316c9d00791f1df8f0b55c6c01386844659680b05eebf920ce61a621c48b` |
| west | `579a656b0623c5897cd5204bef23c29be9f739b45c4c4701b70801d36d76ba4d` | `7c2aae4d26e9d086e4114bdf44ca0aad53a8dd3fabd5356261f6e1d877be3ee4` |

Every direction is byte-identical across three fresh renderer processes.
Every retained raw is an opaque 1536 x 1024 PNG on flat `#ff00ff`, with
occupied bounds `[619,593,1029,906]`, complete volume/footprint/shadow
occupancy, and four unique raw pixel hashes.

`SOURCE-V01-EXACT-RGBA-VISIBILITY.json` decodes the exact retained bytes
through ImageIO. RGB and alpha-visible bounds match in all four directions,
alpha visibility is `1.0`, hidden non-magenta pixel count is zero, and
occupied-area ratios exceed the accepted Commercial L1 reference floor.

## Four separately authored scenes

`SCENE-VALIDATION.json` passes with four unique descriptor hashes and four
unique scene-geometry IDs:

| Direction | Descriptor SHA-256 | Frontage socket |
|---|---|---|
| north | `bc5467c4ce36887b6dda66d3fac4a64e73759b3e6caa0dd73e907515f4204d24` | `(896,704)` |
| east | `7c1bd4b6b9b49f3b7095f297c830ee12cf81427c2612f26cf2c1eac861f0c2c9` | `(896,832)` |
| south | `d3a5dc13a78ae9bb8786e02253967da02088f298e95df52bbe3aeba66204133b` | `(640,832)` |
| west | `40431a39797e545e6b75d904e9f0e9c0d2b81a2d51fdba3c830a23ed750b9307` | `(640,704)` |

Each scene independently declares all four facade planes, a
direction-specific entrance, grouped rooftop HVAC, and its own scene geometry
ID. The fixed ground pivot is `(768,896)`, contact polygon is
`(-28,-28) (28,-28) (28,28) (-28,28)`, light is northwest, and shadow vector
is southeast `(2,1)`. No sibling scene or raster is mirrored, rotated, or
transformed.

The three-floor market/arcade is materially distinct from accepted Commercial
L1: rusticated stone display base, burgundy upper market hall, projecting
corner bay and crown, teal arcade band, denser facade rhythm, and paired roof
mechanicals. The storefront/entrance hierarchy remains visible in the
normalized-alpha actual-scale and grayscale panels without relying on signs.

## Deterministic normalized identity

The task-owned macOS-native normalization repair and shared-normalizer blocker
are recorded in `NORMALIZATION-BLOCKER-AND-NATIVE-REPAIR.md`. All directions
use the same registration scale, `1.7521367521367521`, and pivot `(768,896)`.
Each direction was normalized twice with exact pixel identity.

| Direction | Block SHA-256 | Neighborhood SHA-256 | City SHA-256 |
|---|---|---|---|
| north | `a08a9a22403790bdcca09a5b73ecd974d9e9dad912abecdcdb4fc0750de50658` | `c70b7b6c2843560000713d5e1c21d1fbb7b47bf98724e65576ec7f749db9b83f` | `16021b56b438cf61c5589301617fc20f75cd05957a164d3afaf7f0f08b380234` |
| east | `4bc301f47a59bf2da041d69c3708acdd41a5ec5c784b248037dac6bd68e17b79` | `55c26bd355087e3897adcc6d828e68f8f9654e8099c5d4895544562e9a921c9f` | `dc001def9135a071355d76021d97d1c8e688c018901937231144ad2ba02656bb` |
| south | `f68d23e0ae65249d547f8435ec47f50d688752ad0db80aa75133d9a8b998b13d` | `768035441c14f9e111c8a741c19c7592a5f0f2f0379af2dc7f057946cdcc9d9f` | `f2e6e479714bb913bc27ce50edad1fa6c64b19ef5f5e53aab26365c9379c3385` |
| west | `658d67c49466f03def9c96364cb738e6cb7d903d01c9d7bbaba7314761c9292c` | `8a472bef7da07df3e3ad8aa334444f1190bcd3edc6eff9d57bacf02bee8646eb` | `fc35235d1f80d82b72c18b8ed56c68477cf756211ee02c7782818fea8edf5e80` |

`SOURCE-V01-NORMALIZED-ALL-UNIQUE.json` passes with twelve distinct normalized
pixel hashes across twelve direction/LOD outputs. All twelve repeat reports
pass with one pixel hash across their two runs. Every normalized output has:

- canonical 8-bit sRGB premultiplied RGBA;
- alpha range `0...255`;
- zero opaque chroma pixels;
- zero visible magenta-spill pixels;
- passing canvas padding;
- non-empty registered alpha bounds;
- byte-identical primary and durable repeat output.

## Review packet

All sheets use row-major north/east/south/west order. The registered block crop
is `[341,220,342,383]`, corresponding to raw crop `[512,330,513,575]`.

| Review surface | SHA-256 |
|---|---|
| `SOURCE-V01-SOURCE-SCALE-REVIEW-CANDIDATE.png` | `1ca82935a81b92cbdf88ffe685ef8d27ff71967744d24224c787f0366430b73d` |
| `SOURCE-V01-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `6cf77845815dde53149d0961695779c77b473a813c13544219a62e8a95ee19c1` |
| `SOURCE-V01-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png` | `3bec66c43f5b6d7a7f383b80e0567bc9b95e38d0df2b5d7c33b9b143f602a53e` |
| `SOURCE-V01-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `b6509316834f250a84b244a301ceb1bfba0761d5c0bf0fcbc1da155e47f9aa18` |
| `SOURCE-V01-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png` | `139be6bf2cf0779be4b31915ee3bc79d7c8e055199011bc9db46ec6dc303b050` |
| `SOURCE-V01-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `629c7525d580bb61e875b3d9ef0527f54b128abd5247f78c6ac1bf26b2b4f664` |

The sheet builder produced every surface twice from the exact retained input
bytes with the same six file hashes. The source-scale, normalized-alpha,
grayscale, registered-footprint, and zoom sheets are retained for independent
visual review.

This packet does not modify or select shipping art. It makes no renderer,
atlas, shared-manifest, package, build, runtime, gameplay, simulation, UI,
save, Industrial, Residential, Commercial L1, L3, or L4 mutation.
