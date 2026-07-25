# PLAY-027 north raw pixel determinism failure

**Disposition:** rejected renderer output; retained for diagnosis

The native SceneKit renderer produced two independently retained north
residential L1 variant-zero runs from renderer source commit
`b5a01c58a58ed2fa3061d839b08153b9f35157bb`.

Both sources are 1536 x 1024 opaque RGBA, have exact `#ff00ff` corners, and
share the same non-chroma bounds `(619,640)-(1029,906)`. Their canonical
8-bit sRGB RGBA pixel hashes differ. A diagnostic comparison found two pixels
with a one-code-value RGB difference:

- `(741,740)`: blue `2` versus `1`;
- `(738,770)`: red `46` versus `47`.

This fails CONTRACT-011 pixel identity even though the visible render,
geometry, matte coverage, and bounds are unchanged. Neither retained run is
accepted or production-selected. The renderer must deterministically quantize
its final non-chroma RGB values before another governed north attempt.
