# PLAY-027 CONTRACT-019 R5 disposition

`HARD_PIPELINE_LIMIT`

The exact `0.0625` world-depth shader bias was applied to only
`v17-monumental-portal-header-wall` and
`v17-monumental-portal-lintel`, identically on fresh actual and semantic
node-local material copies. Both diagnostic processes retained the exact
51-node manifest
`611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f`.

The binding repeat and canonical gates failed:

- run A PNG:
  `7ab1ba2deca80480b26b2b7a9908f7fae1e7d22878c541502b215bf84d38b3b7`
- run A decoded RGBA:
  `5ff9b6c8e7af99440430738b034328deabf969e947839f545a4e75247337cdc0`
- run B PNG:
  `360afdd1f2650431ff73d6cfe5961e6d1ad7fa47c8424a01331d5d527a1d088b`
- run B decoded RGBA:
  `896e26417169181f838c3666a1ca5205ab18cfab6ba007f7dd991cf695c9c3b2`
- A/B difference: 195 pixels, 346 channels, bounds
  `[558,736,630,824]`
- canonical R3-A decoded RGBA required:
  `dab941daf6be1539218ee030cd8ddd32474b1296eaef0268d84c54301fe37925`
- run A differs from canonical at 226 pixels, including 195 outside the
  target projection/Lanczos support
- run B differs from canonical at 31 pixels, all inside support

Both runs retain the required literal-192 portal counts, but the source header
count is `1,284`, not required `1,275`. North jamb `1,562/21`, inset
`3,388/57`, and south jamb `155/3` remain exact.

Exactly two diagnostic-only SceneKit/Metal semantic processes were consumed.
Authoritative raw, normalizer, sibling, modeling, ingestion, shipping, source
authority, and production-selection process counts remain zero.

Per CONTRACT-019 R5, the depth-bias implementation has been removed from the
candidate. The failed implementation remains preserved in commit history and
the exact A/B PNGs, provenance, preflight, and final report remain immutable
evidence. All further SceneKit tuning and portal modeling are blocked.
