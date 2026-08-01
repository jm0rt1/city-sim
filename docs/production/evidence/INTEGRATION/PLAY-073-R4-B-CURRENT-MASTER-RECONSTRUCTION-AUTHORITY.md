# PLAY-073 R4-B Current-Master Reconstruction Authority

**Status:** Integration-published frontier authority

## Identity and disposition

- Published product base: `23fc04ddf50bc3599211f5b9d5139a04d1ad7409`
- Returned renderer candidate: `d906d2dcb1048572831575f7847d27fba6e4cad7`
- Returned product commit: `5f6c4ea35c61f2d377b2a6b4c7ff1cb530dcab93`
- Preserved returned branch: `codex/citysim-world-rendering`
- Clean successor branch: `codex/citysim-world-rendering-r4b-current`
- Canonical visible task: `019f7c8a-69a2-78c2-ae70-fa23ee7bfcd0`
- Canonical worktree: `/Users/James/.codex/worktrees/cac1/city-sim`

Integration rejects direct cherry-pick or merge of the returned candidate. Its
branch merge retained R4-A product bytes after published `master` had reverted
them, so the returned tree is not the published product base. The old branch
and commits remain durable evidence; they are not authorized implementation
inputs.

## Frozen current-tree outcome

Starting only from the exact published base, implement the smallest truthful
R4-B repair that:

1. adds three broad, deterministic, low-frequency outer-terrain material
   regions without replacing, deleting, or changing the current 121-patch
   terrain field, its `materialSpan = 2`, its interaction geometry, or any
   district-ground/public-realm layer;
2. gives each completed ordinary lot a subtle family/variant contact shadow
   and frontage-derived ground treatment using only current authoritative tile
   kind, coordinate, and road frontage;
3. proves adjacent ordinary commercial lots receive visibly distinct current
   renderer context while preserving source identity and gameplay truth; and
4. proves the backdrop contains exactly three regional materials plus the
   existing 121 macro material patches.

The worker may inspect the returned product commit as design evidence only.
It must author the repair against current source bytes. It may not port or
reintroduce the returned branch's `ContextSignature`, template-cache rewrite,
continuous-terrain texture, `materialSpan = 6`, R4-A composition, source-art,
shipping resources, or evidence history.

## Exact mutable surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-073/r4-b-current-master-v1/`

Everything else is read-only. No package, asset, world-art, gameplay,
simulation, UI, store, save, build-script, claim, or shared-authority mutation
is authorized.

## Focused proof and stop

The renderer worker runs only:

- `swift test --package-path Native/CitySimNative --filter WorldRenderingTests`
- candidate-bound JSON validation under the new evidence root
- `git diff --check`

Commit one product checkpoint followed by one evidence checkpoint. Stop on any
shared-contract question, current-base mismatch, path escape, visual ambiguity,
failure outside the focused suite, two unsuccessful repairs, or need to change
the frozen 121-patch architecture. Integration owns the full Swift suite,
staged build, semantic acceptance, integration, push, and independent real-app
QA.
