# Industrial L4 North v12 zero-pixel compound-pier authority

- **Disposition:** `V11_REJECTED_ERODED_CORE_GATE`
- **Owner:** Integration
- **Task/lane:** `PLAY-027` / North World Art
- **Published authority parent:** `aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7`
- **Frozen North head:** `10df430ca1f6c0f26eb2082766791c39f9a18eab`
- **Frozen v11 scene SHA-256:**
  `814d9c2c86a740f04622f4ac47718c14d8f92d090fb127d921270e96ef1921c3`
- **Frozen material SHA-256:**
  `e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09`
- **Frozen analytic builder SHA-256:**
  `b09bd1e809e55ae360eee14b5b96a8e85c168a83a1fbd78b90295e0d00ab50b0`
- **Pixel authority:** none
- **DCC authority:** none
- **Maximum concurrency:** one analytic process

V11 remains rejected. Its retained replay widened the west portal jamb but
still produced zero one-pixel-eroded support. Integration independently
replayed the exact finite compound-pier proposal twice in memory and obtained
byte-identical analytic results. This record authorizes only the corresponding
North zero-pixel implementation and two fresh analytic replays.

## Authorized v12 geometry

Start from the frozen v11 scene and make exactly these changes.

### Compound west portal pier

Use unique physical component IDs. Aggregate their semantic ownership only
after ordinary depth resolution:

1. `v12-west-pier-exterior`
   - box dimensions `[6, 18, 3]`;
   - position `[6.5, 10, -14.3]`;
   - material `v10-freight-frame`;
   - `semanticOwnerID: v12-west-portal-pier`.
2. `v12-west-pier-camera-reveal`
   - vertical triangular prism;
   - exact ordered XZ footprint
     `[[3.5, -12.8], [3.5, -6.8], [9.5, -12.8]]`;
   - exact Y bounds `[1, 19]`;
   - vertices `0...2` use that ordered XZ footprint at `y = 1`;
   - vertices `3...5` use the same order at `y = 19`;
   - exact faces
     `[(0,2,1), (3,4,5), (0,1,4,3), (1,2,5,4), (2,0,3,5)]`;
   - material `v10-freight-frame`;
   - `semanticOwnerID: v12-west-portal-pier`.

Do not reverse, sort, infer, or transform the prism vertices. Do not reuse a
physical ID. Semantic aggregation before physical depth ownership fails the
authority.

### Portal inset segmentation

Replace the prior inset with two unique physical pieces that aggregate only as
`v12-portal-inset`:

- `v12-portal-inset-east`: X `[14, 24]`, Y `[1, 17]`,
  Z `[-10.4, -9.9]`, `semanticOwnerID: v12-portal-inset`;
- `v12-portal-inset-west-lower`: X `[9.5, 14]`, Y `[1, 10]`,
  Z `[-10.4, -9.9]`, `semanticOwnerID: v12-portal-inset`.

### Proven occluder relief

Change only the following physical boundaries:

- `v12-raised-high-bay-main`: X `[-28, 12]`, Y `[25.2, 42.5]`,
  Z `[-8, 22]`, `semanticOwnerID: north-v09-raised-high-bay`;
- `v12-raised-high-bay-east-upper`: X `[12, 16]`, Y `[29.2, 42.5]`,
  Z `[-8, 22]`, `semanticOwnerID: north-v09-raised-high-bay`;
- east-return cap: preserve its high Z and change low Z `4.6 -> 7.0`;
- gantry girder A: preserve high Z `3.7` and change low Z `2.7 -> 3.2`;
- gantry pier east: preserve high Z `5.0` and change low Z `3.0 -> 3.3`;
- east assembly return: preserve high Z `27.4` and change low Z
  `4.4 -> 6.0`.

These inset, high-bay, cap, gantry, and assembly-return edits are authorized
geometry changes. The main foundry hall, portal header, east jamb, all
materials, camera, footprint, pivot, socket, contact, light, shadow, and
registration remain unchanged from v11.

## Physical-boundary rules

The only new or modified intentional welded/contact interfaces are:

- exterior pier to camera reveal at `z = -12.8`;
- inset pieces at `x = 14`, Y `[1, 10]`;
- high-bay pieces at `x = 12`, Y `[29.2, 42.5]`; and
- exterior pier to unchanged header at `y = 19`.

Boolean-union each same-owner segmented pair and remove its internal shared
faces. Preserve unchanged v11 contacts such as the east-jamb/header contact.
Reject any other positive-volume overlap, unintended exposed coincident plane,
duplicate physical ID, or topology inferred from a sibling direction.

## Required zero-pixel gates

Evaluate semantic masks only after physical depth ownership.

- `v12-west-portal-pier` owner pixels `>=24`;
- one-pixel 3x3 eight-neighbor eroded core `>=8`;
- at least one real vertical filled `4x6` owner rectangle;
- selected inclusive rectangle X `105...108`, Y `82...87` is filled by
  `v12-west-portal-pier`;
- compact review domain is zero-based `192x128`: X `0...191`, Y `0...127`;
- the selected rectangle guard is the one-pixel Chebyshev dilation minus the
  rectangle:
  `{104 <= x <= 109, 81 <= y <= 88} \ selectedRectangle`;
- evaluate all 24 guard cells; allow background or
  `v12-west-portal-pier`, except `(108,81)` and `(109,81)`, which must be
  owned by `north-v09-portal-header`;
- any other foreign guard owner fails;
- east jamb, header, and inset owner counts remain at least `38`, `55`, and
  `78`;
- occupied pixels remain exactly `2,277`;
- occupied bounds remain exactly `[64,53,128,112]`;
- v11 silhouette intersection-over-union remains exactly `1.0`;
- hot-process minus primary luma remains `>=60`;
- both grayscale tier gaps remain `>=15`;
- pivot `[768,896]`, North socket `[896,704]`, footprint, camera, contact,
  light, shadow, and registration remain exact; and
- analytic review surfaces contain zero exact chroma, near chroma, and hidden
  RGB.

Freight-frame median, freight-frame minus primary mass, hot-process minus
freight-frame, and non-neon appearance remain
`PENDING_ACTUAL_PROCESS_A`. The analytic tool must not claim to prove them.

## Independent prepublication replay

Two independent in-memory replays produced:

- west owner `56`, bounds `[102,80,110,90]`, eroded core `25`;
- seven filled `4x6` rectangles;
- east/header/inset `38 / 55 / 78`;
- occupied pixels `2,277`, occupied bounds `[64,53,128,112]`;
- silhouette IoU `1.0`;
- hot-process minus primary `63`;
- grayscale gaps `39 / 24`;
- exact chroma / near chroma / hidden RGB `0 / 0 / 0`;
- RGBA SHA-256
  `c8edec18ff9937228aca6a2296f5d5bef47dec4d9712b9e238ed408abe1a41a5`;
- post-depth semantic-owner SHA-256
  `9270a4c358678da8ff7a964c092c8cfcea5f67281d5abf2b857ceb04ff5acf4e`;
  and
- report SHA-256
  `a6a52786185db5ce136e58a7bec547988f4331d213224e99f73832714270dc96`.

Those hashes are prepublication review evidence, not worker output authority.
The worker must produce fresh task-owned replays.

## Exact roots and execution boundary

The only writable roots are:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/`

Copy only the exact required frozen v11 inputs into the v12 task root and
record their source paths, source commits, and SHA-256 values. At the start of
v12 implementation, both v12 roots must be absent. Create the source task root
only through sealed exclusive writes. Immediately before replay A, the sealed
source root must exist and only the replay-A evidence/output targets must be
absent. Before replay B, the sealed replay-A inventory and parent evidence root
must exist; only replay-B targets must be absent. No existing or dangling
symlink component is allowed, and every path must resolve lexically and
canonically inside its exact task root. Recheck immediately before every write
and use exclusive no-follow creation. Reject arbitrary paths, unexpected
pre-existing targets, non-regular inputs, overwrite attempts, and any shared
or sibling root.

Run two fresh analytic replays as separate sequential processes. Their complete
inventories and hashes must be identical. Maximum concurrency is one. The
combined hard envelope is 120 seconds wall time and 512 MiB peak memory.

The output whitelist is limited to scene/material bindings, component/semantic
owner declarations, normalized field-diff ledger, physical-boundary report,
validation JSON, literal-`192x128` color/grayscale/semantic views,
v11/v12 comparison, replay-identity receipt, portability receipt, and
zero-pixel handoff.

## Stop conditions

Stop and preserve a rejected checkpoint if:

- any non-whitelisted field, input, file, or root changes;
- any physical ID, prism vertex, semantic aggregation, guard pixel,
  welded/contact interface, or occluder boundary differs;
- any semantic, silhouette, registration, hierarchy, path, replay-identity,
  time, or memory gate fails;
- a second parameter configuration appears necessary; or
- any Blender, Cycles, SceneKit, Metal, ImageGen, normalizer, source Process
  A/B/C, or sibling-direction process starts.

The return must remain `sourceAuthority=false`,
`candidateReadyForIndependentReview=false`, and
`productionSelected=false`. North Process A/B/C, sibling source pixels,
appearance lock, source admission, Renderer activation, normalization, LODs,
shipping, push, integration, and self-acceptance remain unauthorized.
