# PLAY-027 v15 recessed-opening capability

**Disposition:** `PASS_CAPABILITY_ONLY`

The task-owned helper lowers an opening into positive masses only:

- segmented left/right/header/sill wall regions;
- separate positive jamb and lintel frame masses;
- an intentionally empty aperture AABB;
- one inset back plane behind the aperture.

No CSG, alpha deletion, painted rectangle, semantic-only mask, shared
`SceneDescriptor`, shared decoder, renderer, resolver, camera, registration,
shipping, or package change is involved.

The fixed North camera has one deterministic ray which enters the aperture at
distance `172.96889196423874`, intersects no positive solid, and then reaches
`fixture-opening-inset-back-plane` at distance `182.98288044637886`. The
aperture bounds are `[-6,2,-22]` through `[6,14,-18]`; positive-solid overlap
count is zero.

Both fresh processes emitted byte-identical descriptor, literal-192 color,
literal-192 grayscale, and structural report.

`sourceAuthority=false`

`productionSelected=false`
