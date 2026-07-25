# PLAY-024 Returned World-Excellence Evidence

- **Date:** July 24, 2026
- **Exact visual product:** `08a53be3fe4843eeb701bf70ff2f5f2b80036aae`
- **Camera-metric test checkpoint:** `d2c732284bc3839d2b52890feba600088effcafb`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Staged manifest commit:** `d2c732284bc3839d2b52890feba600088effcafb`
- **Independent disposition:** pending PLAY-053; this packet does not self-score

`d2c7322` changes only `WorldRenderingTests.swift`. The staged application
sources and resources are byte-equivalent to exact visual product `08a53be`.
The retained live frames therefore bind the returned visual product, while the
restaged candidate manifest binds the added exact camera assertions.

## Exact player state and capture

All current live frames use the frozen
`story-industrial-complication-v1.json` state in an isolated data root. The app
was loaded with Command-O, paused at Day 33, and left on the City layer with no
selection. The default frame was replaced after explicitly invoking
deterministic `0`; it is not a post-pan or post-LOD frame.

- `industrial-strain-default.jpeg`: regular decorated window immediately after
  exact deterministic `0`.
- `industrial-strain-compact-900x600.jpeg`: exact 900 x 600 content window
  (900 x 652 including title bar).
- `industrial-strain-block-lod.jpeg`: explicit zoom to the block stop.
- `industrial-strain-neighborhood-lod.jpeg`: explicit zoom through the
  neighborhood threshold.
- `industrial-strain-city-lod.jpeg`: explicit strategic city stop.
- `industrial-strain-pollution-overlay-compact.jpeg`: typed Pollution layer
  with sparse ground marks and the non-color AX legend.
- `industrial-strain-reduce-motion-default.jpeg`: proof-mode Reduce Motion
  with static meaning and no ambient actions.

The adjacent `.ax.txt` files retain the full accessibility tree for each
state. The two `before/` images are immutable PLAY-053 rejection frames from
integrated product `91438bf`.

## Camera and composition measurements

`testIndustrialStrainCameraPrioritizesTheDominantDistrictWithoutHidingRemoteTruth`
now freezes and prints these exact deterministic values:

| Window | Camera scale | Priority width occupancy | Priority height occupancy | Detail |
| --- | ---: | ---: | ---: | --- |
| 1280 x 800 | 0.312796950340271 | 0.7473417931726477 | 1.2329704703499522 | block |
| 900 x 600 | 0.576345682144165 | 0.5796985019395197 | 1.58704226315938 | neighborhood |

The camera-priority set contains eight authoritative occupied lots, excludes
the remote industrial lot from framing pressure, and leaves that lot rendered
and inverse-isometric-hittable. The repository has no approved executable
"featureless green" pixel-segmentation method; this packet does not invent one
or replace independent original-resolution visual review with an ad hoc
threshold.

## Automated validation

- `WorldRenderingTests`: 43/43 passed in 15.369 seconds at `d2c7322`.
- Full native suite: 201/201 passed in 86.942 seconds at `d2c7322`.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed; exact staged manifest reports
  `d2c732284bc3839d2b52890feba600088effcafb`.
- Bundled-Python world-pack validation: passed with zero failures, source/staged
  identity true, 84 payload checks, 84 extrusion checks, 974 packed-overlap
  checks, 133 inventory entries, four pages, and all LOD residency sets within
  budget.
- Bundled-Python production-geometry validation: passed with zero failures or
  collisions across 324 reciprocal ground contacts, 36 building/road
  setbacks, and 256 entrance/prop exclusion checks.
- Source and staged generated-v4 manifest SHA-256:
  `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72`.
- Staged candidate manifest SHA-256:
  `69f1893cb9b364cec67c57566108fee0d65c5c51a62962ce950ca5227998ce8e`.
- Staged executable SHA-256:
  `9a3ffacfa142f8c99d3caf54822ba818f0f5e5a1dc567d5f3e84503754c9e217`.

## Renderer budgets

- Default: 1,369 nodes / 553 drawables.
- Compact: 1,345 nodes / 529 drawables.
- Cold profile: 3.850 ms world update, 5.190 ms total render, zero asset
  decode loads.
- Active plus adjacent decoded residency: 10,485,760 bytes at city and
  33,554,432 bytes at neighborhood/block.
- Settled real-process RSS after three block-to-city LOD cycles and 55 seconds:
  117,712 KiB (114.95 MiB).
- Thirty-minute-equivalent unchanged-pulse soak: stable identity, 1,369 nodes,
  553 drawables, two bounded actions, and no accumulation.
- Reduce Motion: zero actions with equivalent static state meaning.
- Explicit generated-v4 fallback count: zero.

## Inspection result and limitations

The corrected default `0` frame restores the developed/pressured district as
the dominant mass. Compact retains its stronger occupancy. The ordinary City
layer contains no prior bright circular markers, thin poles, facade boxes, or
floating residential bar. Terrain furrows are short combined paths rather
than traceable aperture-spanning seams, preserving the 1,369-node default
budget.

Independent PLAY-053 must still judge composition, terrain continuity, LOD
meaning, and material preference at original resolution. Existing building
family breadth and four-direction authored views are intentionally not added
under PLAY-024; that request requires the next separately published
world-rendering claim.
