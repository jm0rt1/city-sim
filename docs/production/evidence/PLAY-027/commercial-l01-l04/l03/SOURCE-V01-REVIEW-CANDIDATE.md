# PLAY-027 Commercial L3 source-v01 review candidate

**Candidate:** `commercial_l03/variant-0` north/east/south/west `source-v01`

**Review disposition:** pending independent source-art review

**Production selected:** no

**Expansion boundary:** Commercial L4 remains blocked until this exact clean
candidate is independently reviewed and integration sends new authority.

## Authority and preservation

The branch synchronized published baseline
`4c0414b003a178948c62128f425b6d534ac2e7a7` through merge
`72adc7770a87af6b7877a47343bf6f5faa978147`. Commercial L2 accepted authority
`a224937e6aaae9c4824566403ead8c6087d646d9` is an ancestor. The four L3 scenes
were frozen before pixels at
`22ee0ca5f3d53d72250b395a04af64d261f45932`.

A path-scoped comparison against `a224937e6aaae9c4824566403ead8c6087d646d9`
passes for every accepted Residential L1-L4 and Commercial L1-L2 scene, raw,
and normalized art path. This candidate does not mutate accepted source art.

## Retained raw source identity

| Direction | Raw SHA-256 | Pixel SHA-256 |
|---|---|---|
| north | `9a81e8b710296c40ab16021c7db7fe0bed68a5e87a6dbb9dc4b07d43322a6c4e` | `d2f94104b8ae6ffe3669820cf22824fb786913bb68436880ab5d592668ebb382` |
| east | `a29c3f2ee33410409ea482c8f15c7f05f2b6a3b227feccc9c575991258ab4363` | `e79fe52692c4388fb1d5b2da009c7c406d7685baba130bb31808a4130a95b17f` |
| south | `63984ab4ec0166b2b451901a48c5b2033b3d5ba103e269a6435831b557812736` | `7472636a3a3dee2dc1f8619091de36521dcb79a3aa945b7bd4e63c76a786031d` |
| west | `7fbb3fedd2bd88d612e7853106c6dd2d510e55b45597c458438005d6412610f9` | `91a66fe788ae7a4cd16b4fb345bd4a6b9b0b1b8b08edcd8fec8760d48ee7b3c5` |

Every direction is byte-identical across three fresh renderer processes.
Every retained raw is an opaque 1536 x 1024 PNG on flat `#ff00ff`, and the four
raw pixel hashes are unique.

`SOURCE-V01-EXACT-RGBA-VISIBILITY.json` decodes the exact retained bytes
through ImageIO. RGB and alpha-visible bounds match in all four directions,
alpha visibility is `1.0`, hidden non-magenta pixel count is zero, and every
occupied area exceeds the accepted Commercial L2 reference floor. The
retained exact-RGBA crop sheet visibly contains the complete building,
footprint plate, southeast shadow, and target frontage in N/E/S/W.

## Four separately authored scenes

`SCENE-VALIDATION.json` passes with four unique descriptor hashes and four
unique scene-geometry IDs:

| Direction | Descriptor SHA-256 | Frontage socket |
|---|---|---|
| north | `54db8480df656e33f725d6b85bc66f6d2e2e215843ff598456561e476af431b1` | `(896,704)` |
| east | `3c371c975c3f9719013f6fe6ecfdb723435f0b98bd120b12ad0e3a797a209403` | `(896,832)` |
| south | `affb2e6fbf2b25436f37456b00a43c200c6ae231535a376b615b7e772c9ef90d` | `(640,832)` |
| west | `1608f3dd065b12bfb7de9dd9c1a08191acb063d4467f365eb80ba8da7a9a31cb` | `(640,704)` |

Each scene independently declares all four facade planes, its
direction-specific lobby/entrance, rooftop plant, and its own scene geometry
ID. The fixed ground pivot is `(768,896)`, contact polygon is
`(-28,-28) (28,-28) (28,28) (-28,28)`, light is northwest, and shadow vector
is southeast `(2,1)`. No sibling scene or raster is mirrored, rotated, or
transformed.

The five-floor office/department block advances beyond accepted Commercial L2
through a rusticated podium, three-level terracotta office body, centered
two-level burgundy setback wing, stepped roof terraces, vertical office
glazing, formal lobby, and screened roof plant. Its commercial silhouette,
entrance hierarchy, and density increase remain visible in normalized-alpha
actual-scale and grayscale panels without relying on signs.

## Deterministic normalized identity

All directions use the same registration scale, `1.7521367521367521`, and
pivot `(768,896)`. Each direction was normalized twice with exact pixel
identity.

| Direction | Block SHA-256 | Neighborhood SHA-256 | City SHA-256 |
|---|---|---|---|
| north | `42dc96ef32cfce8c1717a0e6a8019ddadfadc00385eaccb8aac6ac33599f286a` | `ec2af484f519acc8f3486a1bb5ab1cc7947af2956dc1610d79227396bbbfe068` | `a024f89978776286d1b28e792cbbb4e0be0a2fd1dfff9d0ae62d3f2b9c0ad2a4` |
| east | `f5a5dee1f4b64eed0fef74615905e1334f6ede3125c5bb30d84eda42a422bec0` | `5df20aa94314dab24d242cf1ee3844830690f9286f519dc26682a1da341232d1` | `8e4b9bc5420819af3206c8af02cd3d3759bb81a89acb35252bd6d51e8c0e3a68` |
| south | `62dfba7710fa045c1f1d289440f2d5d21109801d2eeade0a74affcf15e4aa5af` | `eb59e32076d49315a0fe489b3d781760dc672e51a09ad0f27f48217b3eb526ca` | `4400a77be62a99973f9f27ab6cc5235d2ac74d10e9ce4bd42786abd87100d4e0` |
| west | `fbec0d8199e4d8cce55c24bf7cea26ae4b6ebf6e92a422ab01f976dc3ce18796` | `f81f1a3c60ae720ff09e27f04573647f9f143232bc53288a18274f4570813fac` | `725fdfe960e6147d33205fdd63cc2abbbb72e14f390f99b7a12f919d91b43f1a` |

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
is `[341,120,342,483]`, corresponding to raw crop `[512,180,513,725]`.

| Review surface | SHA-256 |
|---|---|
| `SOURCE-V01-SOURCE-SCALE-REVIEW-CANDIDATE.png` | `e15720168a42ebfdf6964daf15ea2b95584a7ab4796d467fe34695e3dafecb19` |
| `SOURCE-V01-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `41b51319ad6578349c505429726f5be2528a23ccad7d35b9fffcb56ca5767446` |
| `SOURCE-V01-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png` | `fd2a0664f8f4b6e5dc29a50843ce84b6e97e0d368f6486285a2c0b521998f67f` |
| `SOURCE-V01-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `6397c6cdb94a252155e46ba42294b19a3f620984a6d661320b89eccc0e78730f` |
| `SOURCE-V01-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png` | `1e8b9d040b725eb4b16d65fefb7876143dc2a64f7031e5fc60c2bfa02ac4e6ef` |
| `SOURCE-V01-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `d46e2e6c05f679f8b03433e11421ba3e22081934442f56fa43f8f0db56721e21` |

The sheet builder produced every surface twice from the exact retained input
bytes with the same six file hashes. The source-scale, normalized-alpha,
grayscale, registered-footprint, and zoom sheets are retained for independent
visual review.

This packet does not modify or select shipping art. It makes no renderer,
atlas, shared-manifest, package, build, runtime, gameplay, simulation, UI,
save, Industrial, Residential, Commercial L1, Commercial L2, or Commercial L4
mutation.
