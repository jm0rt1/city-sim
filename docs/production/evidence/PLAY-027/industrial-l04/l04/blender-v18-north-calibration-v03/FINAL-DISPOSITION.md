# PLAY-027 CONTRACT-020 R3 North calibration disposition

Disposition: `PENDING_INDEPENDENT_RENDERER_QA_REVIEW`

The final mechanical ground-plane calibration passes its authorized gates:

- three fresh factory-startup Blender/Cycles CPU processes;
- raw decoded premultiplied RGBA identity:
  `2e7609ec4f899bdc0c9661f26b6e28f226de2c2d7ffea54177e3b4f8368514fd`;
- semantic decoded premultiplied RGBA identity:
  `e56d557fcfc09fa4308b4d1078e11843f5de4c19c6ccae68ac094a3e90d9f155`;
- raw occupied bounds identity: `[440,525,1025,933]`;
- semantic occupied bounds identity: `[511,525,1025,897]`;
- zero hidden RGB, exact chroma, or near chroma at nonzero alpha;
- exact 51-component mappings and ground projection proofs across A/B/C;
- two no-render packet replays with byte-identical 13-panel inventories and
  final result.

The configured camera projects the governed footprint, pivot, North socket,
and origin from actual CitySim ground `y = 0` within `0.00018310546875` source
pixel. R2-to-R3 evidence records the intended 64-source-pixel upward correction:
the raw occupied top moved `589 → 525`, and the semantic occupied top moved
`589 → 525`. The one-pixel edge-bound variation and retained decoded differences
are documented as subpixel resampling from the corrected camera shift; the
descriptor, geometry, material, camera position/target, light, contact, and
Cycles inputs remain hash-bound and unchanged.

PNG file hashes differ because Blender retains per-process container metadata;
canonical decoded RGBA, component mappings, projection proofs, bounds, and
deterministic packet outputs are identical. This checkpoint does not accept the
current art, source authority, production selection, siblings, normalization,
ingestion, shipping, or product mutation.

Primary review evidence:

- `FINAL-RESULT.json`
- `PACKET-REPLAY-IDENTITY.json`
- `diagnostics/RAW-IDENTITY.json`
- `diagnostics/SEMANTIC-IDENTITY.json`
- `diagnostics/R2-R3-RAW-GROUND-CORRECTION.json`
- `diagnostics/R2-R3-SEMANTIC-GROUND-CORRECTION.json`
- `review/R2-VS-R3-SOURCE-COLOR.png`
- `review/R2-VS-R3-EXACT-192X128-COLOR-GRAYSCALE.png`
