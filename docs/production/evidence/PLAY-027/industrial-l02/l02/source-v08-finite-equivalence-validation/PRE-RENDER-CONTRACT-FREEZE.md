# PLAY-027 Industrial L2 East finite-equivalence validation contract

**Status:** Frozen before pixels
**Authority:** `0696f69a223196253bb613f314384e41ee765df8`
**Scope:** Industrial L2 variant-zero East only

This checkpoint adds one task-owned offline validation contract over the
immutable source-v06 East descriptor. It does not create a source-v08 scene,
change the authored building, or grant production authority.

The contract binds:

- descriptor SHA-256
  `70b36a0e76581524e64d40f19e364659eed6a53d7f7ab8d8924c51ba5d0951dd`;
- finite table SHA-256
  `7c2d5940b8fca22d1e2cb15fa248ab678e8b8266fb3ed453332d82474284ed31`;
- 57 exact 4× coordinates, two disjoint classes, and 15 observed tuples;
- a pure single-frame RGB transform with no cross-run state;
- byte-exact pass-through outside the governed coordinates;
- rejection on descriptor, table, dimensions, input hash, tuple, class, alpha,
  chroma, output-scope, or evidence-path drift.

The renderer retains the complete pre-map and mapped 6144×4096 RGBA frames,
the post-Lanczos prequantized image, downstream stage records, ImageIO output,
and final sips output. The contract is admitted only through the task-owned
diagnostic stage path and only for one new `run-a`, `run-b`, or `run-c`
directory beneath the frozen PLAY-027 validation evidence root.

The standalone adversarial test passes descriptor/table/input hash and
dimension drift, unknown tuple, duplicate/ambiguous class, alpha/chroma,
out-of-scope write, and repeat-application identity checks. The offline
renderer also compiles independently.

No fresh Metal process, normalization, production selection, shipping/runtime
change, N/S/W mutation, or source-scene/material change has occurred at this
boundary.
