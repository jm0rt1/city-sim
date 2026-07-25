# PLAY-061 Frozen Baseline Ledger

## Authority and product parity

- Published preregistration authority:
  `91f885925fd601786fa95dbb969b71fefef5ddcd`.
- Frozen accepted product:
  `64dd47500fe5e2d4a32a64f6298ded5789d3b773`.
- Accepted Commercial source candidate:
  `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`.
- `git diff 64dd475..91f8859 -- Native/CitySimNative/Sources
  Native/CitySimNative/Resources Native/CitySimNative/Package.swift
  script/build_and_run.sh`: empty.

The current published authority adds source-art and governance history but does
not change the accepted shipping product or staged baseline bundle.

## Shipping Commercial identity

The frozen generated-v4 manifest has exactly one Commercial asset:

| Surface | Frozen value |
|---|---|
| Logical ID | `commercial_l01` |
| Family / level / variant | `commercial` / `1` / `0` |
| Frontage / supported orientation | `south` / `south-facing-fixed` |
| Source SHA-256 | `90207ec4ed651810df863e0ff21591c85eea444f8606c41c83e85060e4c1de89` |
| Block normalized / payload | `5f8f75a9363d891510d4839976ee71ee72a41b61cce6fd6a088d574713118d40` / `31b82d2d0ed8601c89cb441221aea34b50bc71c6f7922d7e9490cdfdfb250e75` |
| Neighborhood normalized / payload | `255188495f6c77b92b0c630ebb47ed469a561698b158d77916424411efa92daf` / `ea76796ede777b74fd4fa57c51ed940a1d04f8e00747989c54f2616e3b2e5c35` |
| City normalized / payload | `9d992505eccf438fabc39b814cfeb1b001d99ba35065f5ceec42a602fed69f9e` / `ca0c7a629114d950042d66165444eb4428d1bb3eae42769b68f3628d67be476c` |
| Pages | `block-00`, `neighborhood-00`, `city-00` |
| Pivot / entrance socket | source `[768,896]`; world `[0,-14]` |
| Footprint | `1 x 1`; 56 x 28 world ground-contact diamond |

`CityScene.generatedLogicalID(for:)` and
`LotRenderer.generatedLogicalID(for:)` both map every Commercial kind to
`commercial_l01`. The baseline therefore fails the future sixteen-row identity
matrix by design: every level and road direction aliases a south-facing L1.
This is the frozen improvement target, not a score assigned to a future
candidate.

## Same-state real-app route

Fixture:
`story-commercial-complication-v1.json`,
SHA-256
`fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a`,
digest
`2a1b046eb21665206709415e3a1363aeaa0a9a4a60e83e1e1b52ae3c53b50ad4`.

The real staged app loaded the fixture paused at Day 33/tick 128 and selected
Commercial block 14,12 by keyboard. AX reported maintained condition, strained
power at 83%, strained water at 67%, severe pollution at 100%, and 74%
vitality. Details reported Commercial L1, road connected, 77 workers of 80.

The regular and compact routes retained truthful treasury `$30,848`, net
`+$46`, population `332`, jobs `231`, utilities `P 22 / W 21`, twelve notices,
paused state, and Main Street strategy urgency. Focus City preserved the same
Commercial target and action. Pollution overlay, Details, FKA focus, and
Reduce Motion remained readable without transient toasts.

## Live identity, windows, and cleanup

| Route | PID | Data root | Window/camera | Settled RSS |
|---|---:|---|---|---:|
| Regular presentation | 74387 | `/private/tmp/citysim-play061-64dd475-regular.OTV8mV` | regular; 1278 x 768 decorated | 128,016 KiB |
| Compact presentation | 77001 | `/private/tmp/citysim-play061-64dd475-compact.7pkJYc` | exact 900 x 600 content | 153,616 KiB |
| Compact Reduce Motion | 78748 | `/private/tmp/citysim-play061-64dd475-reduce.uWln4q` | exact compact; Reduce Motion proof | 197,824 KiB |
| Compact city proof | 85416 | compact root above | scale `0.576345682144165` | not sampled |
| Compact neighborhood proof | 86532 | compact root above | scale `0.52` | not sampled |
| Compact block proof | 88764 | compact root above | scale `0.45` | not sampled |

Every PID resolved to the exact lane executable. Each was terminated with
SIGTERM after capture. The final exact-executable process search returned no
live match. No other owner's process was terminated.

## Binding visual matrix

Regular city/neighborhood/block selected hashes:

- city:
  `145b3fb0006a96a2ab1e3965983dfa07a6956777049d1e7e9ba19b8576b237f6`;
- neighborhood:
  `37a04ec3d743c2104cfbbb17b038e9469cd54ba9a853ca6cc284064ef704b48b`;
- block:
  `c2525458e806d94455b9c78b9e884d46044a90ae1c822e85d7f7bc1020dd2991`;
- block grayscale:
  `6aac11b684545113018577c798f6dd5105f1a77be797bd0de98c422113fe676b`.

Compact city/neighborhood/block selected hashes:

- city:
  `fdf63b4a281625edae87c3ef7a6f0571ce5da0bdd494bb38261489dfd2d148ed`;
- neighborhood:
  `1cdd869a77a87c55e0aa69cbc643d321ecba578d151b471eb7f345e6e0ac783f`;
- block:
  `91553fcaafdc7cc0d82c8d7cb2b418712c349fed88303fc6ed74e68c603affbb`;
- block grayscale:
  `c0897f871c487a57f82fe8bba496beb86ad461e5f85e72ff2602a82f5d317fcb`.

The three hashes differ at each viewport. Additional binding captures cover
settled city framing, Details, Pollution, Focus City, FKA focus, and Reduce
Motion; each has a paired AX tree except the derived grayscale panels.

## Accepted performance and validation comparison

The exact frozen product's retained independent PLAY-058 result is:

- full native suite: `219/219`, zero failures, 104.836 seconds;
- renderer group: `48/48`, zero failures, 22.172 seconds;
- asset pack: four pages, 132 payload/extrusion checks, 2,403 packed-overlap
  checks, zero failures;
- active-plus-next decoded bytes: 12,582,912 City and 41,943,040
  Neighborhood/Block;
- repeated LOD residency: three textures, 41,943,040-byte high-water, zero
  fallbacks;
- production geometry: 2,500 reciprocal-ground, 100 building/road, and 372
  entrance/prop checks, zero failures;
- cold renderer: 3.806 ms world update, 5.643 ms total, zero decode loads; and
- 30-minute-equivalent soak: 4,286 pulses, 0.0007 ms average diagnostic pulse.

The future candidate must report deltas from these values and satisfy the
frozen CONTRACT-006 ceilings in `RUBRIC.md`; author results do not replace
independent quality execution.
