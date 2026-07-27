# PLAY-027 Industrial L4 Turbine v08 North resolver authority

- Published baseline before change:
  `48823cb7e3f709a2c3c9a3bff190b2e2a384f0b9`
- Independent renderer disposition: `APPROVE_NARROW_ADMISSION`
- Logical key: `industrial_l04/variant-0`
- Authorized revision: `source-v08-prepixel`
- Authorized direction: North descriptor token `n` only
- Raw processes consumed by this change: `0`
- Source authority: `false`
- Production selected: `false`

Integration admits exactly one accepted pre-pixel descriptor to the
task-owned offline source renderer. The admission does not alter the shipping
renderer, generated-v4 lookup, packaged resources, manifests, or production
selection.

## Exact binding

- Descriptor:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v08-prepixel/scenes/industrial_l04/variant-0/n/scene.json`
- Descriptor SHA-256:
  `9f812479746ba031335aad53f89d562e1f03de0b868b5b533bf43007eb4a9472`
- Geometry ID: `industrial-l04-turbine-v08-n-independent`
- Material library:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v08-prepixel/materials/industrial-l04-turbine-v08-prepixel.json`
- Material SHA-256:
  `f8cf1d4ff9ab4446ec562fe949dd09c45399a32d9a763f7d6dd6380b66e52b94`
- Sampling contract:
  `play027-deterministic-4x-no-msaa-lanczos-v3`
- SceneKit sampling: no MSAA, shadows disabled,
  `authored-constant-v1`
- Orientation transform: `none`
- Authored independently: `true`
- Production selected: `false`

The resolver contains a family-level fail-closed guard. Any other direction,
long-form `north`, variant, revision, revision binding, geometry, material
path or hash, purpose, sampling contract, lighting, shadow mode, antialiasing,
authorship state, production-selection state, or orientation alias is
rejected. Switching both lighting and shadows back to the generic defaults is
also rejected.

## Lighting and shadow disposition

`authored-constant-v1` is intentional: accepted material values carry the
northwest-lit value hierarchy. SceneKit shadow rasterization remains disabled
because it is nondeterministic in this source pipeline. The southeast shadow
continues through the descriptor's authored contact polygon and vector, which
the offline renderer composites deterministically.

## Validation

The focused validator passed one positive case and twenty fail-closed
mutations. Its retained report is:

`docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-resolver/RESOLVER-VALIDATION.json`

Report SHA-256:
`e3ee4fd2c323d147559b2c3d467f94de45b369bef3b52c32b25945dd1ae652c7`.

Fresh compilation used `-parse-as-library -warnings-as-errors` against
`SceneDescriptor.swift`, `RendererArchitecture.swift`, and
`ValidateIndustrialL4V08NorthSamplingResolver.swift`. Existing Industrial L2
source-v04 and Industrial L3 v3/v6 sampling validators also pass after the
change. No SceneKit, Metal, raw, or normalizer process was used.

## Next gate

World Art must merge the published authority containing this contract, then
run three fresh native North source processes. A/B/C must be byte-identical
and decoded-pixel-identical. The lane must retain complete raw and provenance
evidence and stop for independent renderer and QA review before normalization
or any sibling direction.

Rollback is one integration commit: revert the exact predicate, fail-closed
guard, validator, README, and this evidence record together. Any raw produced
under the admission remains non-authoritative unless separately accepted.
