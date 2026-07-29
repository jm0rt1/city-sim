# Industrial L4 hero v02 final narrow replay failure

- Task: `PLAY-027`
- Parent checkpoint:
  `b075cdaf3e0b77563348ec4579400f0a573e3b5a`
- Disposition: `CHECKPOINT_PREPIXEL_VALIDATION_FAILED`
- Source authority: `false`
- Production selected: `false`
- SceneKit/Metal source processes: `0`
- Normalizer processes: `0`
- ImageGen calls: `0`

## Exact authorized input

The final narrow replay changed only:

| Field | Before | After | Resulting positive face |
|---|---:|---:|---:|
| `w-silo-b.position.x` | `21.5` | `21.0` | `25.0` |

The lower assembly positive X remains `25.5`, and the primary hall positive X
remains `26.0`. The generator and its checked-in derived West descriptor carry
the same single semantic change. The validator, other directions, materials,
footprint, primary hall, previously corrected roof depth, camera,
registration, and sampling contract are unchanged.

## Exact compile and single replay

```text
swiftc \
  -module-cache-path /tmp/play027-l4hero-final-replay-cache \
  -parse-as-library \
  -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4HeroPrepixel.swift \
  -o /tmp/build-industrial-l4-hero-final-replay

test ! -e /tmp/play027-l4hero-final-replay-b075cda &&
/tmp/build-industrial-l4-hero-final-replay \
  --repository-root /Users/James/.codex/worktrees/0648/city-sim \
  --output-root /tmp/play027-l4hero-final-replay-b075cda \
  --regular-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/regular-industrial-l3-selected.png \
  --compact-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/compact-industrial-l3-selected.png
```

Compilation passed with warnings treated as errors. The one complete replay
stopped at:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level:
insufficient material value separation
```

The owner-separation gate passed far enough to reach the later immutable
material-value gate. That gate requires at least seven distinct predicted
post-step-32 luma bins. The unchanged material library provides five:

```text
[8, 40, 72, 104, 136]
```

No threshold, material, geometry, or validator adjustment was made, and no
second replay was consumed.

## Exact retained inputs and unrun proof

- pre-pixel builder SHA-256:
  `d12dce63472511e9f7b89aad43b08726a4523ad6aabf4155f26205ba0b657af7`
- material library SHA-256:
  `58b0519f0f5beb68b020b723a8d0b4060701161fecc290408370f6415fee1aa4`
- North descriptor SHA-256:
  `f18e73183c294e63912e00f717e6c1b47344afa78c09b2bc592d6fc73587fdba`
- East descriptor SHA-256:
  `146fa6830e755a3eb359da6d05783ae063d2a42d228d90fa31d43ab4909e1a9e`
- South descriptor SHA-256:
  `de2ae0afca3960a0817f54ad478bcae8da47d591ecd25196ae72e27e4a5764f0`
- West descriptor SHA-256:
  `66db247d7f56a44c5b8e29cb6b9b16e47a0b7f596fc230da834f521d607cb981`

The replay output root contains only the five exact input artifacts listed
above: four descriptors and the material library, with matching hashes. No
concept panel, N/E/S/W review panel, review manifest, passing pre-pixel
validation, raw source render, normalization, source authority, or production
selection was created.

No additional repair or replay is authorized in this checkpoint.
