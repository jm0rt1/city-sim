# PLAY-097 Residential L1 Variant Two — v03 source self-check

## Reference and result

The supplied benchmark established the required bar: a premium hand-painted
isometric building with a credible lot, entry, landscape, architectural detail,
and gameplay-scale silhouette. v03 uses a fresh red-brick/limestone townhouse
rather than any rejected v01/v02 pixels.

## Observed against the bar

- **Architecture:** PASS for a coherent 2.5-story low-density townhouse: slate
  hipped roof, dormers, chimney, masonry trim, divided-light windows, and a
  substantial porch/stoop read as one building rather than disconnected props.
- **Lot, entry, and ground contact:** PASS: each view shows a bounded yard,
  fence, planting, visible walk or stoop, and a clear base/paving relationship.
- **Gameplay silhouette:** PASS for source visual disposition: roof/brick/trim
  hierarchy and dense landscaped perimeter remain legible without the prior
  flat-field or kiosk impression.
- **Four authored views:** PASS mechanically: four separate ImageGen calls and
  four unique raw SHA-256 values. Each view has a different porch, entry,
  window, bay/dormer, and garden arrangement; no raster was mirrored, rotated,
  or copied.

## Deliberate boundary

This is a source-only visual candidate for a fast independent disposition. The
raw masters retain their generator-native 1774x887 RGB chroma-key canvases and
have not been normalized, registered to the 1536x1024 source canvas, derived
to LODs, admitted, quarantined, selected, or connected to runtime/catalog
resources. Those later steps require their own authorized source/renderer work.
