# PLAY-058 Frozen Baseline Ledger

## LOD and public-realm captures

| Viewport | Stop | SHA-256 |
|---|---|---|
| Regular | City | `75049f25b25df7c14ff4f4fa533959c7e4ee3c442c3fc22f887673e23f10a7da` |
| Regular | Neighborhood | `30cd8b2cf79594f1ae3db92fd26a66bda25a8c6d1b646e5790642a4879935fea` |
| Regular | Block | `33437c71e47861a84ddf871b0610121600a42d9e3a192187e35b7770393ae7c9` |
| Compact | City | `99d3eea55c9ca1c9ff7293f5c9aecb25adbf39c8cfd93d3856c0daa5b9def3ff` |
| Compact | Neighborhood | `0158ebf9b2284310fb70911e719577f35b6b9be09e2615731c0f9470a1270599` |
| Compact | Block | `328c43ee3a2da2b05ef960f71555143fec80b3b085a6ec269483e3393254a1a1` |

All three hashes differ within each viewport and were produced by actual
camera input, not renamed fixture frames.

## HUD aperture

Content-height measurements exclude the 52-pixel decorated title bar.

| Viewport/state | World aperture | Content share |
|---|---:|---:|
| Regular closed | 446 / 716 px | 62.3% |
| Regular Details open | 316 / 716 px | 44.1% |
| Compact closed | 360 / 600 px | 60.0% |
| Compact Details open | 270 / 600 px | 45.0% |

## Overlay truth

| Overlay | Representative baseline observation |
|---|---|
| Land Value | Legend present; insufficient localized change to read a corrective action |
| Traffic | Legend present; insufficient localized map truth |
| Utilities | Clear green/yellow building-level service marks |
| Happiness | Legend present; insufficient localized map truth |
| Pollution | Clear yellow/red building-level consequence marks |

Regular map-only PSNR versus the closed state was 47.508 dB for Land Value,
47.508 dB for Traffic, 47.508 dB for Happiness, 35.318 dB for Utilities, and
42.776 dB for Pollution. The near-identical first three values corroborate the
visible legend-only baseline weakness; the final gate remains visual and
hands-on rather than thresholding PSNR.

## Ambient and accessibility checks

- Regular paused endpoints: 0 and 20 seconds retained; only a very small
  map-region delta.
- Compact paused endpoints: 0 and 20 seconds are byte-identical.
- FKA Tab focused `hud.city.identity` in regular and compact; Shift-Tab
  returned focus to the map.
- Complete regular, compact, overlay, LOD, and Reduce Motion AX trees are
  adjacent to their PNG captures.
- No accepted AX record contains `Action update`, `Action cancelled`, or
  `City loaded`.

## Resource, geometry, and performance baseline

- Asset-pack validator: pass; 247 source entries, 4 pages, source/staged
  parity, 0 failures.
- Active-plus-next decoded bytes: City 12,582,912; Neighborhood 41,943,040;
  Block 41,943,040.
- Production geometry: 2,500 reciprocal-ground checks, 0 ground collisions,
  0 building-road collisions, 0 entrance/prop exclusion collisions, 0
  failures.
- Full native suite: 206/206, 0 failures, 100.116 seconds
  (100.131 seconds including suite wrapper).
- Rendering group inside the full suite: 47/47, 0 failures, 22.545 seconds.
- Golden renderer diagnostic: 792 nodes, 327 drawables, 0 actions, 4.464 ms
  world update, 5.894 ms total render, 0 asset decodes.
- 30-minute-equivalent soak: 4,286 pulses, 1,369 nodes, 553 drawables,
  2 actions, 0.0007 ms average diagnostic pulse.
- Runtime residency diagnostic: 3 resident textures, 41,943,040-byte
  high-water, 0 fallbacks.
- Regular live RSS across three LOD cycles: 197,984; 184,704; 190,096 KiB.
- Compact live RSS across three LOD cycles: 114,832; 221,888; 159,856 KiB.
- Compact Reduce Motion settled RSS: 177,568 KiB.

The observed live peaks remain below the frozen 333.8 MiB comparison ceiling
and fall after cycling; the candidate must not introduce continuing growth.

## Preserved infrastructure failures

- Attempt 01 retains the sandboxed stage-only failure before a successful
  elevated governed stage.
- The accepted directory retains the first sandboxed full-suite failure.
- `world-rendering-tests.log` retains a sandboxed focused-run failure; the
  independently rerun full suite supplies the successful 47/47 rendering
  result and is not represented as a successful focused invocation.
