# PLAY-027 Commercial L3 design freeze

## Authority

- Synchronized authority: `72adc7770a87af6b7877a47343bf6f5faa978147`.
- Accepted Commercial L2 ancestor:
  `a224937e6aaae9c4824566403ead8c6087d646d9`.
- Published baseline ancestor:
  `4c0414b003a178948c62128f425b6d534ac2e7a7`.
- Authorized scope: Commercial L3 variant-zero north/east/south/west only.
- Commercial L4 and Industrial remain blocked.

## Density and family story

Commercial L3 is a five-floor office/department block. It advances beyond the
accepted L1 corner shop and L2 market arcade through a rusticated retail
podium, three-level terracotta office body, centered two-level burgundy
setback wing, stepped roof terraces, narrow vertical office-window rhythm,
formal brass-and-limestone lobby, and screened mechanical crown.

The silhouette is not a taller L2 box or a residential building with signs.
Commercial identity must survive unlabeled grayscale through the display
podium, formal lobby, vertical glazing, stepped roofline, and roof plant.

## Four-scene authorship

Every direction has a complete explicit descriptor with all four facade
planes, direction-specific entrance geometry, frontage edge/socket, props,
and occlusion exclusion. Descriptor and scene-geometry IDs are unique.
Sibling sources, mirroring, rotation, and orientation transforms are absent.

Shared building dimensions and materials describe one coherent building
identity. North and west use independently authored lateral lobby returns so
their grounded entrances remain visible from the fixed camera.

## Frozen geometry

- footprint: 56 x 56 world units on the accepted 72 x 36 tile basis;
- ground pivot: `(768,896)`;
- contact polygon: `(-28,-28) (28,-28) (28,28) (-28,28)`;
- five floors with an 83-unit authored wall envelope plus roof plant;
- accepted orthographic 2:1 camera and 1536 x 1024 source canvas;
- northwest light and southeast shadow vector `(2,1)`;
- `orientationTransform: none`;
- `productionSelected: false`.

No render may begin until all four descriptors parse, scene validation reports
four unique hashes and four unique geometry IDs, and this design checkpoint is
committed cleanly.
