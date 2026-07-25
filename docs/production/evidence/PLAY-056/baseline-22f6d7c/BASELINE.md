# PLAY-056 same-state baseline

This is the binding before packet for PLAY-056. The earlier capture under
`rejected-attempt-01/` is retained but rejected because it mixed mutable
runtime state and transients with clamped, mislabeled LOD frames.

## Exact identity

- Source commit: `22f6d7c6422d88ad0c3ef2fc95eb70050e575cec`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle identifier:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged app:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Executable SHA-256:
  `57275958a0079409f18fb3f161aa93b63ad9c9641ca06b25a577459035d571df`
- Staged generated-v4 manifest SHA-256:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`
- Candidate manifest SHA-256:
  `5ec9d770cdebca002fd40462ab928fa12e013074a8e505cca8fa2c296e56fb2d`

## Frozen state and capture protocol

- Fixture:
  `story-industrial-opening-v1.json`
- Fixture and isolated quicksave SHA-256:
  `b6fb32abafca99592a5ad5f0e7312c0cad7520c556c4b785e19e8894936ce0d3`
- Every capture launched the exact staged bundle with its isolated
  `CITYSIM_DATA_ROOT`, invoked Command-O, and waited at least 7.5 seconds.
- Every retained AX tree confirms `Day 17. Paused`.
- No retained AX tree contains the `City loaded` toast.
- The dark `Utilities` control in the strategy band is the legitimate
  persistent priority action and is intentionally preserved.

## Camera and semantic LOD proof

The first attempt assumed filenames and keyboard steps proved LOD. They did
not: regular `0` starts near scale `0.3128`, while the `1.22` zoom multiplier
can jump across the narrow neighborhood band.

The binding packet uses the renderer's supported debug-only
`CITYSIM_PROOF_CAMERA_SCALE` hook. The existing focused renderer export test
printed these exact semantic results:

| Window | Proof scale | Renderer detail |
|---|---:|---|
| regular | 0.31 | block |
| regular | 0.41 | neighborhood |
| regular | 0.45 | city |
| compact | 0.50 | block |
| compact | 0.55 | neighborhood |
| compact | 0.65 | city |

The scale override intentionally causes the existing starting-occupancy
assertions to fail outside their default camera; those diagnostic invocations
are not validation results. They are retained solely as scale-to-LOD
measurements. The unmodified default-scale invocation passes and reports
regular `0.312796950340271 / block` and compact
`0.5447090268135071 / neighborhood`.

## Binding image hashes

| Frame | SHA-256 |
|---|---|
| `live/regular-block-lod.jpeg` | `d76a47782dad4613abd1429f63524f79691d063333f96adf5c0181784dc09bc1` |
| `live/regular-neighborhood-lod.jpeg` | `ad84d7c84e53f65ab926aef3c01adfaa24c633d78c355d9a2f005c1fe6b83851` |
| `live/regular-city-lod.jpeg` | `5723eebaf02a69bca6041b8d1eee8fb8f9cc978503f4e2154e1e3b949e6ef05c` |
| `live/compact-block-lod.jpeg` | `3ecb3bddd7e5f6106503f87bd25b9e6731aef910d9e31477e064747dc1a3235b` |
| `live/compact-neighborhood-lod.jpeg` | `83a5c7ef9a69cb2c79ee37d49fda93451f14e62e053e9c0cec42c846473c1f40` |
| `live/compact-city-lod.jpeg` | `859ad58bf8284ccff1a59c85e78db909b26ae2a0ac1c1aeeb9f4c5620ca6f4bd` |

All six hashes differ for legitimate scale and semantic-detail reasons. The
regular frames are uncropped 1,278 by 768 content captures. The compact frames
are uncropped 900 by 652 decorated-window captures containing an exact
900 by 600 content area.

## Player-visible before findings

- The park is a flat turquoise slab with one pale path and little material or
  compositional depth.
- Vacant land repeats the same small vegetation cluster at conspicuous
  intervals.
- Streets and curbs carry very little grounded public-realm life.
- Land Value and Traffic are primarily communicated by the legend rather than
  a strong localized map response.
- Existing ambient objects are sparse enough that the city reads as paused
  scenery even when decorative motion is enabled.

This packet freezes those defects; it does not accept them.
