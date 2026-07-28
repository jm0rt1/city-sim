# PLAY-027 Industrial L4 Crucible Gantry v16 North raw-probe authority

- Published baseline before authority: `2a31cdfdf6c20e7c7aac37bd74eaa6206474cd70`
- World Art candidate: `9af97963f6010fbba9b135f5d331e3ca2d4ce78d`
- Independent Renderer disposition: `APPROVE_RAW_PROBE`
- Independent QA disposition: `APPROVE_RAW_PROBE`
- Logical key: `industrial_l04/variant-0/n`
- Authorized revision: `source-v16-prepixel`
- Authorized raw processes: exactly one A-only North process
- Source authority: `false`
- Production selected: `false`

Integration admits one tightly bound native raw probe. It does not authorize
repeat renders, East/South/West scenes, normalization, ingestion, shipping
resources, production selection, or product acceptance.

## Exact immutable binding

- Builder:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV16NorthPrepixel.swift`
- Builder SHA-256:
  `15d88031e4b845060d2f66cef93f96a7d9b204fd2ecd9873f885924e8099c97d`
- Descriptor:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/attempts/refinement-02/artifact/scenes/industrial_l04/variant-0/n/scene.json`
- Descriptor SHA-256:
  `bb4d38f44223083fe88b24f482b62a3061b0322e83e50836d8fb7b2d97b3c411`
- Geometry ID:
  `industrial-l04-crucible-gantry-v16-north-l-side-return`
- Material library:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/materials/industrial-l04-crucible-gantry-v14-north-prepixel.json`
- Material SHA-256:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`
- Registration panel SHA-256:
  `f11096e983b14c400e94efa9ae904159b860346dda9a773fb2d1c909f61e2d27`
- Sampling:
  `play027-deterministic-4x-no-msaa-lanczos-v3`,
  `authored-constant-v1`, SceneKit shadows disabled, orientation `none`

The resolver rejects every other family, variant, direction token, revision,
revision binding, geometry ID, material path or hash, authorship/selection
state, sampling purpose, contract, antialiasing, lighting, shadow mode, and
orientation transform.

Focused validation passed one exact positive and 20 fail-closed mutations:

`docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v16-north-resolver/RESOLVER-VALIDATION.json`

Report SHA-256:
`ccfb0bd122e0d487a6478e9275d9a974c15a504f0562edc55f3a251eb1d88c48`.

## Required A-only packet

The single raw process must retain the executable hash, full provenance,
descriptor and material hashes, raw PNG, decoded RGBA/alpha validation,
native-2x and literal 192x128 color/grayscale views, frontage/registration
contact, and direct comparisons with the accepted Industrial L3 source and
v14 pre-pixel candidate.

Independent review must confirm:

1. the road socket reaches a North throat at least 7 compact pixels wide;
2. one monumental recessed freight gate remains unmistakable, with visible
   jamb, header, and inset depth at native-2x and literal 192x128;
3. the warm hall, double-girder gantry, hot crucible, stack, and material
   hierarchy survive the real raster;
4. the authored northwest value direction and southeast contact shadow remain
   coherent; and
5. no crop, registration, alpha, hidden-RGB, or chroma failure is introduced.

World Art must stop after this A-only packet. A separate integration
disposition is required before repeat processes, sibling authoring, or
normalization.
