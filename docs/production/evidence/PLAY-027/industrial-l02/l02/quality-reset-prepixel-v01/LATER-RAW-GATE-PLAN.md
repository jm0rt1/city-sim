# PLAY-027 Industrial L2 later 12-process raw gate

Status: plan only. No process in this plan is authorized by the current
pre-pixel checkpoint.

## Required preconditions

1. Independent review accepts the exact four design descriptor hashes and
   material library SHA in this packet.
2. Integration separately authorizes a source-authority revision derived from
   `quality-reset-prepixel-v01`.
3. The task-owned offline scene schema is extended, if needed, for the frozen
   recess, panel, drainage, rail, pipe, and material-role primitives without
   changing camera, footprint, pivot, socket, light, or authored contact
   shadow.
4. Four production descriptors are frozen and proven traceable component for
   component to these design descriptors. The production descriptor, material
   library, renderer source, binary, SDK, Metal device, and toolchain hashes
   are recorded before the first process.
5. The renderer rejects diagnostic CLI authority and resolves the
   descriptor-bound schema-2 v3 path: SceneKit MSAA none, fixed 4x linear
   oversampling, software Lanczos scale 0.25/aspect 1, frozen step-32
   quantizer, immutable v3 post-quantization canonicalizer, and no finite
   equivalence table or global pre-Lanczos canonicalization.

## Exact process matrix

Each row is a fresh Metal-visible process with no diagnostic switch:

| Sequence | Direction | Attempt | Output stem |
|---:|---|---|---|
| 1 | North | A | `north/source-quality-reset-v01` |
| 2 | East | A | `east/source-quality-reset-v01` |
| 3 | South | A | `south/source-quality-reset-v01` |
| 4 | West | A | `west/source-quality-reset-v01` |
| 5 | North | B | `repeat/north-run-b` |
| 6 | East | B | `repeat/east-run-b` |
| 7 | South | B | `repeat/south-run-b` |
| 8 | West | B | `repeat/west-run-b` |
| 9 | North | C | `repeat/north-run-c` |
| 10 | East | C | `repeat/east-run-c` |
| 11 | South | C | `repeat/south-run-c` |
| 12 | West | C | `repeat/west-run-c` |

Each process uses:

```text
offline-scene-renderer
  --repository-root <exact-worktree>
  --scene <frozen-direction-production-descriptor>
  --materials <frozen-quality-reset-material-library>
  --output <task-owned-governed-raw-path>
  --record <matching-task-owned-provenance-path>
  --renderer-source-commit <exact-authority>
  --backend-capability-record <matching-capability-json>
```

No process may reuse a renderer instance, SceneKit scene, Metal command queue,
or output file. Every attempt retains its own capability and provenance
record.

## Binding raw gates before normalization

1. 3/3 exact PNG file SHA-256 identity per direction.
2. 3/3 exact canonical decoded RGBA SHA-256 identity per direction.
3. Four unique primary file and decoded-pixel identities.
4. Complete alpha-visible and non-chroma occupied bounds with zero hidden
   non-magenta RGB, zero chroma spill, opaque chroma corners, and stable
   occupied area.
5. Exact source footprint, `(768,896)` pivot, four declared sockets, southeast
   authored contact shadow, and frontage registration.
6. No sibling transform, mirror, rotation, alias, fallback, or cross-family
   source substitution.
7. Literal source-scale, occupied-crop, native-2x color, native-2x grayscale,
   footprint, and zoom review sheets. North and West must retain the grounded
   far-edge portal; East and South must retain three readable dock recesses.
8. L1-vs-L2 plus Residential/Commercial comparison must show the L2 stepped
   administration/production/process hierarchy without storefront,
   residential, or L1 silhouette aliasing.
9. Accepted Residential L1-L4, Commercial L1-L4, and Industrial L1 owned
   source bytes remain identical to the pre-gate preservation manifest.

The first failed gate freezes all twelve attempts and stops. No rerender,
repair, normalization, LOD generation, or production selection occurs without
a new integration disposition. Only a separately approved raw packet may
advance to two-run block/neighborhood/city normalization.
