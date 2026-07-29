# Industrial L4 North v08 Process A calibration authority

- **Disposition:** `PREPIXEL_PASS_PROCESS_A_ONLY`
- **Owner:** Integration
- **Task/lane:** `PLAY-027` / North World Art
- **Accepted pre-pixel candidate:**
  `e694987a6dc1e81f341641f29d2ddc7cc4d57a65`
- **Scene SHA-256:**
  `08050bd6b4a6afae530af55afef65c88a76e5722430dc45cd36d1ccfcceb5b26`
- **Material SHA-256:**
  `ad736d509f79e10520b5431c54edca06d2cf5927947e09aae3352e5c11007822`
- **Pixel authority:** one fresh North Process A calibration only
- **DCC compute envelope:** one simultaneous process

Independent review passes v08 for one source-scale appearance calibration.
The compact envelope is `64×59`, equal to accepted Industrial L3; the primary
mass occupies `45.09%`; the portal is `9×15`; all three freight recesses retain
25 pixels; the hot-process cue is `8×15`; six grayscale value bins survive;
registration drift is below `0.000184` source pixels; and the evidence reports
zero structural-plane collisions or primary-volume overlaps.

The known risk is value separation: the hot-process cue luma (`116`) is close
to masonry (`104`), and accepted Industrial L3 retains a stronger vertical
landmark. Process A must increase hot-process separation without enlarging the
compact envelope, weakening the portal/freight hierarchy, changing the
road-facing North socket, or introducing overlap.

## Authorized sequence

After the current v2 zero-pixel binding checkpoint is committed cleanly and
this authority commit is merged:

1. Freeze the exact v08 scene/material/tool inputs above.
2. Launch exactly one fresh North Process A in a new immutable task-owned
   output root.
3. Preserve raw source, semantic source, provenance, registration, object
   mapping, invocation receipt, file hash, canonical decoded-RGBA hash, alpha/
   chroma/hidden-RGB metrics, and rejected-attempt inventory immediately.
4. Produce source-scale, literal-192 color, literal-192 grayscale, compact
   color, and compact grayscale review surfaces without normalizing or
   selecting the source.
5. Commit a clean `PLAY-027` calibration checkpoint and return it for
   independent technical and literal-scale review.

## Explicitly not authorized

- North B/C;
- East, South, or West source pixels;
- normalization or LOD production;
- an appearance lock or source-production profile;
- `source_candidate`, `integration_admitted`, Renderer quarantine, production
  selection, shipping activation, runtime lookup, or staged-app work; or
- changes to shared tools, manifests, atlas pages, package topology, or
  sibling-owned paths.

Integration may publish the non-production appearance lock and shared
source-production profile only after this exact Process A passes independent
technical and literal-scale review.
