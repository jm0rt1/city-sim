# PLAY-027 CONTRACT-019 R5 preflight

`PASS_EXACT_TWO_NODE_SHADER_PREFLIGHT`

The task-owned shader applies a `0.0625` world-depth bias toward the exact
descriptor camera to only:

- `v17-monumental-portal-header-wall`
- `v17-monumental-portal-lintel`

The rule is installed on fresh node-local copies of the actual materials and
on the corresponding fresh constant semantic materials. The geometry shader
SHA-256 is
`589035606fdaaffec8d87ec642d97f030b8e755508f2c435272409725967b7e3`.

The preflight binds unchanged descriptor SHA-256
`3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630`,
unchanged material SHA-256
`147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`,
and exact 51-node manifest
`611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f`.
World transforms, geometry bounds, hit geometry, camera, registration,
sampling, pivot, socket, and descriptor/material bytes remain unchanged.

The conservative union of the two target projections plus two source pixels
of Lanczos support is `[711,612,840,702]` inclusive. R5 outputs must equal
canonical R3-A; any changed pixel outside that support fails closed.

No SceneKit/Metal snapshot, authoritative raw, normalizer, sibling, modeling,
ingestion, shipping, or production-selection process was run.
