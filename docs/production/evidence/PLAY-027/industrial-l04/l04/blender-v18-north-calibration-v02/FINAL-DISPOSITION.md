# PLAY-027 CONTRACT-020 R2 Blender North calibration

**Disposition:** `PENDING_INDEPENDENT_RENDERER_QA_REVIEW`

The formula-bound camera repair passes the pre-render projection gate, and the
three authorized fresh Blender/Cycles processes completed without a fourth
process.

All A/B/C decoded premultiplied RGBA values are identical at
`63a7b9239fda3e6dd753e76783af311fc1b8cfb01b8fbe34a80ef17a70bf6623`.
The three PNG container hashes differ and are retained; CONTRACT-020 R2 binds
decoded RGBA identity, occupied bounds, and object manifests rather than PNG
encoder-container identity.

Shared results:

- alpha bounds: `[439,589,1025,997]`
- padding: `[439,589,511,27]`
- visible pixels: `130848`
- hidden RGB at alpha zero: `0`
- exact chroma at nonzero alpha: `0`
- near chroma at nonzero alpha: `0`
- object mapping:
  `1020c2ef11c56c09ae29beb168a84f8bcd4d13c5f4aa306eaaebc735015076e5`
- projection proof:
  `153fa1d6d3c590c4767a6cbbb834001d08478e3aa2ec70142ba0acf47fe007ed`
- rendered components/materials: `51/13`

The retained comparison packet includes literal source, native-2x, exact
192×128, grayscale, alpha occupancy, registration/contact, v18 SceneKit
semantic, and accepted Industrial L3 panels. World Art makes no source or
production-selection claim; Renderer and QA own the independent disposition.

No SceneKit, normalizer, sibling direction, portal redesign, ingestion,
shipping, package, runtime, or production-selection work occurred.
