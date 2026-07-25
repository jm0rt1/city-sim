# PLAY-027 Commercial directional template architecture

## Frozen contracts

Every Commercial level retains the accepted Residential registration contract:

- 1536 x 1024 source canvas and 2x native oversampling;
- 72 x 36 point tile basis and 72 x 72 scene footprint;
- fixed source diamond, pivot `(768,896)`, contact polygon, frontage edge,
  socket, and direction-specific door base;
- fixed orthographic camera, northwest key, southeast `(2,1)` shadow;
- explicit N/E/S/W descriptors with no sibling source, mirror, rotation, or
  transform.

The global Gate A image remains the appearance-only style anchor. The existing
generated-v4 Commercial L1 source is the appearance-only family anchor.
Commercial materials are numeric task-owned inputs; no ImageGen swatch is
required.

## Commercial identity system

Commercial identity is structural rather than textual:

- floor-one storefront glazing is taller and wider than upper windows;
- each road-facing descriptor declares a shopfront, arcade, office lobby, or
  tower lobby with a broad canopy and transom;
- warm display glass and cooler office glass create a strong grayscale value
  hierarchy;
- flat parapets, coping, roof terraces, and explicit HVAC replace domestic
  chimneys and broad residential roof silhouettes;
- level progression changes massing, height, facade cadence, lobby scale, and
  roof-mechanical composition.

The task-local renderer suppresses Residential floor-one flower boxes for the
Commercial family and adds deterministic storefront/lobby and HVAC geometry.
No product runtime or shipping dependency consumes these authoring features.
