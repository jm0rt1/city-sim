# PLAY-027 Commercial L4 source-v03 design and sampling freeze

## Authority

Integration independently approved the schema-2 v3 sampling contract and its
full accepted-source regression at request `5259947` and packet
`a337a4f8b56c849f15d6be5833d1d22553f58d69`. That disposition authorizes
exactly one separately authored Commercial L4 `source-v03` N/E/S/W set.

Commercial L4 `source-v01` and `source-v02` remain rejected and preserved.
Their evidence isolates the failure to legacy SceneKit MSAA sampling; the
complete tower architecture, frontage, registration, and non-coplanar
descriptor repair remain valid.

## Frozen source-v03 architecture

`source-v03` retains the independently authored source-v02 tower design
without geometry changes:

- eight-floor premium commercial tower;
- stone retail and monumental lobby podium;
- stepped limestone and burgundy office shafts;
- copper executive crown and screened mechanical penthouse;
- direction-specific storefront/lobby, facade rhythm, rooftop props, and
  occlusion exclusions;
- 56 x 56 world-unit footprint, source pivot `[768, 896]`, exact directional
  frontage socket and door base;
- northwest key light, southeast shadow vector `[2, 1]`;
- no sibling mirror, rotation, transform, alias, or fallback.

The exact source-v02 descriptors are retained under
`source-v02-rejected/descriptors/`. The source-v03 descriptor manifest proves
that the authored payload is unchanged after excluding only schema,
source-revision, geometry-identity, toolchain-fingerprint, sampling, and camera
oversampling metadata.

## Frozen sampling contract

Every source-v03 descriptor binds:

- schema 2 and `sourceRevision: source-v03`;
- `play027-deterministic-4x-no-msaa-lanczos-v3`;
- `purpose: source-authority`;
- SceneKit antialiasing `none`;
- linear oversampling factor 4;
- software `CILanczosScaleTransform` at scale 0.25 and aspect 1;
- frozen step-32/midpoint-offset-8 quantization;
- immutable opaque/chroma-free 3x3 one-quantum canonicalizer v3;
- the narrowly approved one-boundary-vote 6+1 extension;
- ImageIO plus `/usr/bin/sips` deterministic PNG canonicalization;
- `productionSelected: false`.

## Pre-pixel gate

- Four descriptor hashes: unique.
- Four scene geometry IDs: unique.
- Four immutable authored payloads: unchanged from retained source-v02.
- Scene validation: pass with 100 windows per direction, exact registration,
  distinct directional entrance/frontage, and no sibling derivation.
- Structural boundary validation: zero coincident authored boundaries in every
  direction.
- Accepted Commercial L1-L3 raw, normalized, provenance, and scene surfaces:
  unchanged.

No source-v03 render may be normalized or reviewed unless three fresh
processes per direction are byte/pixel identical and exact retained RGBA
visibility passes. Commercial L4 remains non-shipping and unselected.
