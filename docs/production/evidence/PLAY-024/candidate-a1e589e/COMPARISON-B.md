# PLAY-024 Comparison B — Authoritative Starter District

- **Exact renderer product:** `a1e589e68783e25dc5788b055b3b9e786acb4b69`
- **Platform adoption checkpoint:** `60bf0c066cd7a5d75e399b518ae697fbd73690eb`
- **Platform product:** `29cfc272ad74ecd4de741ffe6903e09fc952d875`
- **Gameplay product:** `a0ce861`
- **World/platform merge:** `f4ebca3c2fb9558a7d5ff83189319ca9ef39d9e6`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Staged app:** `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- **Disposition:** author evidence for independent PLAY-053 scoring; no
  self-score or acceptance claim

## Comparison boundary

This is **Comparison B** evidence. It captures the accepted authoritative
32-road, two-block starter district after gameplay and platform adoption. It is
not a same-state comparison with the retired one-cross opening. The immutable
same-state PLAY-024 packet remains at product `20edac8` and evidence `4e0bb39`.

The staged app was launched without a save and paused before any player build,
bulldoze, placement, or topology mutation. The clock reached Day 8 before the
pause input was accepted; the retained frames therefore show the unmodified
fresh-start topology at Day 8.

## Topology and renderer adoption

- 32 authoritative, connected road cells form the two-block starter district.
- Eight authoritative occupied lots render from `CityGameState`.
- The water tower renders at its relocated authoritative tile `(15, 13)`.
- No road cell has a dead-end mask or a renderer-invented continuation.
- Observed road masks are exactly `3, 5, 6, 9, 10, 11, 12, 14`.
- Every road cell resolves its generated-v4 mask asset and excludes the terrain
  hit surface.
- The occupied bounds height is `206.7188`; cold-launch framing produces
  occupancy `0.7473417932` at default and `0.5600000271` at compact.
- City hall remains an exact mask-11 road reference across city,
  neighborhood, and block LOD.
- The rejected monolithic golden plate is ineligible for this state.
- The spatial-focus fixture at `(13, 11)` verifies exact utility, pollution,
  and vitality recovery dimensions without seed-specific production logic.

## Uncropped staged proof

| Evidence | Window/content | SHA-256 |
|---|---:|---|
| `comparison-b/fresh-start-default.png` | 1276 x 768 window | `399c046f14aba80a3a3a827f89c1d7f1242b824981b22caef78b92ef55197257` |
| `comparison-b/fresh-start-compact-900x600.png` | 900 x 652 window; exact 900 x 600 content | `08e5407937718472f4c9610126648b41b8d757c9ad03364b1fd1eaf0c07e3b10` |

Accessibility inspection identified the exact candidate, New Arcadia, the City
map, no selected block, and the paused state. Both frames show the same
authoritative two-block topology and eight occupied lots.

## Validation

- Focused `WorldRenderingTests`: 41/41 passed in 13.216 seconds.
- Full combined native suite: 199/199 passed in 93.736 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed for exact staged commit
  `a1e589e`.
- Cold diagnostics: 3.516 ms world update, 4.785 ms total, zero decode loads.
- Default: 1,357 nodes / 549 drawables.
- Compact: 1,333 nodes / 525 drawables.
- Unchanged-pulse soak remained stable with two bounded actions.
- The exact bundled interpreter
  `/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
  imported Pillow 12.2.0; no dependency was installed or changed.
- Source/staged generated-v4 validation passed 84 payload, 84 extrusion, 974
  packed-overlap, 133 source-inventory, digest, LOD, fallback, and residency
  checks with zero failures.
- Production geometry validation passed 324 reciprocal-ground, 36 setback,
  and 256 prop-exclusion checks with zero collisions or failures.

Validator reports:

- `comparison-b/world-asset-pack.json`
- `comparison-b/production-geometry.json`

The complete packet is bound by `SHA256SUMS`.
