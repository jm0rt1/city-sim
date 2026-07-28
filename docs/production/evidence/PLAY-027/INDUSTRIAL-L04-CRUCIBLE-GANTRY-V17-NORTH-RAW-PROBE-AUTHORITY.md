# PLAY-027 Industrial L4 Crucible Gantry v17 North raw-probe authority

- Published baseline before authority: `2b389fa10e45fabc8c8d17a67b8dfdca6215e0ac`
- World Art candidate: `46b1c584dd6769356b716fd881bef681167d5f00`
- Independent Renderer disposition: `APPROVE_ONE_RAW_PROBE`
- Independent QA disposition: `APPROVE_ONE_RAW_PROBE`
- Logical key: `industrial_l04/variant-0/n`
- Authorized revision: `source-v17-prepixel`
- Authorized raw processes: exactly one A-only North process
- Source authority: `false`
- Production selected: `false`

Integration admits one tightly bound native raw probe. It does not authorize
repeat renders, East/South/West authoring, normalization, ingestion, shipping
resources, production selection, or product acceptance.

## Exact immutable binding

- Builder:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV17NorthPrepixel.swift`
- Builder SHA-256:
  `50198ea5b18d9eb9da8948566f86fb2ec52b5d929555a25dda8bb07dae503ac2`
- Descriptor:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v17-north-prepixel/artifact/scenes/industrial_l04/variant-0/n/scene.json`
- Descriptor SHA-256:
  `6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a`
- Geometry ID:
  `industrial-l04-crucible-gantry-v17-north-monumental-portal`
- Material library:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-crucible-gantry-v17-north-prepixel/materials/industrial-l04-crucible-gantry-v14-north-prepixel.json`
- Material SHA-256:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`
- Registration/contact panel SHA-256:
  `1bc04f4ed81b95efd3498a75ff90cc95c3f67e4d261c07ac033d12a0a52a56c3`
- Sampling:
  `play027-deterministic-4x-no-msaa-lanczos-v3`,
  `authored-constant-v1`, SceneKit shadows disabled, orientation `none`

The resolver rejects every other family, variant, direction token, revision,
revision binding, geometry ID, material path or hash, authorship/selection
state, sampling purpose, contract, antialiasing, lighting, shadow mode, and
orientation transform.

Focused validation passed one exact positive and 20 fail-closed mutations:

`docs/production/evidence/PLAY-027/industrial-l04/l04/crucible-gantry-v17-north-resolver/RESOLVER-VALIDATION.json`

Report SHA-256:
`029e7acc08766160e5cd6ce23d617a9edca3080309fd6fc7dafd0f3f56531f4b`.

## Required A-only packet

The single raw process must retain the renderer executable hash, full
provenance, descriptor/material hashes, raw PNG, decoded RGBA/alpha/chroma
validation, native-2x and literal 192x128 color/grayscale views,
frontage/registration/contact evidence, and direct comparisons with the
rejected v16 raw and accepted Industrial L3.

Independent review must confirm:

1. both jambs, header, and dark inset of the monumental portal survive in the
   actual literal-192 color and grayscale raster;
2. the portal remains architecture rather than a painted dark label;
3. the hot crucible remains visually separate from the opening;
4. hall, double-girder gantry, crucible, and stack retain a premium L4
   hierarchy that materially exceeds accepted L3;
5. road socket, court, throat, pivot, registration, and southeast contact
   shadow remain coherent; and
6. no player-visible magenta wedge, halo, crop, alpha, hidden-RGB, or chroma
   failure is introduced.

World Art must stop after this A-only packet. A separate integration
disposition is required before repeat processes, sibling authoring, or
normalization.
