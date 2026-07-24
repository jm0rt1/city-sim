# PLAY-022 Round 1B exact-candidate geometry evidence

This renderer-harness packet was generated from the exact product candidate
`fc8b838d6d33ee8091ce6c54c125ea0cee279f5b` on
`codex/citysim-world-rendering` (Git tree
`1277422dabd28c67469b11516ba06692f978bc1a`). It supports only the
production collision and deterministic road-seam gates. It is not staged-app
proof and does not self-accept the visual candidate.

## Production geometry and collision report

Command, run from the repository root:

```sh
mkdir -p docs/production/evidence/PLAY-022/round-1b/geometry-fc8b838
set -o pipefail
python3 Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_production_geometry.py \
  --report docs/production/evidence/PLAY-022/round-1b/geometry-fc8b838/production-geometry-report.json \
  2>&1 | tee docs/production/evidence/PLAY-022/round-1b/geometry-fc8b838/production-geometry-validator.log
```

Result: **pass** (exit 0). The exact structured report records:

- schema 2, 12 semantic assets, and 84 inventory entries;
- 324 reciprocal-ground checks, with 0 collisions;
- 36 building/road-setback checks, with 0 collisions;
- 256 entrance/prop-exclusion neighbor checks, with 0 collisions;
- 0 orphan inventory entries and 0 missing inventory references;
- 0 failures;
- repeated-LOD decoded-byte high water of 13,521,048 bytes; and
- generated-v4 manifest SHA-256
  `900287027256d7f5ea960b7b17c9208f3ff990de532feb87448eb01328076e78`.

Artifact identity:

| Artifact | MIME / dimensions | Bytes | SHA-256 |
|---|---|---:|---|
| `production-geometry-report.json` | `application/json` | 20,213 | `29621f9f053000a12d11f4131aeea09a3a04ecd142f14d2de9b8d3764a5bca12` |
| `production-geometry-validator.log` | JSON validator stdout; `application/json` | 20,213 | `29621f9f053000a12d11f4131aeea09a3a04ecd142f14d2de9b8d3764a5bca12` |

## Deterministic road topology seam mosaic

The focused export used task-local caches and a task-local scratch build:

```sh
set -o pipefail
env \
  CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-geometry-fc8b838-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/private/tmp/citysim-play022-geometry-fc8b838-cache/clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-geometry-fc8b838-cache/swiftpm \
  CITYSIM_PLAY022_ROAD_SEAM_MOSAIC=/Users/James/.codex/worktrees/cac1/city-sim/docs/production/evidence/PLAY-022/round-1b/geometry-fc8b838/road-topology-seam-mosaic.png \
  swift test --disable-sandbox \
    --package-path Native/CitySimNative \
    --scratch-path /private/tmp/citysim-play022-geometry-fc8b838-build \
    --filter WorldRenderingTests.testProductionCorridorExportsAllTopologySeamMosaicAcrossSemanticLODs \
  2>&1 | tee docs/production/evidence/PLAY-022/round-1b/geometry-fc8b838/road-seam-focused-test.log
```

The first restricted-host execution built the exact candidate but exited 1
after `xctest` received signal 11 while initializing SpriteKit's `SKView`,
before a mosaic was exported. Its exact output is retained as
`road-seam-focused-test.sandbox-attempt.log`. The identical command was then
rerun with WindowServer access.

Final result: **pass** (exit 0). One focused test executed with 0 failures in
0.289 seconds. It exported all 16 deterministic road connection masks at city,
neighborhood, and block semantic LODs: 48 rendered cells. The same test asserts
the production-corridor node source, no generated-v4 road fallback, and zero
active actions.

Artifact identity:

| Artifact | MIME / dimensions | Bytes | SHA-256 |
|---|---|---:|---|
| `road-topology-seam-mosaic.png` | `image/png`; 2,400 x 680; 8-bit RGBA; non-interlaced | 131,089 | `8931b8a7d02cecddc3cc60f03bc0100352f754bc1a9671f65e289a5f77f87af4` |
| `road-seam-focused-test.log` | `text/plain`; UTF-8 | 1,216 | `1bada2a344f2438cf6b098c9f794d7ca8aeb1f94be69f2dff6519bed2c5bfe55` |
| `road-seam-focused-test.sandbox-attempt.log` | `text/plain`; UTF-8 | 5,136 | `ed505b5168da96eefb5301d87c66f4e14f78642064239b5bd48aff6d666d8f49` |

## Boundary

No product, contract, claim, staged-app, canonical GUI, or other evidence
surface was changed or exercised to create this packet. The packet makes no
interaction, visual-acceptance, memory, or full-suite claim.
