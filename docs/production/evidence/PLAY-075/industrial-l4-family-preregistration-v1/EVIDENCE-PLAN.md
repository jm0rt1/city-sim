# PLAY-075 Industrial L4 candidate evidence plan

For exact future renderer candidate `<candidate>`, retain evidence under:

`docs/production/evidence/PLAY-075/industrial-l4-family-<candidate>/`

## Identity

- `IDENTITY.md`
- `identity/source-candidate.txt`
- `identity/product-candidate.txt`
- `identity/ancestry.txt`
- `identity/source-tree.manifest`
- `identity/staged-tree.manifest`
- `identity/executable.sha256`
- `identity/staging-manifest.sha256`
- `identity/generated-v4-source.sha256`
- `identity/generated-v4-staged.sha256`
- `identity/direction-bridge-authority.txt`
- `identity/direction-bridge-mapping.sha256`
- `identity/runtime-direction-source-pixel-sockets.json`
- `identity/fixture-completed.sha256`
- `identity/fixture-construction.sha256`
- `identity/fixture-condition.sha256`
- `identity/process.txt`
- `identity/window-and-camera.csv`

## Live visual matrix

For each of `regular` and `compact`, and each of `north`, `east`, `south`,
`west`, retain:

- `live/<width>/<direction>/city-color.png`
- `live/<width>/<direction>/city-grayscale.png`
- `live/<width>/<direction>/neighborhood-color.png`
- `live/<width>/<direction>/neighborhood-grayscale.png`
- `live/<width>/<direction>/block-color.png`
- `live/<width>/<direction>/block-grayscale.png`
- `live/<width>/<direction>/selected-pointer.png`
- `live/<width>/<direction>/selected-keyboard.png`
- `live/<width>/<direction>/details.ax.txt`

Also retain:

- `live/regular/family-city.png`
- `live/compact/family-city.png`
- `live/regular/construction-north.png`
- `live/compact/construction-north.png`
- `live/regular/condition-west.png`
- `live/compact/condition-west.png`
- `live/regular/demolished.png`
- `live/regular/undo-restored.png`
- `live/reduce-motion/compact-three-lods.png`
- `live/accessibility/fka.png`
- `live/accessibility/voiceover.txt`
- `live/comparison/l3-vs-l4-regular.png`
- `live/comparison/l3-vs-l4-compact.png`
- `live/comparison/l3-vs-l4-grayscale.png`

Every PNG must be original-resolution and uncropped. The identity ledger must
bind width, content size, PID, fixture digest, target player block, semantic
LOD, canonical camera target, overlay, Focus City state, Details state,
Reduce Motion state, timestamp, and SHA-256.

## Interaction and state

- `interaction/pointer-keyboard.csv`
- `interaction/ax-ledger.csv`
- `interaction/demolition-undo-ledger.json`
- `interaction/before-save.sha256`
- `interaction/after-undo-save.sha256`
- `interaction/reduce-motion-ledger.csv`

The demolition/Undo ledger must record the exact before, demolished, and
restored state fingerprints. Before and restored must match exactly.

## Pack and performance

- `validation/world-asset-pack-report.json`
- `validation/directional-source-pack-runtime.csv`
- `validation/atomic-four-direction-admission.json`
- `validation/fallback-and-alias-ledger.json`
- `validation/registration-and-overlap.json`
- `validation/two-build-identity.txt`
- `performance/frame-and-lod.json`
- `performance/rss-footprint.csv`
- `performance/node-drawable-action.csv`
- `performance/process-termination.txt`

`identity/direction-bridge-authority.txt` must bind accepted source authority
`3e01ca6738d7574718f9aeff4b66771eee109feb` through published Integration
authority `aa20d5963c356eee812f66bafff8582215293bbb`.
`identity/direction-bridge-mapping.sha256` must equal
`5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7`.
The socket ledger must use `citysim_source_pixels_v1` and exact North
`[896,704]`, East `[896,832]`, South `[640,832]`, and West `[640,704]`
sockets. The atomic admission record must fail closed unless all four
directions are present in the same exact renderer candidate; a one-, two-, or
three-direction packet is not eligible for a staged-app score.

## Final records

- `VALIDATION.md`
- `DEFECTS.md`
- `DISPOSITION.md`
- `SHA256SUMS`

`DISPOSITION.md` must return one exact-candidate `APPROVE` or `RETURN`, state
all partial/blocked checks explicitly, and repeat that a focused family
approval is not the final PLAY-075 release disposition.
