# PLAY-027 Residential L2 source-v05 review candidate

**Disposition:** frozen for independent review; not accepted; not production
selected.

## Density story

Residential L2 is a compact three-floor walk-up. A taller corner stair bay,
cross-gabled green roof, copper stair cap, warm ochre brick, floor string
courses, dense divided-light windows, flower boxes, and direction-specific
stoops distinguish it from the accepted two-floor L1 house. It does not inherit
L1's broad charcoal roof or rectilinear silhouette.

## Directional authorship

- North: explicit north frontage plus grounded east-facing return door and
  stoop at the stair-bay corner.
- East: explicit east frontage with full walk-up canopy and stairs.
- South: explicit south frontage with full walk-up canopy and stairs.
- West: explicit west frontage plus grounded south-facing return door and
  stoop.

Every scene descriptor is independent. No sibling source, scene, raster,
mirror, rotation, or transform is used. The four descriptor hashes and four
raw pixel hashes are unique.

## Determinism and technical gate

- Raw revision: `source-v05` N/E/S/W.
- Renderer source commit: `f03cd9e`.
- Each retained raw source is byte-identical to two additional native process
  renders.
- Each normalized LOD is byte-identical across two independent runs of the
  unchanged deterministic normalizer.
- Native validation passes four unique raw pixel hashes, twelve unique
  normalized pixel hashes, alpha range `0...255`, zero opaque chroma, zero
  visible magenta spill, transparent padding, and nonempty subject bounds.
- Scene validation passes unique descriptor hashes and explicit independent
  geometry/frontage declarations.

## Review surfaces

Review order is unlabeled row-major `N, E, S, W`.

- `SOURCE-V05-SOURCE-SCALE-REVIEW-CANDIDATE.png`
- `SOURCE-V05-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `SOURCE-V05-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `SOURCE-V05-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `SOURCE-V05-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `SOURCE-V05-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `SOURCE-V05-CONTACT-SHEET-ORDER-REVIEW-CANDIDATE.json`

This checkpoint authorizes neither batch selection nor renderer ingestion.
