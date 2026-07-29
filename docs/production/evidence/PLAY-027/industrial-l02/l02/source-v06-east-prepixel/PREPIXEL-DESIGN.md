# PLAY-027 Industrial L2 East source-v06 pre-pixel freeze

## Scope

This checkpoint implements only the integration-approved non-coplanar topology
repair for Industrial L2 East. North, South, and West remain exact source-v05
descriptors. No pixel render, normalization, LOD, production selection,
shipping ingestion, or runtime change is present.

## Geometry

The source-v05 high assembly hall occupied:

- `x=-25…13`
- `y=2…44`
- `z=-13…25`

Source-v06 replaces that single volume with:

- left strip: `x=-25…-23`, `y=2…44`, `z=-13…25`;
- right strip: `x=-7…13`, `y=2…44`, `z=-13…25`;
- rear block: `x=-23…-7`, `y=2…44`, `z=-13…11`.

The process tower remains exactly `x=-23…-7`, `y=2.5…50.5`,
`z=11…25`. The repaired hall pieces retain
`i02-v05-corrugated-northwest`; the tower retains
`i02-v05-brick-northwest`.

The hall union, height, footprint, and external silhouette are unchanged. The
tower is now the sole material owner of its camera-visible positive-z facade.

## Frozen contract

- scene: `industrial_l02/variant-0/east/source-v06`;
- geometry ID:
  `industrial-l02-v0-east-integrated-logistics-geometry-v4`;
- independent East descriptor, no sibling transform;
- authored-constant-v1 materials;
- SceneKit shadows disabled;
- SceneKit MSAA none;
- 4x linear render and software Lanczos 0.25;
- schema-2 v3 quantizer, compositor, and canonicalizer unchanged;
- material library byte-identical to source-v05;
- camera, pivot, socket, contact, authored shadow, registration, frontage,
  facade, roof, trim, props, and occlusion records preserved.

## Structural validation

The strengthened validator rejects source-v05 East's exact shared positive-z
material-owner plane at `z=25`, with `x=16` and `y=41.5` overlap. Repaired
source-v06 East has zero coincident Y boundaries and zero camera-visible
coincident material-owner planes.

The same rule was run over every current accepted Residential L1-L4,
Commercial L1-L4, and Industrial L1 descriptor; each has zero visible
coincident material-owner planes. Retained Industrial L2 source-v01 through
source-v05 descriptors were also exercised and preserve their expected
rejection evidence.

`productionSelected` remains false.
