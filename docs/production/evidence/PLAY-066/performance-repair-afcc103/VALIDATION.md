# PLAY-066 cold renderer repair validation

## Exact identity

- Repaired product commit:
  `afcc103aac006d6fe5330f89ea5039d19cc3c7fe`.
- Preserved visible product ancestor:
  `481a6fbf09b8a31dff85941b3b9ebce0ca11715d`.
- Preserved returned evidence ancestor:
  `bdcc7210d44c06e152c478185dd35f69e57b53a3`.
- Candidate ID: `world-rendering-w5f893ad1da1b`.
- Staged executable SHA-256:
  `924603016cf66bb45d691112ade8acf36dfb140f392f92c3df340451ed262299`.
- Staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.
- Staged atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`.

## Repair boundary

`LotContextRenderer` now caches at most 100 immutable templates keyed by
family, deterministic variant, authoritative frontage, and physical tile
geometry. Each scene receives a deep copy of the exact cached children. The
repair avoids rebuilding identical paths, palette blends, and SpriteKit
subtrees during cold world construction.

The focused regression proves that an identical context grows the cache by at
most one entry, reuses that entry, produces identical child-name inventories,
returns distinct node objects, and does not leak later node mutation. No
camera, LOD, activity-selection, simulation, UI, asset, package, or gameplay
surface changed.

## Five fresh-process reliability runs

Each retained sample used the same command and cache policy:

```text
swift test --filter WorldRenderingTests
```

Each command launched a fresh XCTest process against exact product
`afcc103aac006d6fe5330f89ea5039d19cc3c7fe`. No sample was replaced.

| Ordered run | Tests | Governed cold update | Profile cross-check | Unchanged-pulse average | Result |
|---|---:|---:|---:|---:|---|
| 1 | 60/60 | 4.755 ms | 4.668 ms | 0.0006 ms | pass |
| 2 | 60/60 | 4.537 ms | 4.740 ms | 0.0007 ms | pass |
| 3 | 60/60 | 4.459 ms | 4.298 ms | 0.0007 ms | pass |
| 4 | 60/60 | 4.534 ms | 4.744 ms | 0.0007 ms | pass |
| 5 | 60/60 | 4.576 ms | 5.284 ms | 0.0006 ms | pass |

- Governed cold-update series: `4.755, 4.537, 4.459, 4.534, 4.576 ms`.
- Median: `4.576 ms`.
- Maximum: `4.755 ms`.
- Ceiling result: `5/5 <= 6.03 ms`; no sample exceeded the ceiling.
- Unchanged-pulse result: maximum `0.0007 ms`, below the `2.1 ms` ceiling.
- Each soak held 4,286 pulses at 1,474 nodes, 648 drawables, and two bounded
  actions.
- Each run reported 41,943,040 high-water decoded bytes and zero fallback.

The complete ordered outputs are retained under `diagnostics/` as
`focused-fresh-process-01.log` through
`focused-fresh-process-05.log`.

## Broader validation

- Full native suite: 233/233 passed in 113.285 seconds.
- Full-suite renderer cold update: 4.921 ms.
- Full-suite profile cross-check: 4.788 ms.
- Full-suite unchanged-pulse average: 0.0007 ms.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed and identified exact commit
  `afcc103aac006d6fe5330f89ea5039d19cc3c7fe`.
- Generated-v4 source/staged validation: passed; staged bytes matched source,
  192 payload digest checks passed, 5,033 overlap checks passed, and failures
  were empty.
- Production geometry: `result: pass`; 8,100 reciprocal ground-collision
  checks, 180 road-setback checks, and 692 entrance/prop neighbor-exclusion
  checks produced zero collisions and zero failures.
- The exact staged PID `50135` was terminated after verification; no exact
  candidate process survived.

## Pixel and interaction equivalence

The repair changes only how immutable renderer-local lot-context nodes are
constructed. It does not alter any path, color, position, scale, alpha,
z-order, node name, texture, camera rule, LOD threshold, activity signature,
selection, frontage, or hit geometry. The focused tests prove equal child
inventories with isolated deep copies, while all five runs preserve the exact
914-node/434-drawable golden scene and 1,474-node/648-drawable/two-action soak.

Accordingly, under the integration return's explicit allowance, the six
candidate-bound Day-53 frames retained at
`docs/production/evidence/PLAY-066/candidate-481a6fb/live/` were not
recaptured. They remain the visible composition reference; this packet binds
the pixel-equivalent construction repair and new staged executable identity.

## Historical failure disclosure

The unchanged returned candidate remains recorded at `bdcc721`: its two final
focused rechecks measured 6.912 ms and 7.288 ms against the 6.03 ms ceiling.
Those samples were not replaced or reclassified. This packet is a new product
candidate and a new five-process reliability series.
