# PLAY-027 Industrial L4 R4 edge-locality disposition

`PREPARATION_STATE_SPLIT`

The no-Metal analyzer reproduced all 143 immutable R3 A/B differing
coordinates. The 85 dominant `portal-header -> crucible-occluder` transitions
do not satisfy the R4 raster-edge rule:

- 71 of the 85 coordinates are stable 3×3 interior in at least one run.
- Run A boundary distance reaches 5 source pixels; run B reaches 2.
- Although every coordinate remains within 2 pixels of at least one run's
  relevant silhouette, R4 classifies any stable 3×3 interior as preparation
  state.
- None of the 143 differences intersects either provenance
  post-quantization mutation target set.
- The two 45-record post-quantization mutation sets are byte-identical at
  SHA-256 `65eb89deb49ae6a7432bbd71d2c3e0153508d6426180b59441f281615d0fd0a0`.

The complete coordinate ledger in `EDGE-LOCALITY.json` binds each A/B RGBA
value and semantic transition, silhouette-boundary distance, component
thickness/interior status, mutation-set intersection, analytic AABB
gap/overlap, and projected conservative component bounds. Two fresh analyzer
processes produced byte-identical output SHA-256
`30504318c3e4949c5320bcf2017ffb2e087cbdb697aaf2c0765436d9e1a14d8f`.

Portal status remains rejected. This packet is diagnostic-only:
`sourceAuthority=false`, `productionSelected=false`. No modeling, SceneKit,
Metal, raw, normalizer, sibling, renderer, resolver, descriptor, material, or
source process or mutation was performed.
