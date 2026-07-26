# PLAY-027 Industrial L2 explicit-box offline capability

Disposition: `PENDING_INDEPENDENT_PREPIXEL_CAPABILITY_REVIEW`.

This checkpoint adds exactly one task-owned offline renderer capability:
`OfflineSceneRenderer.addProp` now accepts `kind: explicit-box`, requires
exactly three strictly positive dimensions, and delegates node creation to the
existing deterministic `boxNode(name:dimensions:position:materialID:)`.

The frozen Industrial L2 N/S/W descriptors, East v05/v06 records, material
library, geometry, sampling, camera, registration, and all pixels are
unchanged.

The focused no-Metal validator proves:

- both frozen North HVAC-bank boxes retain their exact descriptor names;
- their measured SceneKit bounds match `[7, 5, 7]`;
- their positions match the two frozen authored positions;
- all six deterministic mapped material faces resolve to
  `v05-process-metal`;
- they cast authored SceneKit shadows through the existing box path;
- two-component, zero, and negative dimension cases fail closed with the
  exact typed error;
- all four existing supported `explicit-cylinder` props in frozen North retain
  exact names, radii, heights, 32 radial segments, positions, materials, and
  shadow behavior.

The validator replay is byte-identical. Both the production renderer and
validator compile with warnings-as-errors. No capability preflight, Metal
renderer, SceneKit snapshot, raw output, normalization, or West process ran
after the preserved failure checkpoint.

Exact artifacts:

- Renderer source:
  `4fe620e3368f73997bdca7ed5834172e4e0b341e2840a553fcf3c3c48183787f`
- Production renderer binary:
  `f36e9c0c693b3738c9ac4e9fb91866271dbb4eda0589fb62fab4b247bc2052ea`
- Validator source:
  `a0442b9ff5b8b6c3b52a8632ab17a206a1a4b7e67671a70d4be82ae99b9b036d`
- Validator binary:
  `18f1eec7c2ab495006bf0fec3afb7d6fbbedbaa836160b6576003a68078142b0`
- Validation report:
  `eeff82939a6e90c10a651c1143cabe75a6385a0b3b6296d285b063c3a10e4b63`

`sourceAuthority=false` and `productionSelected=false`. North retry and West
remain blocked pending integration review.
