# PLAY-027 Commercial L1-L4 alias audit and production plan

## Authority and ownership

- Published authority: `1d4d4f7eba1bb1cf3c8d64b1c221f33d3be91637`.
- Authorized slice: Commercial L1-L4 variant-zero N/E/S/W, sixteen sources.
- Accepted Residential L1-L4 files are immutable comparison and registration
  inputs. The final ownership audit compares every Residential OfflineScene
  path against this authority.
- Commercial sources remain non-shipping and `productionSelected: false`.
- Industrial, renderer, atlas, manifest, package, build, runtime, gameplay,
  simulation, UI, and save surfaces are outside the claim.

## Read-only catalog audit

No task-owned Commercial OfflineScene descriptor, raw, normalized source,
provenance record, or review sheet exists at the published authority. The
sixteen authorized keys therefore begin uncovered rather than aliased.

The historical generated-v4 `commercial_l01/source-v01.png` is used only as an
appearance/family anchor. It does not supply geometry, pixels, a sibling scene,
or a directional raster. Its SHA-256 is
`90207ec4ed651810df863e0ff21591c85eea444f8606c41c83e85060e4c1de89`.

## Controlled level sequence

1. Commercial L1: two-floor corner shop with broad display glazing, recessed
   shopfront, flat coping, and a small rooftop mechanical cabinet.
2. Commercial L2: three-floor market/arcade with a heavier stone base,
   projecting corner bay, continuous arcade canopy, and grouped HVAC.
3. Commercial L3: five-floor office/department block with a setback wing,
   vertical office-window rhythm, strong lobby, and screened roof plant.
4. Commercial L4: eight-floor urban office tower with a commercial podium,
   stepped curtain-wall shaft, crown, and materially larger mechanical roof.

Each level freezes its four independent descriptors before rendering. Each
retained source is rerendered in a separate native process for pixel identity,
normalized twice with the unchanged deterministic normalizer, validated at
raw and all three LODs, and reviewed through source-scale, native-2x
normalized-alpha, grayscale, registered-footprint, and zoom panels.

After two direction failures within one level, production stops for local
template/anchor redesign rather than continuing prompt or geometry churn.

## Current controlled checkpoint

Commercial L1 `source-v04` is accepted non-shipping source-art authority at
`9718b5e63d6322daa5b9616aea31244b3f3d6629`. Its exact packet is documented in
`l01/SOURCE-V04-REVIEW-CANDIDATE.md`; `productionSelected` remains false.

Commercial L2 `source-v01` is the current clean review candidate. It preserves
four independently authored descriptors, three-process raw identity,
two-process normalized identity, twelve unique direction/LOD pixel hashes,
exact RGBA visibility, stable registration, and the complete color,
grayscale, registered-footprint, zoom, and source-scale review packet under
`l02/`. Commercial L3/L4 remain blocked until this L2 candidate is
independently reviewed and integration publishes further authority.
