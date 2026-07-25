# PLAY-068 Frozen `1b883ca` Baseline Ledger

## Authority and staged identity

- Published preregistration authority:
  `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`.
- Frozen accepted product:
  `1b883ca684b07ba38c5c755b616723bde0cd2230`.
- Product/build parity across `Native/CitySimNative` and
  `script/build_and_run.sh`: exit `0`.
- Candidate ID:
  `playtest-quality-wf967be0ab5b4`.
- Bundle ID/defaults:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`.
- Staged executable SHA-256:
  `3c4a58a444e481b10d2a64da0d36b9f53fa777522657069c4692abafabee7a5c`.
- Staging-manifest SHA-256:
  `351e847435c334f700712c7f1850a4a4f7da95757b2c19bda28b13c0c339f19e`.
- Info.plist SHA-256:
  `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`.
- Source/staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.
- Source/staged manifest byte comparison: exit `0`.

## Same-state player truth

The exact app loaded `story-industrial-complication-v1.json` paused at Day 33,
tick 128 and selected Industrial block 15,12. AX and HUD retained:

- treasury `$34,037`, net `+$93/cycle`, 332 residents, 231 jobs;
- Freight strategy, `DECISION · 16 DAYS`, `Prepare for the load surge`;
- twelve warning notices and paused state;
- completed, maintained Industrial L1;
- power and water strain 75%, pollution severe 100%, vitality stable 68%;
- road connected, 77 workers of 110, upkeep `$8/cycle`; and
- `Add power capacity` as a truthful response in Details.

All five overlays retained the selected coordinate and authoritative state.
Focus City retained identity, treasury, urgency, notices, speed, selected
target, and primary action.

## Baseline activity/public realm

`1b883ca` predates CONTRACT-016's two explicit transient activity indices. It
therefore provides no accepted coordinate-scoped activity field to justify new
density. Existing static pedestrians/vegetation/public-space details are
comparison pixels only, not activity truth. The candidate must materially
enrich the public realm while proving that every dynamic density change is
driven by the accepted snapshot; nil/zero must suppress.

The selected comparison scene contains the City Hall/plaza, park, road loop,
trees, Commercial, Industrial, Water Tower, and nearby Residential massing.
Those accepted buildings and roads may not move between A/B captures.

## Window, camera, and aperture baseline

The baseline uses the vertical unobscured-world-band measurement on the
original decorated screenshot. Pixel rows are inclusive and measured to
within two pixels. Percent uses the app-content area below the 52-pixel window
chrome.

| Width/mode | Original image | Unobscured world band | Content-area share |
|---|---:|---:|---:|
| Regular normal | 1278 x 768 | y 200-645, 446 px | 62.3% |
| Regular Details | 1278 x 768 | y 200-515, 316 px | 44.1% |
| Regular Focus City | 1278 x 768 | y 134-767, 634 px | 88.5% |
| Compact normal | 900 x 652 | y 177-535, 359 px | 59.8% |
| Compact Details | 900 x 652 | y 177-444, 268 px | 44.7% |
| Compact Focus City | 900 x 652 | y 158-651, 494 px | 82.3% |

Accepted proof-camera metrics remain:

- default scale `0.312796950340271`, priority width
  `0.7473417931726477`;
- compact scale `0.576345682144165`, priority width
  `0.5796985019395197`; and
- explicit comparison stops regular `0.85`, `0.65`, `0.50`, compact `0.45`.

The candidate must retain the same developed bounds, fixture, selection, and
camera stop for each A/B. It must improve normal and Details aperture by at
least five percentage points in both widths without hiding operating truth.

## Live process ledger and cleanup

| Route | PID | Environment | Point RSS |
|---|---:|---|---:|
| Staged verify | 34261 | generated staged root | 130,896 KiB |
| Regular block/Details/Focus/overlays | 36795 | regular; scale `0.50` | 119,312 KiB |
| Regular city | 40603 | regular; scale `0.85` | 237,456 KiB |
| Regular neighborhood | 42221 | regular; scale `0.65` | 262,240 KiB |
| Compact block/Details/Focus/overlays/FKA | 43245 | compact; scale `0.45` | 156,816 KiB |
| Compact Reduce Motion | 44868 | compact; scale `0.45`; Reduce Motion | 330,224 KiB |

These are point samples, not new settled baselines or ceilings. Every PID
resolved to the exact quality executable and injected root/environment. Every
listed PID was terminated with SIGTERM. No other owner's process was
terminated.

## Accepted resource, geometry, and performance comparison

The accepted independent PLAY-063 evidence for the byte-identical product
records:

- four atlas pages; three resident textures;
- active-plus-adjacent decoded high-water `41,943,040` bytes;
- zero fallbacks;
- zero building/road, reciprocal-ground, and entrance/prop-exclusion
  collisions;
- cold full-suite profile: 5.702 ms total / 3.854 ms world update;
- cold focused profile: 5.907 ms total / 4.233 ms world update;
- unchanged-pulse soak: 4,286 pulses / 0.0006 ms average;
- highest accepted live quality RSS sample: 230,208 KiB, with lower settled
  samples and no continuing growth;
- focused WorldRenderingTests: 55/55; and
- full native suite: 226/226.

These values are baseline comparisons, not replacements for CONTRACT-006.
The governing hard limits remain those frozen in `RUBRIC.md`.
