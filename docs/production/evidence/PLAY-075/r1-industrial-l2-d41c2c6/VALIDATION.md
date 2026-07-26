# PLAY-075 R1 focused validation

## Four directions x three LODs

Every listed normalized file was hashed independently from exact candidate
`d41c2c68`; every actual digest matched the candidate manifest.

| Direction | City SHA-256 | Neighborhood SHA-256 | Block SHA-256 |
|---|---|---|---|
| East | `861db1d52b55f82c70f51a31c606baa063092127384c66703b89d4cdfa79372c` | `c229dfa0759fa7232786eee92fcdd6786cd1d13728fb09b8aa9b39b30d49ed93` | `54e3e6c8f07f50af8bab56dd8d46923b8bdc70c6e7929ff45ee514d1fbea6086` |
| North | `60969ffb594fee16efa1114e75edf6dcb5e57c4041c1c8019c1796d7a7ff8b0a` | `76d1d302d8b1dfaa41ca799bbce5bf5ae4bee9754091e08a31eb1c0c0c6c7736` | `c539f4478296e929fb77250ad8476572e7b8155ad96abd2ebebe3170b052debc` |
| South | `b70085caaef5045df7289364d34f983054bc3b80d991ddb9507e9654ac1abbc3` | `976b998aa14adb1f040651616b31c5bc2e0ead77fb388054d7bf04b1d863dceb` | `c98e9b56a5705613a482b4ca249b4cb2b23a74fd6123638fc8282e7e8e5ba6f7` |
| West | `3853833738f2d2660ad9abe01cdee98f35ce6a80aa0a21f8afcd3f837fed9f8b` | `f0a3732a12672f91c023126bdc55b09c11acd2735930900b17c1106216858823` | `4c66e3d326606838bb484beef0a685cbf73d38d2e127572bd19be8e0c83077dd` |

- Four logical IDs, four source keys, four frontage edges, and four view
  directions are present.
- All twelve normalized hashes are unique.
- Visual inspection of each original, non-composited normalized image found a
  coherent gray/blue industrial family with direction-specific entrances and
  massing preserved from city through neighborhood to block LOD.
- No L2 manifest object contains a mirror, rotation, recolor, or fallback
  field.

## Pack/resource proof

The fresh independent focused command was:

```text
validate_world_asset_pack.py
  --atlas Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas
  --staged-atlas dist/CitySim-playtest-quality-w88bd7cb407a2.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas
```

Result:

- `passed: true`
- `staged_matches_source: true`
- failures: `[]`
- page count: `4`
- payload digest checks: `204`
- extrusion checks: `204`
- packed-overlap checks: `5727`
- Industrial directional identities: `8` across L1/L2
- Industrial normalized hashes: `24`
- maximum active-plus-next decoded bytes: `50,331,648`
- all L2 anchor drift: `0.0`

Page SHA-256 values:

| Page | SHA-256 |
|---|---|
| block/page-00.png | `efc1abd9f91a2821e2c013736781dc12561f972c56d0bd4b1f71c860da93fd5b` |
| block/page-01.png | `5191f34f50cddfa9e2a57b2d10089f1c4d7e4d563b36bbff28a2d495a8349566` |
| city/page-00.png | `29b84a3c928909bfb4511c7a821062b16e53d3ffbde4cd747510e4e03412bee9` |
| neighborhood/page-00.png | `c158f10745008365e8bab4397049e517e6e219cddaa9b67bccbdefc0ca5ccdb8` |

The first invocation with system Python stopped before validation because that
runtime lacked Pillow. The same command was rerun with the bundled workspace
Python and completed successfully. The retained machine-readable result is
`validation/world-asset-pack-report.json`.

## Fresh staged-app route

The route used only player-visible app controls after mechanically placing the
frozen fixture in the isolated candidate data root:

1. Load the Day 212 upgraded Industrial district, paused.
2. Press Right four times to select Industrial block 15,12.
3. Open Details with Shift-Return.
4. Close Details, then directly click the visible factory and confirm the same
   block and command-center identity.
5. Save, demolish through the visible action, invoke Command-Z, and save again.
6. Load the construction fixture and select Industrial block 6,9.
7. Load the pressured fixture and select Industrial L2 block 6,9.
8. Relaunch the exact candidate at 900 x 600 with Reduce Motion proof enabled,
   reload the Day 212 fixture, select the same block, and reopen Details.
9. Repeat the Day 212 selection in exact `10c2ed8` staged apps at regular and
   900 x 600 sizes.

The frozen upgraded fixture SHA-256 was
`d6e60c425fb240c196655516c236eda1ee5cf7d17ad19b11b2b1149492715826`.
The pressured fixture SHA-256 was
`92f0e3bf7cd190cf8b4bd6ec4e27494a9a2174e6da643ebbc9b434bb4b452448`.

## Same-state comparison

| Surface | Exact `10c2ed8` | Exact `d41c2c68` |
|---|---|---|
| Regular, 1278 x 768 decorated capture | Published pre-R1 brick Industrial factory | White/blue L2 factory, selected and road-aligned |
| Compact, 900 x 652 decorated capture / 900 x 600 content | Published pre-R1 brick Industrial factory | Same white/blue L2 identity, selected and legible under Reduce Motion |

The baseline packaged manifest has zero Industrial L2 identities. The
candidate has four. The live comparison therefore demonstrates a real packaged
runtime change rather than an evidence-only, fallback, recolor, or screenshot
substitution.

## Interaction and state ledger

| Check | Result |
|---|---|
| Keyboard selection | Industrial block 15,12 |
| Pointer selection | Same Industrial block 15,12 |
| AX identity | Industrial, Level 2, Operational |
| AX workers | 89 maintained / 94 pressured, capacity 220 |
| AX context | Block coordinates, maintained/weathered condition, Road Connected |
| AX action | Demolish Industrial for $256; Undo available |
| Construction | Foundation/flag visibly distinct from completed factory |
| Condition | Weathered L2, service causes and 46% vitality remain legible |
| Demolition | Parcel and city metrics visibly changed |
| Undo | State and metrics restored; retained save bytes exactly match |
| Reduce Motion | Same selected L2, HUD meaning, AX, and actionable identity |

## Retained screenshot hashes

| Capture | SHA-256 |
|---|---|
| candidate regular selected map | `fff4b863c064db43a1c655c680abead85e642e09228d6b27582af696cd3e93d0` |
| candidate compact selected map | `3ebf0f14aa60c5b2e36dc5509dfd2985966896f8032a54a2a19f06076d9b960b` |
| baseline regular selected map | `71b18aea4175a09983908bbada0fcdd1b7e604d341ddf73689f554c1c00d7f4a` |
| baseline compact selected map | `519cfa73698b66b0c82018288e7cc9cfa7a3e2bf7b2d48f3f0f06044ab999736` |
| candidate pressured L2 | `505e491585a98e3f930f5205294f9e5684aa1af980356708f13d2b7ccacf4123` |
| candidate construction | `db71cfc4142df075235c2a2a4e12569a73d15d5b718d8abfae624616e81e0c64` |
| post-demolition | `e04df9c79fff69d79b49954b6e64e5e30c3a9a3e904821663d6aec16d94de5cc` |
| post-Undo | `067abefc3001c44532e2e1f115b6bd60fa373e71d238332b7224a9a69701d910` |
