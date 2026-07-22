# PLAY-022 production world scale sheet

Status: Round 1 renderer authority
Projection: fixed orthographic 2:1 isometric
Lighting: northwest key, southeast baked shadow
Simulation ownership: one `CityTile` per visible place; presentation never reserves neighboring cells

## Camera and output budget

| Surface | Production value | Acceptance band |
|---|---:|---:|
| World tile | 72 x 36 pt | exact |
| Default/compact developed-bounds occupancy | 64% on limiting axis | 55-70% |
| City LOD | camera scale above 0.70, proof stop 0.74 | network, mass, landmark hierarchy |
| Neighborhood LOD | camera scale 0.61-0.70, proof stop 0.66 | frontage, crossings, family identity |
| Block LOD | camera scale at or below 0.60 | material, entrance, props, bounded life |
| Shipping output | native 2x backing scale | no source enlarged beyond its declared LOD budget |

The camera fits descriptor-derived developed visual bounds, nearby connected road arms, and three geometry-only expansion sockets. It does not imply build validity for those empty sockets.

Milestone 2 and 3 JSON records preserve the camera thresholds that were active
when those historical harness frames were exported. The final Round 1 staged
candidate uses the thresholds and proof stops above; final live evidence is
indexed under `docs/production/evidence/PLAY-022/round-1/live-3c44905/`.

## Physical vocabulary

| Element | Production value | Tolerance / role |
|---|---:|---|
| Asphalt corridor | 18 pt | socket-exact; +/-5% |
| Raised curb | 22 pt outer width | continuous at reciprocal sockets |
| Sidewalk | 27 pt outer width | continuous at reciprocal sockets |
| Crosswalk stripe | 1.2 pt x 5 | junctions only |
| Residential walk | 5.5 pt | entrance exclusion protected |
| Commercial/civic apron | 8 pt | entrance exclusion protected |
| Industrial/service drive | 10 pt | entrance exclusion protected |
| Adult figure | 7-9 pt tall | neighborhood/block only |
| Parked service object | 18 x 9 pt | curb socket; never route truth |
| Street tree | 15-20 pt crown | contact-grounded |
| Typical door | 6 x 11 pt | visual calibration, not collision truth |
| Typical floor | 11-13 pt | silhouette calibration |

## Calibrated retained-source envelopes

| Logical source | Opaque world envelope | Presentation footprint | Supported orientation |
|---|---:|---:|---|
| Residential L1 | 54.8 x 62.7 pt | 1 x 1 | south-facing fixed |
| Commercial L1 | 53.0 x 62.4 pt | 1 x 1 | south-facing fixed |
| Industrial L1 | 61.9 x 47.1 pt | 1 x 1 | south-facing fixed; original 2 x 1 template retained as provenance only |
| Park L1 | 72 x 36 pt | 1 x 1 | projection fixed; original 2 x 2 template retained as provenance only |
| City Hall L1 | 62.3 x 57.2 pt | 1 x 1 | south-facing fixed; original 2 x 2 template retained as provenance only |
| Water tower L1 | 46.6 x 82.4 pt | 1 x 1 | symmetric utility silhouette |

Each shipping LOD uses one stable world envelope and a per-export trim and ground anchor. Maximum permitted pivot drift is 0.5 source pixel. Ground-contact polygons must remain inside the authoritative 72 x 36 tile; roofs and vertical silhouettes may exceed the tile only through declared overhang.

## Visual hierarchy

1. Quiet terrain establishes the map field without per-cell borders.
2. Connected roads, curbs, sidewalks, crossings, and frontage joins establish movement and access.
3. Grounded building silhouettes carry place identity and lifecycle state.
4. Vegetation and bounded ambient life support scale at neighborhood/block detail.
5. Selection, placement, and diagnostic marks yield to architecture and never become a second HUD.

## Round 1B corrective evidence — `fc8b838`

This addendum records measured composition and residency for exact product
commit `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b` (tree
`1277422dabd28c67469b11516ba06692f978bc1a`). It does not revise the
authoritative tile, projection, pivot, lighting, frontage, or LOD vocabulary.

| Fixture | Fitted scale / detail | Occupied visual mass | Network/opportunity context | Gate |
|---|---|---:|---:|---|
| 1280 x 800 | `0.374546`, block | `62.41% x 85.04%` | `148.23% x 170.36%` | limiting axis passes 45% |
| exact 900 x 600 | `0.618716`, neighborhood | `54.00% x 122.09%` | `128.25% x 244.58%` | limiting axis passes 45% |

Occupied mass derives only from authoritative occupied lots and immediately
adjoining public realm. The larger network/opportunity rectangle is reported
separately and does not count toward occupied coverage.

Repeated LOD cycling retains 28 generated-v4 textures and 13,521,048 decoded
bytes with zero fallback. Production geometry validation retains zero
collisions across 616 checks. After three LOD cycles and a 60-second settle,
the exact staged compact sample reports 236 MB physical footprint and the
regular sample reports 300 MB, both below the 333.8 MiB ceiling. Independent
scoring remains the authority on whether the shipping composition reads as a
substantial connected neighborhood rather than a toy island.
