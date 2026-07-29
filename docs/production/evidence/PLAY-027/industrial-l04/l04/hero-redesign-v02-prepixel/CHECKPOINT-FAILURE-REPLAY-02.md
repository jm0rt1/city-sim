# Industrial L4 hero v02 single-replay failure

- Task: `PLAY-027`
- Parent checkpoint:
  `d430da2c090913ddce9c2e453cfe5c8982808670`
- Disposition: `CHECKPOINT_PREPIXEL_VALIDATION_FAILED`
- Source authority: `false`
- Production selected: `false`
- SceneKit/Metal source processes: `0`
- Normalizer processes: `0`
- ImageGen calls: `0`

## Authorized correction

Exactly one geometry field changed from the preserved checkpoint:

- primitive: `w-assembly-roof`;
- center Z: `-19` unchanged;
- depth: `19` to `18`;
- resulting Z extent: `[-28, -10]`, matching the underlying
  `w-lower-assembly-wing` and the frozen `[-28, 28]` footprint.

No other geometry, material, descriptor, camera, sampling, validator, or
authority field was changed before the replay.

## Exact replay

```text
swiftc -module-cache-path /tmp/play027-l4hero-resume-cache \
  -parse-as-library -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4HeroPrepixel.swift \
  -o /tmp/build-industrial-l4-hero-prepixel-resume

/tmp/build-industrial-l4-hero-prepixel-resume \
  --repository-root /Users/James/.codex/worktrees/0648/city-sim \
  --regular-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/regular-industrial-l3-selected.png \
  --compact-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/compact-industrial-l3-selected.png
```

Compilation passed with warnings treated as errors. The one complete
pre-pixel replay then failed at the West camera-visible coincident
structural/material-owner gate:

```text
visible plane conflict west:
high-bay-forge-hall / lower-assembly-wing +X
high-bay-forge-hall / open-freight-throat +Z
high-bay-forge-hall / silo-b +X
lower-assembly-wing / silo-b +X
process-headhouse / monitor-clerestory +X
```

Exact shared positive-face coordinates:

| Face | First owner | Second owner | Coordinate |
|---|---|---|---:|
| `+X` | `w-high-bay-forge-hall` | `w-lower-assembly-wing` | `26` |
| `+Z` | `w-high-bay-forge-hall` | `w-open-freight-throat` | `22` |
| `+X` | `w-high-bay-forge-hall` | `w-silo-b` | `26` |
| `+X` | `w-lower-assembly-wing` | `w-silo-b` | `26` |
| `+X` | `w-process-headhouse` | `w-monitor-clerestory` | `19.5` |

The validator was not weakened. The generated material library and four
descriptors are retained as failed replay inputs with unique hashes. Review
panels, review manifest, pre-pixel validation result, raw source rendering,
normalization, source authority, and production selection were not run or
created.

No further geometry adjustment is authorized in this checkpoint.
