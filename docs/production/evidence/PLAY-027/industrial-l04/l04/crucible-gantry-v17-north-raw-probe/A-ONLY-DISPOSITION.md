# PLAY-027 Industrial L4 v17 North A-only raw-probe disposition

- Baseline and renderer source commit:
  `5ee718b0544064557f6b92695eb70edf5ccb0c8c`
- Authorized Metal-visible raw processes: `1`
- Consumed Metal-visible raw processes: `1`
- Repeat, sibling, and normalizer processes: `0`
- Source authority: `false`
- Production selected: `false`
- Disposition: `REJECTED_PLAYER_VISIBLE_NEAR_CHROMA`

The single authorized North A process completed with the exact published
descriptor, material, geometry, camera, registration, sampling, and resolver
bindings. The raw is complete and retained unchanged:

- raw PNG SHA-256:
  `9aea278d4fe7640a4dd126c4393fd284f2849f80168b5e62d6e8dbe2cf75c5d7`
- decoded RGBA SHA-256:
  `0d9ca24f63de0f17c72cd36c38b742bd6fe6aca8aaee60c987a541af952e620f`
- provenance SHA-256:
  `57626baf2c5244e593e91546992c96154f7bc9c16c2e8c98e79879759ea9ac54`
- renderer binary SHA-256:
  `da2c8c420f4c4fe3ef8d2e0706cd2a640190c0b6fa89d79e8b89b843ab1b08e6`
- occupied bounds: `[509, 523, 1026, 897]`
- occupied pixels: `118721`
- hidden RGB at alpha zero: `0`

## Binding first failure

Exact-chroma removal leaves `1807` opaque non-exact near-magenta pixels over
source bounds `[509, 523, 1026, 897]`. They are visibly attached to the
building silhouette and southeast contact/footprint edge in the literal
192x128, native-2x, and occupied-crop color panels. The result therefore fails
the authority's no-visible-magenta-wedge-or-halo gate. Thresholds were not
relaxed, the result was not normalized, and no additional raw process was run.

Portal, crucible, hierarchy, and registration evidence is retained for
independent diagnosis, but cannot override this first failed gate.

## Process accounting

The initial sandbox capability check found no visible Metal device and stopped
before scene preparation, scene construction, or candidate output. It consumed
no raw process. Its exact record is retained as
`diagnostics/north/run-a/capability-sandbox-preflight.json` with SHA-256
`29bda6eac97d2f5261caa411946d430f4ba2b7fcda8d25206e98f6b298eba15b`.
The subsequent native invocation is the sole Metal-visible A process.

The no-Metal review builder compiled with warnings as errors:

- builder source SHA-256:
  `99b580b587a5a78fe3e32d39bb3c1c4698d3de6b6c25318a0de6c8f64e1a9e11`
- builder binary SHA-256:
  `6af94ad6c48e0b503328b4893388231567fed3e0850af38a8ef39eef5fb47a4c`
- two fresh review roots: byte-identical
- committed review inventory aggregate SHA-256:
  `53a4fcfff45887f0464572b36866be748877446d46e56ccdcb0c8fe8b78420c4`

The exact machine report is `review/RAW-PROBE-REVIEW.json`; its bound panel
inventory is `review/PACKET-MANIFEST.json`.
