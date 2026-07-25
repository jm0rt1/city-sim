# PLAY-063 Frozen Baseline Ledger

## Authority and accepted source

- Published/shipping baseline:
  `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`.
- Accepted non-shipping Industrial L1 source authority:
  `79668c347e58d602f9627c73cb09e3272a83ef57`.
- Accepted source calibration:
  `industrial-l01-variant-0-directional-v05`.
- Product parity:
  `git diff --quiet 1799fbc..8f85a0c` across active sources, resources,
  `Package.swift`, and staging script passed.

Accepted raw source SHA-256:

| Direction | Accepted source-v05 SHA-256 |
|---|---|
| North | `5ca93afa57157ddf686ef5740f1907da03f513906b9c703bc556ed75e2516728` |
| East | `f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f` |
| South | `f3588cf71e689055a2bd0a184262b24df0af8c4e41be1665af5c8eb6f8edca2e` |
| West | `9fa5759f88e2efd2f3eef36f66089f0e8e978dc4e052d08d919b9f1a40aa331a` |

The accepted source review provides twelve unique normalized files, four
directions by three LODs. `ledgers/industrial-direction-lod-matrix.csv`
freezes every accepted file/pixel hash.

## Shipping Industrial identity

The baseline generated-v4 manifest has exactly one Industrial asset:

| Surface | Frozen value |
|---|---|
| Logical ID | `industrial_l01` |
| Family / level / variant | `industrial` / `1` / `0` |
| Frontage / supported orientation | `south` / `south-facing-fixed` |
| Source SHA-256 | `22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515` |
| Block normalized / payload | `31773d3b78ff36a8da6e8bfed16548b995c1cc6213b8dfd9e28b3a074c73c71e` / `0584842114b49dac3b5c6a8e015770900955be0899c8d6786fad9d69fa6f2446` |
| Neighborhood normalized / payload | `c59758b4ba7c039eba6577c6bc688ae8a781d49af0e76ec2e1c6bab57da8c344` / `845773328775a9d62ac17c1dda85a8695cee8c7383934ef6e49b9b80c2daadc9` |
| City normalized / payload | `9810dec8b5d8c1875ff0a253e0182d8a37fbef181e0bfc020657630d7844122a` / `a0a2c782a6c42f85a7d2999f6c6ae9d22e1f7041084429bd0af782c68725e510` |
| Pages | `block-00`, `neighborhood-00`, `city-00` |
| Pivot / entrance socket | source `[768,896]`; world `[0,-14]` |
| Footprint | `1 x 1`; 60 x 30 world ground-contact diamond |

Both `CityScene.generatedLogicalID(for:)` and
`LotRenderer.generatedLogicalID(for:)` map Industrial and Power Plant to
`industrial_l01`. The baseline therefore fails the future N/E/S/W matrix by
design: every authoritative direction resolves one south-facing identity.
This is the frozen improvement target, not a score assigned to a future
candidate.

## Same-state real-app route

Fixture:
`story-industrial-complication-v1.json`,
SHA-256
`7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`,
digest
`a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`.

The exact staged app loaded paused at Day 33/tick 128 and selected Industrial
block 15,12 through keyboard navigation. AX reported completed, maintained,
power strained 75%, water strained 75%, pollution severe 100%, and stable 68%
vitality. Details reported Industrial L1, 77 workers of 110, connected road,
and `$8 / cycle` upkeep. The HUD retained treasury `$34,037`, net `+$93`,
population `332`, jobs `231`, utilities `P 9 / W 14`, twelve notices, paused
state, and the Freight strategy priority.

Pollution layer AX added `Pollution overlay active` without hiding target
condition. Focus City preserved the exact target, treasury, urgency, notices,
pause state, and primary action. Compact Details exposed the same coordinate,
cause, consequence, response, and `Add power capacity` action. Tab traversal
entered the HUD metrics and provided a visible focus ring; candidate execution
must complete the full FKA and AX action matrix.

## Live identity, windows, and cleanup

| Route | PID | Data root | Window/camera | Point RSS |
|---|---:|---|---|---:|
| Staged verify launch | 58963 | staged manifest root | default | not sampled |
| Regular default | 60115 | `/private/tmp/citysim-play063-8f85a0c-regular.g8LCsF` | regular/default | 230,400 KiB |
| Regular city | 60940 | same | scale `0.85` | 182,752 KiB |
| Regular neighborhood | 61528 | same | scale `0.65` | 204,608 KiB |
| Regular block/overlay/Focus | 62259 | same | scale `0.50` | 274,560 KiB |
| Compact default/Details/FKA | 63871 | `/private/tmp/citysim-play063-8f85a0c-compact.SJw2eo` | exact compact/default | 210,528 KiB |
| Compact block/overlay | 65954 | same | exact compact; scale `0.45` | 286,096 KiB |
| Compact Reduce Motion | 67513 | `/private/tmp/citysim-play063-8f85a0c-reduce.eEsUrU` | exact compact; scale `0.45` | 248,752 KiB |

The RSS values are disclosed point samples, not a replacement performance
budget or settled baseline. Every PID resolved to the exact quality
executable and matching environment. Every PID was terminated with SIGTERM.
The final exact-executable process search returned no live process. No other
owner's process was terminated.

## Binding visual evidence

Regular:

- `live/regular/industrial-selected-city.jpg`;
- `live/regular/industrial-city-scale-0.85.jpg`;
- `live/regular/industrial-neighborhood-scale-0.65.jpg`;
- `live/regular/industrial-block-scale-0.50.jpg`;
- `live/regular/industrial-block-scale-0.50-grayscale.jpg`;
- `live/regular/industrial-pollution-block-scale-0.50.jpg`; and
- `live/regular/industrial-focus-pollution-block-scale-0.50.jpg`.

Exact compact:

- `live/compact/industrial-selected-city-900x600.jpg`;
- `live/compact/industrial-details-city-900x600.jpg`;
- `live/compact/industrial-details-fka-900x600.jpg`;
- `live/compact/industrial-block-scale-0.45-900x600.jpg`;
- `live/compact/industrial-block-scale-0.45-grayscale-900x600.jpg`;
- `live/compact/industrial-pollution-block-scale-0.45-900x600.jpg`; and
- `live/reduce-motion/industrial-block-900x600.jpg`.

All binding frames are transient-free. Derived grayscale images retain the
same uncropped dimensions and are identified separately in `SHA256SUMS`.

## Accepted validation/performance comparison

Exact `8f85a0c` baseline execution:

- `./script/build_and_run.sh --verify`: passed;
- focused `WorldRenderingTests`: **52/52**, zero failures, 28.352 seconds;
- repeated LOD diagnostics: three resident textures, 41,943,040-byte
  high-water, zero fallbacks;
- cold renderer diagnostic: 4.039 ms world update, 5.632 ms total, zero decode
  loads;
- 30-minute-equivalent unchanged-pulse soak: 4,286 pulses, 0.0006 ms average;
- default proof camera: scale `0.312796950340271`, priority width
  `0.7473417931726477`;
- exact compact proof camera: scale `0.576345682144165`, priority width
  `0.5796985019395197`; and
- full native suite: **223/223**, zero failures, 110.348 seconds.

The complete suite result is retained in
`validation/full-native-suite.log`.
Future candidate results must report deltas from the accepted resource values
and satisfy CONTRACT-006. Author results never replace independent quality
execution.
