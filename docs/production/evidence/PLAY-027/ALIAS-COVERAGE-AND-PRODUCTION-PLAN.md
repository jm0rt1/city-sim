# PLAY-027 alias, coverage, and production plan

**Audit authority:** `d91dc81a4e6e38387e5af8621c4275f8be2bb96f`

**Branch:** `codex/citysim-world-art`

**Audit date:** July 24, 2026

**Disposition:** durable read-only baseline; source production may proceed

## Scope and method

This audit reads the generated-v4 calibration catalog, retained ImageGen
sources and provenance, deterministic normalized exports, production-selected
generated-v4 manifest, CONTRACT-006, CONTRACT-010, the PLAY-022 program and
scale sheet, and the PLAY-027 claim. It does not alter or accept the shipping
pack.

The following checks produced no duplicate groups:

- 12 calibration logical IDs;
- 12 retained raw calibration SHA-256 values;
- 36 normalized calibration SHA-256 values;
- 12 production-manifest source SHA-256 values;
- 36 production-manifest packed payload-pixel SHA-256 values.

The present catalog therefore has no observed cross-type byte or pixel alias
among its existing 12 calibration assets. That is not directional coverage:
the only R/C/I building sources are fixed south-facing level-one calibration
masters.

## Anchor and template status

| Role | Exact retained input | SHA-256 | PLAY-027 use |
|---|---|---|---|
| Appearance-only global style anchor | `Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png` | `b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425` | Immutable appearance reference only. Independent quality verified the retained source; it is not production geometry or shipping acceptance. |
| Residential family anchor | `Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/residential_l01/source-v01.png` | `e15a388c2a1a0a55488457211c23939f70eca255cbae733ee0f7b39b141c962e` | Material, floor/door scale, roof and residential identity reference only. |
| Commercial family anchor | `Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/commercial_l01/source-v01.png` | `90207ec4ed651810df863e0ff21591c85eea444f8606c41c83e85060e4c1de89` | Material, floor/door scale, storefront rhythm and commercial identity reference only. |
| Industrial family anchor | `Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png` | `22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515` | Material, loading-door scale, roof rhythm and industrial identity reference only. |
| Directional registration geometry | `Native/CitySimNative/WorldArt/GeneratedV4/templates/registration-1x1.png` | `6ad1db2e7b8f670718ff4a4eb8c183737b0dec859559a2eab6a25746b53cff67` | Exact 1536 x 1024 canvas, 512 x 256 source tile, 768 x 896 pivot, 1 x 1 footprint and named sockets. |

The scale sheet makes one authoritative simulation tile the presentation
footprint for every R/C/I building. The earlier industrial 2 x 1 generation
template remains provenance only. PLAY-027 therefore freezes the 1 x 1
registration geometry for all 12 R/C/I variant-zero identities.

The three family anchors are distinct retained calibration masters accepted by
the renderer lane for its calibration candidate. They are not counted as
PLAY-027 directional sources because they lack the CONTRACT-010 directional
source record and complete four-view sibling set. A generated PLAY-027 attempt
may never reference a rejected sibling.

## 48-source variant-zero coverage matrix

Legend:

- `missing` — no PLAY-027 governed source attempt or source record exists;
- `calibration anchor only` — a separately authored earlier south-facing
  calibration master exists, but it is not PLAY-027 directional coverage.

| Logical building ID | Family | Level | North | East | South | West | PLAY-027 accepted |
|---|---|---:|---|---|---|---|---:|
| `residential_l01` | residential | 1 | missing | missing | calibration anchor only | missing | 0 / 4 |
| `residential_l02` | residential | 2 | missing | missing | missing | missing | 0 / 4 |
| `residential_l03` | residential | 3 | missing | missing | missing | missing | 0 / 4 |
| `residential_l04` | residential | 4 | missing | missing | missing | missing | 0 / 4 |
| `commercial_l01` | commercial | 1 | missing | missing | calibration anchor only | missing | 0 / 4 |
| `commercial_l02` | commercial | 2 | missing | missing | missing | missing | 0 / 4 |
| `commercial_l03` | commercial | 3 | missing | missing | missing | missing | 0 / 4 |
| `commercial_l04` | commercial | 4 | missing | missing | missing | missing | 0 / 4 |
| `industrial_l01` | industrial | 1 | missing | missing | calibration anchor only | missing | 0 / 4 |
| `industrial_l02` | industrial | 2 | missing | missing | missing | missing | 0 / 4 |
| `industrial_l03` | industrial | 3 | missing | missing | missing | missing | 0 / 4 |
| `industrial_l04` | industrial | 4 | missing | missing | missing | missing | 0 / 4 |

Baseline PLAY-027 directional coverage is **0 / 48**. The three retained
south-facing calibration masters are appearance anchors, not accepted
directional siblings.

## Exact production order

Production is twelve independently reviewable four-view sets:

1. `residential_l01/variant-0`: north, east, south, west;
2. `residential_l02/variant-0`: north, east, south, west;
3. `residential_l03/variant-0`: north, east, south, west;
4. `residential_l04/variant-0`: north, east, south, west;
5. `commercial_l01/variant-0`: north, east, south, west;
6. `commercial_l02/variant-0`: north, east, south, west;
7. `commercial_l03/variant-0`: north, east, south, west;
8. `commercial_l04/variant-0`: north, east, south, west;
9. `industrial_l01/variant-0`: north, east, south, west;
10. `industrial_l02/variant-0`: north, east, south, west;
11. `industrial_l03/variant-0`: north, east, south, west;
12. `industrial_l04/variant-0`: north, east, south, west.

Every attempt uses one built-in ImageGen call and receives an immutable source
key:

```text
<logical-building-id>/variant-0/<north|east|south|west>/source-vNN
```

For each call:

1. load the exact frozen style, family, and geometry hashes;
2. use the CONTRACT-006 prompt prefix with one declared frontage and entrance;
3. save the raw result immediately without overwriting any prior attempt;
4. record the full prompt, model exposure, date, input hashes, raw hash and
   initial reviewer state;
5. normalize only with a task-owned deterministic PLAY-027 tool and declared
   registration values;
6. reject perspective, projection, direction, entrance, scale, pivot,
   envelope, light, shadow, chroma, padding, silhouette or material drift;
7. after two consecutive directional-drift failures in one family, stop that
   family and repair its anchor/template record before another call.

## Four-view set gate

No view becomes accepted merely because normalization succeeds. A coherent set
must retain:

- four distinct raw and normalized hashes with
  `orientationTransform: none`;
- identical 1 x 1 footprint/contact coordinates and 768 x 896 ground pivot;
- declared north/east/south/west frontage socket and entrance exclusion zone;
- no more than five-percent opaque-envelope drift unless the frozen template
  explicitly records the exception;
- coherent floor and door scale, family materials, northwest key and southeast
  shadow;
- alpha/chroma/padding validation;
- source-size and actual-game-scale N/E/S/W contact sheets;
- an unlabeled grayscale family-recognition sheet;
- explicit accepted and rejected inventories.

Each accepted four-view set is committed as one focused PLAY-027 checkpoint.
Renderer ingestion, atlas pages, live mapping, production selection, staged-app
proof, integration and self-acceptance remain out of scope.
