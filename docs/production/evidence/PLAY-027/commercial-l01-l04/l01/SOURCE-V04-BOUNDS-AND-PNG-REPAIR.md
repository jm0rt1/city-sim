# PLAY-027 Commercial L1 source-v04 bounds and PNG repair

**Scope:** Commercial L1 variant-zero N/E/S/W only

**Production selected:** no

Source-v03 proved stable SceneKit pixels but did not produce reliably complete
east/west presentation in the independent review decoder. Source-v04 adds two
separate hard gates around the unchanged source-v03 geometry.

## Rendered-node volume gate

Before snapshot, the exporter records the root presentation's complete
geometry bounds. It fails unless those bounds contain the descriptor's full
foundation footprint and minimum building height. The per-direction render
record retains minimum/maximum world coordinates and the required footprint
half-extents so N/E/S/W can be compared directly.

## Raw occupied-area gate

Before PNG writing, the exporter inspects canonical RGBA pixels. It fails
unless the non-chroma result contains at least 50,000 pixels and spans at
least 400 x 260 source pixels. That lower bound covers the building,
registered footprint plate, and southeast shadow rather than allowing a thin
facade slice to pass.

The standalone native validator independently enforces the same values on
decoded raw files and records occupied pixel count plus exact bounds.

## Review-decoder-safe PNG encoding

Core Graphics and ImageIO still create the canonical pixel image. The final
byte encoding is passed once through macOS `/usr/bin/sips`, a native ImageIO
front end on the already fingerprinted host. This changes no pixel, geometry,
camera, registration, material, or alpha authority; it produces a
deterministic PNG representation that the independent review decoder presents
completely. The intermediate ImageIO PNG is temporary and never becomes
source authority.

All directions advance together to `source-v04`. Geometry-v2, the four unique
direction descriptors, and all footprint/pivot/frontage/light/shadow contracts
remain unchanged.
