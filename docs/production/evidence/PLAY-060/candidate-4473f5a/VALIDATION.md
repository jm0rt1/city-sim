# PLAY-060 candidate validation

## Identity

- Product commit: `4473f5a1fe827e143701fea6386299db1116ed45`
- Authority ancestor: `91f885925fd601786fa95dbb969b71fefef5ddcd`
- Accepted comparison ancestor: `64dd47500fe5e2d4a32a64f6298ded5789d3b773`
- Branch: `codex/citysim-world-rendering`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle identifier: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged executable SHA-256: `c3203904afbaf08414315735c8fa314ca9e9a7d1fa728f2b5f1a66a5e2f50485`
- Staging manifest SHA-256: `31b8046de769b61aa225be0f12ecf632957ab11b09f6aea50c1a5d2d11ac0f45`
- Source and staged generated-v4 manifest SHA-256: `c9351451928e035c0631b074d38fc55156325e5fcd19d3ebd4b104c5f90d8aa8`

`candidate.manifest` retains the exact bundle, executable, resource-bundle, preference-domain, and data-root identity produced by `./script/build_and_run.sh --verify`.

## Catalog and deterministic pack

- Exact Commercial identities: 16 (`L1...L4 × north/east/south/west`)
- Unique accepted raw-source hashes: 16
- Unique normalized hashes: 48 (`16 × city/neighborhood/block`)
- Cross-family Commercial/Residential source-hash overlap: zero
- Runtime mirror, rotation, sibling alias, and cross-family fallback paths: zero
- Commercial production fallback count: zero
- Two clean pack outputs:
  - `/private/tmp/play060-pack-a.II4rzO`
  - `/private/tmp/play060-pack-b.D7xGS5`
- `diff -qr` across the two clean outputs: no differences
- Canonical source atlas and staged resource atlas parity: true

Generated pages remain within the four-page ceiling:

| Page | SHA-256 | Decoded bytes |
|---|---|---:|
| `block-00` | `90aeb2c8e56bfc95d8279581ebee60f3dc692e45407aff4e364a0ba087bbff1a` | 33,554,432 |
| `block-01` | `190f1b9e37b33d5c8cfce5bf7d3f91c58283b70bf54d26b190c8585e4d3decce` | included in block total |
| `city-00` | `0510dad5ae9d6ce786edf84217eacc6bf23932eb9ca50246afc559136d5d912f` | 4,194,304 |
| `neighborhood-00` | `0efaa934b3b58bee17b1dd0b5c6d5fdf02cd0512eb6e718c7018606697ca2cc9` | 8,388,608 |

The full pack validator is retained at `diagnostics/asset-pack-validation.json`. It passed 180 payload digests, 180 extrusion checks, 4,411 packed-overlap checks, source/staged parity, and all directional inventory assertions.

The physical geometry validator is retained at `diagnostics/production-geometry-validation.json`. It reports `result: pass`, 44 registered logical assets, 6,724 reciprocal-ground checks with zero collisions, 164 building-road setback checks with zero collisions, and 628 entrance/prop neighbor-exclusion checks with zero collisions.

## Native and staged validation

- Focused `WorldRenderingTests`: 52/52 passed in 27.304 seconds; retained log: `diagnostics/world-rendering-tests.log`
- Full native suite: 223/223 passed in 108.014 seconds; retained log: `diagnostics/full-native-tests.log`
- `bash -n script/build_and_run.sh`: passed
- `./script/build_and_run.sh --verify`: passed
- Exact staged generated-v4 bundle load: passed from `CitySimNative_CitySimNative.bundle`, not a build-directory atlas

Focused identity coverage proves:

- all 16 level/direction identities select the exact manifest logical ID;
- the selected asset level equals authoritative `CityTile.level`;
- the entrance socket and frontage edge equal the actual adjacent-road direction;
- all three LODs retain the same identity;
- unchanged pulse, JSON save/load, mutation, and undo preserve or restore the exact identity;
- roadless Commercial selection fails explicitly rather than choosing a visual fallback.

## Rendering and residency

Latest full-suite governed renderer diagnostics:

- cold backdrop: 0.156 ms
- preparation: 0.010 ms
- tile build: 3.573 ms
- tree metrics: 0.185 ms
- world update: 3.741 ms
- asset decode loads: 0
- asset decode: 0.000 ms
- cold total: 5.355 ms
- default nodes/drawables: 1,407 / 594
- exact-compact nodes/drawables: 1,383 / 570
- unchanged-pulse soak: 4,286 pulses, 1,407 nodes, 594 drawables, 2 actions, 0.0006 ms average
- generated-v4 repeated-LOD high-water: 41,943,040 decoded bytes
- generated-v4 fallbacks: 0

Hands-on staged RSS:

- regular after three LOD cycles: 62,528 KiB
- exact compact after three LOD cycles: 201,696 KiB
- exact compact Reduce Motion: 275,136 KiB

All are below the established 333.8 MiB settled ceiling. The higher Reduce Motion snapshot was taken shortly after its isolated launch and resource load; it still remains under the ceiling.

## Visual and interaction proof

The production 4×4 matrix is candidate-rendered from the exact runtime catalog:

- pre-ingestion baseline: `matrix/commercial-pre-ingestion-4x4.png`
- PLAY-060 production: `matrix/commercial-production-4x4.png`
- grayscale: `matrix/commercial-production-4x4-grayscale.png`

The production matrix materially distinguishes L1, L2, L3, and L4 massing and shows authored north/east/south/west frontage without runtime transforms. Its SHA-256 is `e74430399d8095d7c10d538f2ffefd4e4ba7bdb3c725bf01b5b822046271c1a6`.

The uncropped staged app packet proves:

- regular and exact 900×600 compact content layouts;
- city, neighborhood, and block camera states with distinct hashes;
- pointer-selected Commercial identity at displayed block 14,12;
- keyboard movement to road 13,12 and return to Commercial 14,12;
- AX identity `Commercial Level 1 Operational`;
- authoritative south-road frontage for underlying state coordinate 13,11;
- invalid occupied-lot reason, valid placement availability, construction at 0%, Return commit, and Undo;
- Save followed by Load with Day 10/Day 33 paused truth intact;
- static Reduce Motion meaning in the exact staged app.

Regular clean City SHA-256: `e584db3731e91c4d5d2249934f1ef2c564e1c716b5e190e55ca64a4b8b4e3672`.

Compact clean City SHA-256: `6f56e119602567f26063a49842358e5d615f50e8ad6b800782e2e16a5e9b393e`.

The accepted park, terrain, street furniture, vegetation, overlays, and Focus City composition from `64dd475` remain visually present. No public-realm or HUD surface changed in the product diff.

## Honest limitation

The committed production story corpus currently contains Commercial lots only at L1. The staged app therefore proves real authoritative L1 selection/frontage and the complete interaction lifecycle. L1→L4 and all four authored directions are proved by the exact candidate runtime 4×4 matrix plus exhaustive all-LOD tests, not by a fabricated gameplay save. Independent PLAY-061 review should retain this distinction.
