# PLAY-027 Commercial L4 West renderer diagnostic plan

## Frozen inputs

- rejected source checkpoint:
  `dbaab46d3afa41f198a0c20a1f3f66d8c55bd775`;
- retained pixel-locality checkpoint:
  `d759f6fdb17209889f7fdee3460870fd0b26a54c`;
- scene:
  `commercial_l04/variant-0/west/source-v02`;
- descriptor SHA-256:
  `7ec24286982735476cc377dd3420bec2beafd905ac5443bc1cc0cc390bff27cc`;
- camera, oversampling factor, materials, registration, geometry, light
  direction, and deterministic registered footprint shadow remain fixed.

No `source-v03` descriptor or accepted raw/normalized path may be created.
Every diagnostic PNG and provenance record remains under the task-owned
`docs/production/evidence/PLAY-027/.../l04/diagnostics/` tree and has no
source-art authority.

## Ordered isolation

1. Retained primary/B/C locality is already frozen in
   `source-v02-west-pixel-locality/`.
2. Render West in at least three fresh processes with SceneKit MSAA disabled
   and current SceneKit shadows.
3. Only if step 2 still splits, render West with current 4x MSAA and SceneKit
   shadows disabled.
4. Only if step 3 still splits, add task-owned renderer-node/group isolation
   around the upper-shaft window/frame seam. Authored scene geometry remains
   frozen.

The first isolation that converts the retained split to exact repeated pixel
identity identifies the causal renderer stage. If no isolation does, stop with
the exact retained evidence rather than changing art.
