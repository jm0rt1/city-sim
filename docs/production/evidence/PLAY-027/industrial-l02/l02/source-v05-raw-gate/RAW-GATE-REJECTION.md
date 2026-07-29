# PLAY-027 Industrial L2 source-v05 raw gate rejection

Disposition: **rejected and frozen after exact repeat-identity failure.**

The governed raw gate ran exactly twelve fresh Metal-visible SceneKit
processes from clean descriptor authority
`299fdd4cb2fe764421ba0c1f81daa09c63486a35`: primary, B, and C for each
independently authored North, East, South, and West descriptor. No diagnostic
CLI override was used. Every retained provenance record binds the
`authored-constant-v1` material model, zero-intensity/no-shadow SceneKit
lights, no MSAA, disabled SceneKit shadows, factor-4 linear oversampling,
software Lanczos 0.25 downsampling, the frozen step-32 quantizer and schema-2
v3 canonicalizer, the authored contact shadow, and
`productionSelected: false`.

All four primary raws are complete and visually reviewable. They pass the
fixed occupied-area and bounds gates, exact RGBA visibility, opaque flat
chroma corners, zero hidden non-magenta pixels, and four-direction primary
uniqueness. The retained review sheets show a grounded N/E/S/W industrial
volume, distinct logistics frontages, recovered northwest-lit material/value
hierarchy, and clear progression from accepted Industrial L1. The East
comparison also preserves the rejected source-v04 and flattened diagnostic
context.

The binding repeat gate nevertheless fails in all four directions:

- North has two file identities and two decoded-pixel identities; primary and
  C match while B differs at two pixels.
- East has three file identities and three decoded-pixel identities; the
  largest comparison differs at 724 pixels with no alpha difference.
- South has two file identities and two decoded-pixel identities; primary
  differs from matching B/C by one red-channel value.
- West has two file identities and two decoded-pixel identities; primary
  differs from matching B/C by one red-channel value.

The strengthened raw validator now requires both exact file identity and exact
canonical decoded-pixel identity. The per-direction reports and pixel-locality
zoom sheets preserve exact hashes, coordinates, channel values, alpha, and
difference bounds. Visual completeness does not waive the deterministic
failure.

The governed stop was applied. No normalization, LOD generation, source-v06,
causal diagnostic, production selection, renderer ingestion, shipping/runtime
mutation, or accepted-art mutation was performed. Further work requires a new
integration disposition.
