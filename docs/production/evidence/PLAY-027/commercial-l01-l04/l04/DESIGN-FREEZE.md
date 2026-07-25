# PLAY-027 Commercial L4 design freeze

## Authority

- Exact accepted Commercial L3 base:
  `71655d5dbaf8a56fa287e68b5b99159ee4ba6144`.
- Authorized scope: Commercial L4 variant-zero north/east/south/west only.
- Industrial, renderer ingestion, shipping selection, shared manifests, and
  runtime changes remain blocked.

## Density and family story

Commercial L4 is an eight-floor premium urban office tower. It advances
materially beyond the accepted L3 office/department block through:

- a stone retail and formal lobby podium;
- a broad, high-value limestone lower office shaft;
- a narrower burgundy upper shaft with a second setback;
- a copper executive crown story and lantern;
- three stepped roof terraces and a materially larger screened mechanical
  penthouse;
- a 4/4/3/2 window rhythm that changes at every massing tier.

The silhouette must read as a top-tier commercial tower at block,
neighborhood, and city LODs rather than a taller L3 box. Premium stone,
burgundy masonry, copper, blue office glazing, and a monumental tower lobby
must preserve commercial family identity and value separation in grayscale.

## Four-scene authorship

Every direction has a complete explicit descriptor with all four facade
planes, direction-specific tower-lobby geometry, frontage edge/socket, three
direction-specific rooftop mechanical props, and an occlusion exclusion.
Descriptor and scene-geometry IDs are unique. Sibling sources, mirroring,
rotation, and orientation transforms are absent.

Shared building dimensions and the accepted material library describe one
coherent building identity. North and west use independently authored lateral
lobby returns so their grounded entrances remain visible from the fixed
camera.

## Frozen geometry

- footprint: 56 x 56 world units on the accepted 72 x 36 tile basis;
- ground pivot: `(768,896)`;
- contact polygon: `(-28,-28) (28,-28) (28,28) (-28,28)`;
- eight floors with four distinct vertical massing tiers;
- 132-unit authored wall envelope plus crown and mechanical roof;
- accepted orthographic 2:1 camera and 1536 x 1024 source canvas;
- northwest light and southeast shadow vector `(2,1)`;
- `orientationTransform: none`;
- `productionSelected: false`.

No render may begin until all four descriptors parse, scene validation reports
four unique hashes and four unique geometry IDs, accepted L1-L3 owned paths
remain byte-identical to `71655d5`, and this design checkpoint is committed
cleanly.
