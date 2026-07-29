# Industrial L4 hero v02 material-value replay failure

- Task: `PLAY-027`
- Parent checkpoint:
  `c217214f17adab24c5776e8636041019c1fd6a35`
- Disposition: `CHECKPOINT_PREPIXEL_VALIDATION_FAILED`
- Source authority: `false`
- Production selected: `false`
- SceneKit/Metal source processes: `0`
- Normalizer processes: `0`
- ImageGen calls: `0`

## Exact authorized material input

Only these two small-area material base colors changed:

| Material | Before | After | Predicted step-32 luma |
|---|---|---|---:|
| `l4-light-trim` | `[0.68, 0.55, 0.36, 1]` | `[0.82, 0.70, 0.50, 1]` | `168` |
| `l4-warm-glazing` | `[0.67, 0.42, 0.19, 1]` | `[0.96, 0.78, 0.42, 1]` | `200` |

All geometry, validator thresholds, contracts, other materials, footprint,
camera, registration, and sampling inputs remain unchanged. The four
descriptor material-library hashes were mechanically rebound to the exact
changed library; every other descriptor field is unchanged.

The predicted material ladder is exactly:

```text
[8, 40, 72, 104, 136, 168, 200]
```

## Exact compile and single replay

```text
swiftc \
  -module-cache-path /tmp/play027-l4hero-material-value-cache \
  -parse-as-library \
  -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4HeroPrepixel.swift \
  -o /tmp/build-industrial-l4-hero-material-value

test ! -e /tmp/play027-l4hero-material-value-pass-c217214 &&
/tmp/build-industrial-l4-hero-material-value \
  --repository-root /Users/James/.codex/worktrees/0648/city-sim \
  --output-root /tmp/play027-l4hero-material-value-pass-c217214 \
  --regular-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/regular-industrial-l3-selected.png \
  --compact-staged-frame /Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-073/r2-industrial-l3-a6000d1/live/compact-industrial-l3-selected.png
```

Compilation passed with warnings treated as errors. Exactly one complete
replay was consumed. It cleared the seven-bin material-value gate and stopped
at:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level:
L3-to-L4 silhouette change target failed
```

The immutable silhouette gate requires both:

```text
silhouetteBoundaryChangeShare >= 0.20
silhouetteMaskIntersectionOverUnion < 0.80
```

No geometry, material, threshold, or validator adjustment followed, and no
second replay was consumed.

## Retained exact partial packet

- pre-pixel builder SHA-256:
  `cb53593023b5ab353600dd9bbfe4fa6a61c61cc02fcbb0cc845639aac92ec272`
- material library SHA-256:
  `329851c631d6b25e45c0a4a86b383bc23ae2591403ef259e13077cb57f34810e`
- North descriptor SHA-256:
  `f01cf99950485743b982aec8b9cc8bd79de276a277a25fbde8dddcf6c2625e74`
- East descriptor SHA-256:
  `4e74f8fefeb89178f6c9716db99a701dea0bec1480da383bcf8e38a346e10edb`
- South descriptor SHA-256:
  `8c5125fe839b21b0c210a1c87a52aca0559a886eeef6b51e21f3c386e3a92329`
- West descriptor SHA-256:
  `779666bad50562e9c59a54a0b1edc8da35a683908bf934f905af5fcf86b716c3`
- retained partial panel count: `22`
- deterministic sorted panel-hash-list SHA-256:
  `ac015692dff85194417f29611b562a437d1583080c6daad02524120b6ef769b2`
- retained panel root:
  `docs/production/evidence/PLAY-027/industrial-l04/l04/hero-redesign-v02-prepixel/material-value-replay-05-failure/review/`

The panels are retained as failed-attempt evidence only. Because the technical
gate failed, they were not promoted to candidate review panels or treated as
visual acceptance evidence.

Passing pre-pixel validation, source-authority raw rendering, normalization,
source authority, and production selection remain unrun or false.

No additional repair or replay is authorized in this checkpoint.
