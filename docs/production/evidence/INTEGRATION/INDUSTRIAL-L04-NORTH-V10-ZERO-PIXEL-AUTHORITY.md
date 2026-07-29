# Industrial L4 North v10 zero-pixel repair authority

- **Disposition:** `V09_PROCESS_A_RETURNED_SEMANTIC_AND_VALUE_GATE`
- **Owner:** Integration
- **Task/lane:** `PLAY-027` / North World Art
- **Rejected parent:** `4255b021f743281b60cfdf8cff896235d405be23`
- **Published authority base:** `6382d82ad403287c35ec189a86b821ed71ead8a2`
- **Pixel authority:** none
- **DCC authority:** none
- **Maximum concurrency:** one analytic process

North v09 Process A preserved the intended L4 massing, hot-process hierarchy,
three grayscale tiers, compact envelope, registration, alpha, chroma, padding,
and hidden-RGB safety. It failed two localized actual-pixel gates: the west
portal jamb retained only five exact semantic-core pixels against a minimum of
eight, and the freight-frame median was 12 luma below the primary mass instead
of at least 15 above it. No broader hall, high-bay, court, gantry, furnace,
stack, staff, camera, light, footprint, pivot, socket, or shadow redesign is
authorized.

## Authorized v10 hypothesis

Create exactly one North-only zero-pixel repair configuration:

1. Change only `north-v09-portal-jamb-west.position.x` from `6.5` to `8.0`.
   Preserve its `[3,18,3]` dimensions and prove the remaining clear aperture is
   exactly `14.5` world units.
2. Derive `v10-freight-frame` from `v09-freight-frame`. Preserve
   `baseColorRGBA [0.82,0.64,0.38,1]`, roughness `0.76`, and metalness `0.04`;
   add `emissionStrength 0.30`; bind it only to objects that currently use
   `v09-freight-frame`.
3. Change only mechanical revision, geometry, material-library, and binding
   identifiers and hashes required by those two edits.
4. Preserve every other scene, geometry, material, camera, lighting,
   color-management, shadow, Cycles, coordinate-bridge, and registration
   field byte-for-byte after revision-token normalization.

The emission value is a frozen production hypothesis, not a zero-pixel luma
result. The existing analytic preview does not consume `emissionStrength`.
Zero-pixel work may prove only its exact material-field binding. Freight-frame
median `62–78`, freight-frame minus primary mass `>=18`, hot-process minus
freight-frame `>=35`, and the absence of an emissive/neon appearance remain
`PENDING_ACTUAL_PROCESS_A`. They must be re-proved on exactly one separately
authorized Cycles Process A before any appearance lock.

## Required zero-pixel gates

- west jamb un-eroded semantic core `>=12` pixels;
- west jamb one-pixel-eroded semantic core `>=8` pixels;
- west jamb literal bounds at least `3×4`;
- east jamb, header, and inset do not regress below v09's `38`, `40`, and `91`
  exact semantic-core pixels;
- correct empty-aperture-to-inset ray order and zero solid aperture overlap;
- hot-process minus primary-mass median remains `>=60`;
- all grayscale tier gaps remain `>=15`;
- compact occupied envelope remains no larger than `64×60`;
- v09 silhouette intersection-over-union remains `>=0.98`;
- pivot `[768,896]`, North socket `[896,704]`, footprint, camera, contact,
  shadow, and registration remain exact; and
- analytic review surfaces contain zero chroma contamination and hidden RGB.

## Exact roots and execution boundary

The only writable roots are:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v10/`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v10/`

Both roots and every per-replay child root must be absent before execution,
must contain no existing or dangling symlink component, and must resolve
lexically and canonically inside the exact task root. Reject arbitrary output
paths, pre-existing targets, non-regular inputs, overwrite attempts, and any
path outside the exact whitelist. Recheck before every write. The v09 source
and evidence paths at rejected parent `4255b021...` must remain byte-identical.

Run two fresh analytic replays as separate sequential processes. Their complete
inventories and hashes must be identical. Maximum concurrency is one. The hard
combined envelope is 120 seconds wall time and 512 MiB peak memory; stop before
exceeding either limit.

The exact output whitelist is:

- scene and material bindings;
- normalized field-diff ledger;
- validation JSON;
- literal-`192×128` color, grayscale, and semantic analytic views;
- v08/v09/v10 comparison;
- replay-identity receipt; and
- zero-pixel predesign handoff.

## Stop conditions

Stop and preserve a rejected checkpoint if:

- any non-whitelisted field, file, or root changes;
- the west jamb requires a hall, high-bay, or inset redesign;
- any semantic, silhouette, compact-envelope, registration, aperture,
  hierarchy, path, replay-identity, time, or memory gate fails;
- the analytic tool claims the emission hypothesis has proved Cycles luma;
- a second parameter configuration appears necessary; or
- any Blender, Cycles, SceneKit, Metal, ImageGen, normalizer, source Process
  A/B/C, or sibling-direction process starts.

The return must remain `sourceAuthority=false` and
`productionSelected=false`. North Process A/B/C, East/South/West pixels,
appearance lock, source admission, Renderer activation, normalization, LODs,
shipping, push, integration, and self-acceptance remain unauthorized.
