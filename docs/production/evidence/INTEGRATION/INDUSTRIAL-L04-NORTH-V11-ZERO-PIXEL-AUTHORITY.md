# Industrial L4 North v11 zero-pixel repair authority

- **Disposition:** `V10_REJECTED_WEST_JAMB_ANALYTIC_GATE`
- **Owner:** Integration
- **Task/lane:** `PLAY-027` / North World Art
- **Published v10 portability base:** `7042f0934903ca54e360725251a96205a347af4e`
- **Imported v10 rejected-evidence commit:** `2dc33a78219c178b21250a10bb4eb3cc12fb4ef0`
- **Imported v10 lineage:** `6d4912fbe57f0498048c862d5c332cdd6e30e904`,
  `cef04037c909b6c5df6559cd5dc7771ecf73ab17`,
  `2dc33a78219c178b21250a10bb4eb3cc12fb4ef0`,
  `7042f0934903ca54e360725251a96205a347af4e`
- **Pixel authority:** none
- **DCC authority:** none
- **Maximum concurrency:** one analytic process

V10 remains rejected. Its portable evidence proves west-jamb un-eroded core
`7`, one-pixel-eroded core `0`, and bounds `3x3`; the required gates are
respectively `>=12`, `>=8`, and at least `3x4`. The same analytic model
regressed from v09 `8` to v10 `7` when the unchanged three-unit jamb moved
inward. No Process A, source pixel, or appearance authority exists.

## Authorized v11 hypothesis

Create exactly one North-only zero-pixel configuration derived from the
published portable v10 bundle:

1. Keep the west jamb inner face fixed at `x = 9.5`.
2. Change only `north-v09-portal-jamb-west.dimensions.x` from `3.0` to `6.0`
   and `position.x` from `8.0` to `6.5`, producing exact X bounds
   `[3.5, 9.5]`.
3. Extend only the matching header cap so its west edge remains aligned:
   change `dimensions.x` from `22.0` to `23.5` and `position.x` from `16.0`
   to `15.25`, producing exact X bounds `[3.5, 27.0]`.
4. Preserve the east jamb inner face at `x = 24.0` and prove the clear portal
   aperture remains exactly `14.5` world units.
5. Preserve the enlarged west jamb and header at least `1.7` world units clear
   of the process hall ending at nominal `x = 1.8`; validate
   `clearance >= 1.7 - 1e-6` to account only for IEEE representation.
6. Change only mechanical v11 revision, task-root, geometry IDs, and derived
   hashes required by those two geometry edits.
7. Preserve all material fields and bindings exactly from v10, including
   `v10-freight-frame` and material SHA-256
   `e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09`.
   The emission hypothesis remains pending actual Cycles proof.
8. Preserve every other component, inset, Y/Z geometry, bevel, camera, light,
   shadow, color-management, Cycles, coordinate-bridge, footprint, pivot,
   socket, contact, and registration field byte-for-byte after normalized
   revision and task-root tokens.

No second geometry parameter set is authorized. Do not move the west jamb
farther inward.

## Required zero-pixel gates

- west jamb un-eroded semantic core `>=12` pixels;
- west jamb one-pixel-eroded semantic core `>=8` pixels;
- west jamb literal bounds at least `3x4`;
- west jamb inner face `x = 9.5`, east jamb inner face `x = 24.0`, and clear
  aperture exactly `14.5`;
- west jamb/header west edge exactly `x = 3.5`;
- west jamb/header satisfy `clearance >= 1.7 - 1e-6` from the process hall;
- east jamb, header, and inset do not regress below v10's `38`, `46`, and `95`
  exact semantic-core pixels;
- correct empty-aperture-to-inset ray order and zero solid aperture overlap;
- hot-process minus primary-mass median remains `>=60`;
- all grayscale tier gaps remain `>=15`;
- compact occupied envelope remains no larger than `64x60`;
- v09 silhouette intersection-over-union remains `>=0.98`;
- pivot `[768,896]`, North socket `[896,704]`, footprint, camera, contact,
  shadow, and registration remain exact; and
- analytic review surfaces contain zero chroma contamination and hidden RGB.

Freight-frame median `62-78`, freight-frame minus primary mass `>=18`,
hot-process minus freight-frame `>=35`, and non-neon appearance remain
`PENDING_ACTUAL_PROCESS_A`. The analytic tool must not claim to prove them.

## Exact roots and execution boundary

The only writable roots are:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v11/`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v11/`

V11 must copy only the exact required v10 portable frozen inputs into its own
task root and record their source paths, source commits, and SHA-256 values.
Every root and child output must begin absent, contain no existing or dangling
symlink component, and resolve lexically and canonically inside the exact task
root. Recheck immediately before every write and use exclusive no-follow
creation. Reject arbitrary paths, pre-existing targets, non-regular inputs,
overwrite attempts, and any shared or sibling root.

Run two fresh analytic replays as separate sequential processes. Their
complete inventories and hashes must be identical. Maximum concurrency is
one. The combined hard envelope is 120 seconds wall time and 512 MiB peak
memory.

The output whitelist is limited to scene/material bindings, normalized
field-diff ledger, validation JSON, literal-`192x128` color/grayscale/semantic
views, v09/v10/v11 comparison, replay-identity receipt, portability receipt,
and zero-pixel handoff.

## Stop conditions

Stop and preserve a rejected checkpoint if:

- any non-whitelisted field, input, file, or root changes;
- the jamb inner face, east jamb, aperture, hall clearance, header alignment,
  or any invariant above differs;
- any semantic, silhouette, compact-envelope, registration, hierarchy, path,
  replay-identity, time, or memory gate fails;
- a second parameter configuration appears necessary; or
- any Blender, Cycles, SceneKit, Metal, ImageGen, normalizer, source Process
  A/B/C, or sibling-direction process starts.

The return must remain `sourceAuthority=false` and
`productionSelected=false`. North Process A/B/C, sibling source pixels,
appearance lock, source admission, Renderer activation, normalization, LODs,
shipping, push, integration, and self-acceptance remain unauthorized.
