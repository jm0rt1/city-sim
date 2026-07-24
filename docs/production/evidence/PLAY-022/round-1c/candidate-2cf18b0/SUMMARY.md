# PLAY-022 Round 1C engineering candidate

## Disposition

Product commit 2cf18b0f0d9a0aee9f3708e72593eb6e7cd99ae0 passes the
Round 1C renderer engineering gate. It is not a visual self-score and PLAY-022
remains subject to independent integration/playtest disposition. Round 2,
PLAY-023, and CONTRACT-008 remain unauthorized.

The rejected predecessor product fc8b838d6d33ee8091ce6c54c125ea0cee279f5b
and evidence commit 701bb0aa7de3ee2f80932065bf7167aada7fbe3f remain
unchanged in history and were not sampled again.

## Product outcome

The renderer now:

- counts nodes, drawables, and actions in one scene-tree traversal;
- avoids sorting authoritative row-major tile storage and avoids first-render
  removal-set work;
- keeps stable logical records for empty interior parcels without attaching
  structurally blank SpriteKit nodes;
- resolves nearby developed frontage by direct cardinal set lookup;
- computes generated residency needs in one state pass; and
- combines identical road socket material paths into one drawable per material
  pass without changing road geometry or pixels.

Shipping-start diagnostics changed from 1,932 nodes / 758 drawables at fc8b838
to 1,370 nodes / 648 drawables. The retained three-LOD road seam mosaic is
byte-identical to the predecessor:
8931b8a7d02cecddc3cc60f03bc0100352f754bc1a9671f65e289a5f77f87af4.
No asset, construction-stage, snapshot, store, input, Package.swift, build
script, save, gameplay, or shared-contract surface changed.

## Governed cold series

Exactly five fresh XCTest processes used the preregistered whole-renderer-class
command and one built scratch root. Every process passed 35/35 renderer tests.

| Sample | World update | Decode | Total |
|---|---:|---:|---:|
| 1 | 3.917 ms | 0 loads / 0.000 ms | 4.431 ms |
| 2 | 3.707 ms | 0 loads / 0.000 ms | 4.196 ms |
| 3 | 3.963 ms | 0 loads / 0.000 ms | 4.476 ms |
| 4 | 4.012 ms | 0 loads / 0.000 ms | 4.527 ms |
| 5 | 3.836 ms | 0 loads / 0.000 ms | 4.341 ms |

Median total is 4.431 ms and maximum total is 4.527 ms. The result is 5/5 at
or below 4.8 ms and 5/5 at or below 6.03 ms. Compared with the rejected
predecessor window's 5.943 ms median, this is 1.512 ms / 25.4% lower. Every
environment and process prerecord and every unabridged sample log is retained.

## Validation

- Focused renderer plus invalidation: 71/71 passed before the product commit.
- Full isolated native suite: 135/135 passed.
- Focused resolver and command/input suites: 21/21 passed.
- Production geometry: 616 checks, zero reciprocal ground collisions, zero
  building/road collisions, zero entrance/prop collisions, zero failures.
- Repeated LOD residency: 28 textures, 13,521,048 decoded bytes, zero fallback.
- Changed-pulse diagnostics: 5,759 reuses, one update, 0.770 ms average.
- Unchanged soak: 1,370 nodes, 648 drawables, one bounded action, 0.0025 ms
  average; Reduce Motion remains zero-action.
- Staged build and resource probe: passed at exact commit 2cf18b0.
- Candidate isolation: passed in two disposable shared clones; their task
  processes were terminated after verification.
- Regular staged memory after three LOD cycles and settle: 198 MB physical
  footprint, 162,240 KiB RSS, 298 MB lifetime peak.
- Exact 900 x 600 staged memory after three LOD cycles and uncontaminated
  settle: 148 MB physical footprint, 117,392 KiB RSS, 290 MB lifetime peak.
- Regular and compact are both below the 333.8 MiB ceiling.

The exact staged app retained keyboard map focus, Arrow-key selection, Return
inspection, a truthful selected Power Plant AX description, regular developed
composition, and exact 900 x 600 compact controls/map legibility. The
renderer harness independently retains default/compact composition and
occupancy: default 0.624132 x 0.850377 and compact 0.540000 x 1.220904.

## Exact staged identity

- Candidate ID: world-rendering-w5f893ad1da1b
- Product tree: 171f03c1945d42b07f042246a504f689d1e7d351
- Executable SHA-256:
  af7808aab403b04ffb219842da81f7b9eb1fb69796809b174e35702402e949a7
- Candidate manifest SHA-256:
  87cb7839f1ab6e6def47b37fa55b87a73c1f588980e40161001bd705014a3cd1
- Packaged/source generated-v4 manifest SHA-256:
  900287027256d7f5ea960b7b17c9208f3ff990de532feb87448eb01328076e78
- Geometry report SHA-256:
  29621f9f053000a12d11f4131aeea09a3a04ecd142f14d2de9b8d3764a5bca12

No CitySim, XCTest, Swift build, or isolation process created for this packet
is intended to remain alive after handoff.
