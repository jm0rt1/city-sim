# PLAY-027 Industrial L3 source-v06 promotion authority

- Exact North diagnostic pass:
  `86ae9c6e51f271988dbb3f84800f45fd4ed6375b`
- Exact West matrix pass:
  `9a384ebceef0a4dadd64b980950d8fe2a9d4137e`
- Integration disposition: `SELECT_N2_AND_W1_AUTHORIZE_PREPIXEL_V06`
- Authorized logical key: `industrial_l03/variant-0`
- Authorized directions: North and West only
- Authorized revision: `source-v06`
- SceneKit/raw processes: `0`
- Normalization: `false`
- Source authority: `false`
- Family authority: `false`
- Production selected: `false`

Integration selects the two smallest independently proven recipes:

| Direction | Exact source-v05 descriptor SHA-256 | Selected diagnostic material SHA-256 | Selected channel deltas |
|---|---|---|---|
| North | `a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61` | `33ff7c3424594a05bf9eea94958f33e82f186b7ed5b99ea3d736b0852342dd58` | `l3c-charcoal-outline-steel.red +2/255`; `l3c-warm-trim.red +3/255` |
| West | `56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc` | `59a450c842058067d35374b041a4f5a263eb2ffb02c010e90bc156a1a3430d52` | `l3c-charcoal-outline-steel.red +2/255`; `l3c-warm-formed-concrete.blue +2/255` |

North passed three fresh processes with identical raw SHA-256
`91b3fb983e294eeff288b13f6d89a19366393cfaf084b52527633e88ed0507ea`
and decoded-RGBA SHA-256
`ca087fb06b5bcc67ea101f661ac07a5a1b263d5b3b32db4d1c6d8aa7d18764af`.
West passed three fresh processes with identical raw SHA-256
`ceaa2948be0f37cbd8f6288c9c125f15502a864ce683bc3eaa1cd0d7563477d4`
and decoded-RGBA SHA-256
`f66b4fe3cde165e0c3852ce5aa0863ec7380824f46e81708804428b6717be310`.

## Direction-scoped material contract

Create one source-v06 North material library and one source-v06 West material
library. Direction-scoped libraries are required because combining both
recipes into a shared library would apply untested warm-trim changes to West
and untested warm-concrete changes to North.

Each new library must be a semantic copy of the exact selected diagnostic
material file for its direction. Only task-owned library identity and
provenance fields needed to name source-v06 may change. Material ordering,
material assignments, unlisted base-color channels, patterns, physical scale,
roughness, metalness, texture mapping, and every other rendering value must
remain identical to the selected diagnostic input.

## Direction-scoped descriptor contract

Create dedicated North and West source-v06 descriptors from the exact
source-v05 descriptors bound above. Each descriptor may change only:

1. `sourceRevision` and `provenance.sourceRevisionBinding` to `source-v06`;
2. `sceneGeometryID` to a direction-specific source-v06 identity;
3. `materialLibrary.file` and `materialLibrary.sha256` to its direction-scoped
   source-v06 library;
4. task-owned provenance fields needed to cite the selected diagnostic
   checkpoint and recipe; and
5. any task-owned catalog identity whose sole function is naming this revision.

Geometry, transforms, camera, sampling contract, footprint, pivot, socket,
door base, height, light, shadow, props, frontage, materials assigned to
primitives, and all unlisted values must remain unchanged.

## Required pre-pixel gate

Before any resolver edit or raw render, retain and commit:

- exact source-v05, selected diagnostic, and source-v06 descriptor/material
  hashes;
- a machine-readable semantic diff proving only the authorized identity,
  provenance, pointer, and selected material-channel changes;
- replay-identical scene geometry, structural, frontage, pivot, socket,
  registration, bounds, and sampling-contract reports;
- enlarged and native-scale color/grayscale material swatches for each
  direction;
- proof that North and West use different library files and that each
  descriptor resolves only its own library hash;
- negative tests rejecting a swapped North/West material library;
- explicit `sourceAuthority=false`, `familyAuthority=false`, and
  `productionSelected=false`.

Commit one clean pre-pixel source-v06 checkpoint and stop. Report the exact
North/West descriptor paths and SHA-256 values, material paths and SHA-256
values, geometry IDs, validator/tool hashes, and evidence root.

Do not edit the source-v05 inputs, the sampling resolver, canonicalizer,
normalizer, East/South, renderer shipping code, package topology, or shared
manifests; do not render pixels, normalize, begin L4/A2, push, or self-accept.
