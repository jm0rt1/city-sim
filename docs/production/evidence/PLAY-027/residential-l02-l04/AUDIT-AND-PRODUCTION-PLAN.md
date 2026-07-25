# PLAY-027 Residential L2-L4 audit and production plan

**Authority:** `1744c3d62dd45ee206035793366c45a811c47229`

**Accepted calibration baseline:** `6380037d42ede73eca60aac4a9b1c7b710f681d6`

**Authorized scope:** Residential L2, L3, and L4 variant-zero N/E/S/W only

**Production selected:** no

## Read-only coverage audit

The current task-owned offline catalog contains the independently accepted
Residential L1 variant-zero four-view set and its retained rejected attempts.
It contains no scene descriptor, raw source, normalized source, provenance
record, review panel, or selected production record for Residential L2, L3,
or L4.

All twelve authorized source keys are therefore missing, not aliased. No
Commercial or Industrial source will be started in this slice.

## Frozen registration and family anchors

Every level keeps the accepted L1 contract:

- 72 x 36 point tile basis and 72 x 72 scene footprint;
- source footprint diamond `[[768,640],[1024,768],[768,896],[512,768]]`;
- ground pivot `(768,896)` and contact polygon
  `[[-28,-28],[28,-28],[28,28],[-28,28]]`;
- direction-specific frontage edges, midpoint sockets, and door-base records;
- fixed orthographic 2:1 camera, northwest key, southeast `(2,1)` shadow,
  chroma source field, floor/door scale, and `orientationTransform: none`;
- accepted warm residential family palette, limestone hierarchy, warm
  windows, planting accents, and neutral normalized-alpha review field.

L1 source pixels and descriptors remain unchanged. Its broad dark hip roof and
rectilinear two-floor silhouette are expressly not a higher-level template.

## Frozen density stories

### Residential L2 — compact corner walk-up

- three readable floors;
- compact main mass plus a taller articulated corner stair bay;
- intersecting cross-gabled roof volumes rather than one broad hip;
- paired and grouped window rhythm, modest balconies, and a visible walk-up
  stoop;
- warm ochre masonry with red-brick and limestone accents.

### Residential L3 — stepped courtyard mid-rise

- five readable floors;
- independently declared U-shaped west/east/rear wings around a foreground
  courtyard opening;
- different wing heights and flat parapet roofs;
- denser window cadence, courtyard planting, and a broad arched residential
  entry;
- deeper terracotta masonry with warm stone bands.

### Residential L4 — podium-and-tower urban residential

- seven readable floors;
- broad three-floor podium supporting an offset four-floor tower;
- stepped roof terraces and a distinct copper-toned crown roof;
- strong vertical window stacks, balcony bands, and a bright urban lobby;
- warm stone podium, brick tower, and dark green/copper roof hierarchy.

## Directional authorship

Each level receives four explicit scene descriptors. Every descriptor declares
all facade records, windows, entrance geometry, frontage edge/socket, props,
and occlusion exclusions. No descriptor or raster is mirrored, rotated, or
transformed from a sibling.

North and west use independently positioned grounded frontage returns where
the fixed camera would otherwise occlude the named edge. East and south keep
their entrance mass directly readable. A failed direction is retained and
repaired locally; after two direction failures in one level, rendering stops
for template repair.

## Checkpoints and proof

Each level is a coherent four-source checkpoint with:

1. four unique raw hashes and three-process raw byte identity;
2. deterministic normalized block/neighborhood/city outputs and unique hashes;
3. alpha, chroma, padding, pivot, frontage, projection, light, and shadow
   validation;
4. normalized-alpha actual-scale, grayscale, exact-envelope, and zoom panels;
5. accepted/rejected inventory and complete tool/scene/material provenance.

The final slice adds an unlabeled cross-level density sheet so L2, L3, and L4
must remain recognizable by massing and vertical rhythm in color and
grayscale. Independent quality, not this lane, decides acceptance.

Renderer ingestion, atlas pages, shared manifests, `Package.swift`, product
runtime code, production selection, push, and integration remain out of scope.
