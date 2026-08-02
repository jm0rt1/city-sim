# PLAY-073 R4-B color-identity frontier resolution

**Classification:** frontier authority after the final Luna repair stopped

**Clean Git HEAD:** `a01ad44c563d9b2fbf3d9d3a59208ddd896d52c7`

**Preserved one-file working diff SHA-256:** `fe7042c004dceef05c8aa0aa55878eece405d8850a5f6806587b6e2eb7a8ed8e`

Luna correctly stopped because a one-bit perturbation to an input
`calibratedRed` value is normalized away by `NSColor` before it becomes the
realized render color. The correct proof boundary is the exact realized color,
not constructor input bits and not rounded text.

## Decision

Continue from the exact preserved one-file diff only after its binary diff hash
matches the value above.

- Keep lossless path element identity using element type and exact coordinate
  bit patterns.
- Canonicalize each `NSColor` through `usingColorSpace(.deviceRGB)`, matching
  the prior semantic comparison boundary.
- Compare exact bit patterns of the realized red, green, blue, and alpha
  components. Do not compare raw color-space object identity.
- For the color adversary, use a device-RGB red delta small enough that the old
  six-decimal string comparison remains equal but large enough to survive
  `NSColor` realization. `0.25` versus `0.2500002` is the approved pair.
  Assert both premises before asserting the lossless signatures differ.
- The coordinate adversary remains an exact one-bit representable scalar drift.

Only `WorldRenderingTests.swift`, the existing `RESULT.json`, and existing
`HANDOFF.md` may change. Renderer product source and geometry are frozen.
Run both targeted adversaries, all `WorldRenderingTests`, JSON validation,
path/hash review, and diff check. Commit one clean frontier-resolution result.
Stop on any remaining failure, product change, path expansion, or ambiguity.
Integration still owns the full suite, staged app, visual acceptance,
integration, and push.
