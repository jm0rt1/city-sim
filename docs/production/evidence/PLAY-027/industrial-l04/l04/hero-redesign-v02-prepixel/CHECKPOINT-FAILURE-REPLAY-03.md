# Industrial L4 hero v02 four-field replay failure

- Task: `PLAY-027`
- Parent checkpoint:
  `ae3ee167ef000a4a3e41b1567caa6d4d226beb2c`
- Disposition: `CHECKPOINT_PREPIXEL_VALIDATION_FAILED`
- Source authority: `false`
- Production selected: `false`
- SceneKit/Metal source processes: `0`
- Normalizer processes: `0`
- ImageGen calls: `0`

## Exact authorized input

The replay changed only these four West fields:

| Field | Before | After | Resulting positive face |
|---|---:|---:|---:|
| `w-lower-assembly-wing.position.x` | `11` | `10.5` | `25.5` |
| `w-open-freight-throat.position.z` | `1` | `0.5` | `21.5` |
| `w-silo-b.position.x` | `22` | `21.5` | `25.5` |
| `w-process-headhouse.position.x` | `14` | `13.5` | `19` |

The previously authorized `w-assembly-roof` depth remains `18` at center Z
`-19`. The primary hall, validator, other directions, materials, footprint,
camera, registration, and sampling contract are unchanged.

## Exact single replay

```text
swiftc -module-cache-path /tmp/play027-l4hero-owner-separation-cache \
  -parse-as-library -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4HeroPrepixel.swift \
  -o /tmp/build-industrial-l4-hero-owner-separation

/tmp/build-industrial-l4-hero-owner-separation \
  --repository-root /Users/James/.codex/worktrees/0648/city-sim \
  --output-root /tmp/play027-l4hero-owner-separation-pass \
  --regular-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/regular-industrial-l3-selected.png \
  --compact-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/compact-industrial-l3-selected.png
```

Compilation passed with warnings treated as errors. The one complete replay
stopped at:

```text
visible plane conflict west:
w-lower-assembly-wing / w-silo-b +X
```

The authorized values leave both subordinate owners at positive X `25.5`:

- assembly wing: `10.5 + 30 / 2 = 25.5`;
- silo B: `21.5 + 8 / 2 = 25.5`.

The other four previously recorded owner conflicts cleared. The validator was
not weakened, and no follow-up geometry change or replay was made.

## Retained exact inputs and unrun proof

- material library SHA-256:
  `58b0519f0f5beb68b020b723a8d0b4060701161fecc290408370f6415fee1aa4`
- North descriptor SHA-256:
  `f18e73183c294e63912e00f717e6c1b47344afa78c09b2bc592d6fc73587fdba`
- East descriptor SHA-256:
  `146fa6830e755a3eb359da6d05783ae063d2a42d228d90fa31d43ab4909e1a9e`
- South descriptor SHA-256:
  `de2ae0afca3960a0817f54ad478bcae8da47d591ecd25196ae72e27e4a5764f0`
- West descriptor SHA-256:
  `8a585d4280221dd4bfb8ed12314b3eba14d0e7c42deb131f14370b584305fcd4`

Concept panels, N/E/S/W review panels, review manifest, passing pre-pixel
validation, raw source rendering, normalization, source authority, and
production selection were not created.

No iterative repair is authorized in this checkpoint.
