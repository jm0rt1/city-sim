# PLAY-027 Commercial L2 design freeze

**Parent Commercial L1 checkpoint:** `9718b5e63d6322daa5b9616aea31244b3f3d6629`

**Calibration:** `commercial_l02/variant-0` north/east/south/west

**Planned first raw revision:** `source-v01`

**Production selected:** no

## Density and family story

Commercial L2 is a three-floor market/arcade, not a taller copy of the L1
corner shop. Its frozen building envelope uses:

- a rusticated warm-stone ground-floor market base;
- a burgundy two-floor upper market hall;
- a full-height terracotta projecting corner bay with its own flat copper
  crown;
- flat parapet/coping rather than a domestic roof;
- teal arcade and warm limestone horizontal hierarchy;
- two separately placed rooftop HVAC cabinets per direction;
- broad ground-floor display glazing plus two upper commercial window rows.

The four explicit descriptors each declare a `market-arcade` entrance on the
named road-facing facade. North/east/south/west scenes have independent scene
geometry IDs, descriptor hashes, entrance ownership, HVAC layouts, clearance
polygons, and frontage records. Every descriptor declares no sibling source,
mirror, rotation, or transform.

## Frozen contract

`SCENE-VALIDATION.json` passes with:

- four unique descriptor hashes and four unique scene-geometry IDs;
- fixed 1536 x 1024 source canvas and 2:1 orthographic camera;
- common footprint, building envelope, ground pivot `(768,896)`, northwest
  light, and southeast shadow vector `(2,1)`;
- exact N/E/S/W frontage sockets and door-base midpoints;
- three readable floors, four facade planes, at least eight ground-floor
  commercial glazing bays, and grouped rooftop mechanical treatment;
- `productionSelected: false`.

The preview plan reserves a taller registered crop for the three-floor
envelope and uses the deterministic native Core Graphics grayscale path frozen
with Commercial L1.

## Pixel gate

No Commercial L2 raster or normalization output exists at this checkpoint.
The first source render must show a complete building, footprint plate,
southeast shadow, and unmistakable target-face arcade in all four directions.
Fresh-process repeat identity, exact RGBA visibility, raw occupied-area
comparability, and color/grayscale native-2x review remain mandatory before
normalization. Two direction failures stop the level for local redesign.

Commercial L3/L4 remain blocked pending a separately frozen and visually
reviewed L2 candidate. Shipping, renderer, runtime, package, shared manifest,
and accepted Residential surfaces remain outside this checkpoint.
