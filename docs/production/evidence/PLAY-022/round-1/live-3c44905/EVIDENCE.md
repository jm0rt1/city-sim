# PLAY-022 Round 1 live evidence index

**Product candidate:** `3c44905467de4a6629098f6be51d0ac90f56f5f0`

**Disposition:** retained visual checkpoint. Independent scoring is deferred
pending integration resolution of the PLAY-051 shared active-placement-target
contract. This index does not self-accept Round 1 or authorize Round 2,
PLAY-023, merge, or push.

## Exact staged identity

The retained frames came from the isolated staged app at
`dist/CitySim-world-rendering-w5f893ad1da1b.app`:

- branch `codex/citysim-world-rendering`;
- worktree token `w5f893ad1da1b`;
- candidate `world-rendering-w5f893ad1da1b`;
- bundle and preference domain
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`;
- executable `CitySimNative-w5f893ad1da1b`, SHA-256
  `3a834dee98eddbf7d03536611a9918474372fa19212b4815f1df9d39075b1b02`;
- packaged resource bundle `CitySimNative_CitySimNative.bundle`;
- source and packaged generated-v4 manifest SHA-256
  `afedf49fc0df87fa67733dd1b6a990aabcf22e77051425c78da222153353c93a`;
- isolated data root
  `dist/test-data/world-rendering-w5f893ad1da1b`.

`live-results.json` records exact paths, PIDs, window/camera identities, save
identity, accessibility observations, journeys, and validation. `performance.json`
records fresh-process timing, nodes, actions, texture residency, RSS, and the
separately disclosed allocator footprint. `motion-trace.json` records every
input represented in the retained pan/zoom movie.

## Live color proof

All JPEGs below are uncropped whole-window captures from the staged app. The
regular captures are 1277 or 1278 by 768 pixels because the native window edge
varied by one pixel. The compact captures are 900 by 652 pixels: exactly 900 by
600 points of app content plus 52 pixels of native title-bar chrome.

### Camera and composition

- `regular-block-normal.jpeg`, `regular-neighborhood-same-state.jpeg`, and
  `regular-city-same-state.jpeg` are a same-state Day 10 block/neighborhood/city
  sequence at proof scales 0.50, 0.66, and 0.74.
- `compact-900x600-block.jpeg`, `compact-900x600-neighborhood.jpeg`, and
  `compact-900x600-city.jpeg` prove the three distinct stops in exact compact
  content. They preserve the same seed but span Days 20-21, so they are not
  asserted as a frozen-state pixel comparison.
- `compact-900x600-after-three-lod-cycles.jpeg` and
  `regular-after-three-lod-cycles.jpeg` retain the post-cycle compositions used
  for the memory samples.
- `comparison-source-95c801b-block.jpeg` and
  `comparison-source-95c801b-city.jpeg` are historical camera-composition
  frames captured from product commit `95c801b`. They are not the rejected
  `8cb45b5` baseline and are not claimed as same-state comparisons to the final
  Day 10 sequence.

### Interaction and construction

- `regular-pointer-hit.jpeg` and `regular-keyboard-selection.jpeg` retain the
  pointer and keyboard hit-testing outcomes.
- `compact-900x600-selection.jpeg` retains exact-compact selection.
- `regular-build-valid.jpeg` shows open parcel 16,14 with one grounded boundary
  and frontage anchor; `regular-build-invalid.jpeg` shows occupied Industrial
  parcel 15,12 with the non-color invalid hatch.
- `regular-construction-committed.jpeg`,
  `regular-construction-progressed.jpeg`, and
  `regular-construction-finishing.jpeg` show prepared foundation, 50-percent
  frame, and 75-percent finishing states at Residential parcel 16,14.
- `regular-after-undo.jpeg` shows the same journey after undo.
- `regular-after-save-load.jpeg` shows the paused city restored through the
  staged File > Load City route.
- `regular-utility-overlay.jpeg` and `regular-pollution-overlay.jpeg` show the
  sparse approved diagnostic marks without a full-tile wash.

### Reduce Motion and motion

- `compact-900x600-reduce-motion-a.jpeg` and
  `compact-900x600-reduce-motion-b.jpeg` are paused exact-compact frames three
  seconds apart under `CITYSIM_REDUCE_MOTION_PROOF=1`. Their SSIM is 0.999762
  and average PSNR is 50.819494 dB.
- `regular-pan-zoom-app-only.mp4` is 41 seconds, 1278 by 768, H.264, 41 frames
  at 1 fps. It represents an uninterrupted 44.183-second staged-app input
  sequence and is intentionally app-window-only. Its low capture cadence is a
  disclosed proof limitation; it is not described as a fluid 30/60-fps movie.
- `regular-pan-zoom-start.jpeg` and `regular-pan-zoom-end.jpeg` retain the
  endpoints.

## Derived grayscale and mosaics

The grayscale JPEGs are derived proof, not additional live captures. Each was
created with `ffmpeg -vf format=gray`, retaining the source frame dimensions:

| Derived artifact | Color source |
|---|---|
| `grayscale-regular-normal.jpeg` | `regular-block-normal.jpeg` |
| `grayscale-selection.jpeg` | `regular-keyboard-selection.jpeg` |
| `grayscale-valid.jpeg` | `regular-build-valid.jpeg` |
| `grayscale-invalid.jpeg` | `regular-build-invalid.jpeg` |
| `grayscale-construction-0.jpeg` | `regular-construction-committed.jpeg` |
| `grayscale-construction-50.jpeg` | `regular-construction-progressed.jpeg` |
| `grayscale-construction-75.jpeg` | `regular-construction-finishing.jpeg` |
| `grayscale-utility-overlay.jpeg` | `regular-utility-overlay.jpeg` |
| `grayscale-reduce-motion.jpeg` | `compact-900x600-reduce-motion-a.jpeg` |

`round-1-live-lod-mosaic.png` is an unlabeled 1917 by 384 contact sheet derived
from the final regular block, neighborhood, and city frames. It supports review
of macro terrain boundaries and useful LOD differences. The deterministic road
socket/seam mosaic remains at
`../milestone-2-road-topology-seam-mosaic.png`; collision and registration
reports remain at `../milestone-1-physical-geometry.json` and
`../milestone-3-geometry.json`.

## Known evidence limitations

- The retained exact-coordinate construction sequence contains 0, 50, and 75
  percent states. It does not contain a separate 25-percent frame or an exact
  same-coordinate 100-percent completion frame.
- The save/load screenshot and retained save hash prove the restored saved
  outcome, but no second pre-load state digest was retained for bytewise
  before/after equality. Native persistence tests cover exact round-trip and
  undo equality.
- The pointer and keyboard journeys are represented by sequential whole-window
  stills and the structured result record, not separate continuous journey
  videos.
- The compact three-LOD frames are same-seed but not same-state, as disclosed
  above. The regular three-LOD frames are same-state.
- The historical `CITYSIM_PLAY021_GOLDEN_DIAGNOSTICS` cold block-detail marker
  is materially slower with the generated-v4 visible set. It is disclosed in
  `performance.json`; the changed and unchanged pulse gates remain within their
  accepted limits.

Every retained artifact has an exact digest in `SHA256SUMS`.
