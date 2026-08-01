# PLAY-073 R4-B current-master technical return

**Disposition:** `RETURN`

**Exact candidate:** `9b63056cfaeb591dd03da9af6e0ff0c80655649a`

**Product commit:** `1bcaad26cd4685038c327381b897084e569e8e93`

**Frozen authority ancestor:**
`6305d0f87f8f31b30e681d94a1882245c403efc9`

**Classification for repair:** `LUNA_LOCAL_DEBUG / gpt-5.6-luna / max`

## Accepted reconstruction

The two-commit candidate is clean and changes only the three authorized
renderer/test files plus the two candidate-bound evidence files. Preserve:

- current-master `materialSpan = 2` and all 121 existing terrain patches;
- exactly three deterministic broad regional materials;
- runtime and ledger use of `districtMaterialVariant`;
- visible variant counts R=4, C=2, industrial/service=3, civic/park=1;
- normalized `x + y` mapping that distinguishes both E/W and N/S neighbors;
- normalized frontage perpendicular;
- no new civic or park treatment;
- truth-neutral ground-only presentation with no gameplay state.

The candidate remains focused-pass evidence only. Full suite, staged build,
subjective visual disposition, accessibility journey, integration, and push
remain Integration/independent-QA owned.

## Reproduced technical blockers

1. The industrial contact-shadow diamond is 66/67 points wide and offset by
   `(1.4, -1.2)`. Its right vertex exceeds the authoritative 72x36 lot
   diamond (`1.0222` for variant 0 and `1.0361` for variant 1 under the
   normalized diamond equation). It can bleed into a road or adjacent lot.
2. The terrain repeat test compares names, node positions, and z-position,
   but regional centers are encoded inside the `CGPath`; all node positions
   are zero. Path or fill drift can pass while `repeatIdentity` is reported as
   passing.
3. Lot-context coverage proves only commercial ground-treatment distinction
   and containment. It does not prove repeated path/position/fill identity,
   residential and industrial/service containment, contact-shadow
   containment, non-interactivity, or explicit civic/park absence.

## Frozen narrow repair

Within the existing five candidate paths only:

1. Reduce or reposition every industrial/service contact-shadow variant so
   every actual path vertex, after node position, remains inside the
   authoritative lot diamond for all four frontages.
2. Add table-driven containment checks for both treatment and contact-shadow
   geometry across residential, commercial, industrial, power-plant, and
   water-tower variants and N/E/S/W frontages.
3. Compare exact deterministic `CGPath` element signatures, node positions,
   z-position, and fill/stroke colors across repeated regional backdrops.
4. Compare same-tile treatment and contact-shadow path, position, z-position,
   fill, and stroke across repeated lot renders.
5. Assert the new nodes have no labels, actions, user interaction, or hit
   semantics and that civic/park lots contain none of them.
6. Preserve all current 121+3, EW/NS distinction, variant-count, truth,
   resource, cache, and performance assertions.
7. Update `RESULT.json` and `HANDOFF.md` only after the expanded focused gate
   passes; report repeat identity only from the new geometry/color proof.

## Exact allowed paths

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-073/r4-b-current-master-v1/RESULT.json`
- `docs/production/evidence/PLAY-073/r4-b-current-master-v1/HANDOFF.md`

Do not edit art sources, resources, package topology, app/UI/gameplay/simulation,
shared authority, claims, scripts, saves, shipping manifests, or legacy Python.

## Gate and stop condition

Run `WorldRenderingTests`, JSON validation, and `git diff --check`. Return one
focused product repair commit and one evidence successor. Stop immediately on
a path outside the exact five, a shared-contract or visual-architecture
decision, a regression outside focused scope, or a second unsuccessful repair.
Do not run the aggregate full suite or staged final journey, self-score,
self-accept, integrate, push, or pin.
