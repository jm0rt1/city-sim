# PLAY-027 Industrial L4 Turbine material pre-pixel disposition

**Candidate:** `104027f29fce44fb734c010625a4f8f8fc509c2c`

**Disposition:** `REJECTED_PROOF_BINDING`

**Source authority:** `false`

**Production selected:** `false`

The material hierarchy is retained as a useful art-direction checkpoint, but
the packet is rejected for pixel-production authority.

## Binding failure

The v06 source/color/clay raster path draws each untransformed local
`DirectionPlan` through one fixed analytic projection. The committed
descriptors separately apply direction-specific `worldPoint`,
`worldDimensions`, and camera transforms. The frontage, socket, and pivot
overlays therefore move to the declared N/E/S/W diamond edges while the
pictured facade does not prove the same transformed scene.

The literal 768-by-512 cells expose the mismatch: the opaque asset ends at
Y=412 while the registered pivot scales to Y=448, leaving a 36-pixel gap. The
v06 validator does not prove pixel-to-footprint, pivot, socket, door-base, or
contact alignment.

## Gameplay-scale return

At exact 192-by-128:

- median opaque luminance is 34 for North and 51 for East/South/West;
- approximately 15 percent of opaque pixels are at or below luma 32;
- the staff-entry identity collapses in literal grayscale and neighborhood
  presentation.

## Preservation

The exact committed v06 packet remains immutable under:

- `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v06-prepixel/`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-works-v06-material-prepixel/`

The combined sorted file-hash ledger digest for those two roots is
`c5d006a9d0ff27443ac4b84672ff56fdaf45a52949e2a9a48e9b9e959c64f1fb`.
No raw SceneKit/Metal source process or normalization process was run.

The next candidate must render its analytic proof from the exact descriptor
geometry and camera, assert registration against those pixels, and improve the
compact grayscale hierarchy without weakening the freight recesses or making
orange trim noisy.
