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
| City LOD | camera scale above 1.15 | network, mass, landmark hierarchy |
| Neighborhood LOD | camera scale 0.61-1.15 | frontage, crossings, family identity |
| Block LOD | camera scale at or below 0.60 | material, entrance, props, bounded life |
| Shipping output | native 2x backing scale | no source enlarged beyond its declared LOD budget |

The camera fits descriptor-derived developed visual bounds, nearby connected road arms, and three geometry-only expansion sockets. It does not imply build validity for those empty sockets.

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
