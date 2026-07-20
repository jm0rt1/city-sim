# PLAY-022 Wave 003 Spatial Consequence Evidence

## Evidence classification

The three PNGs in this directory are deterministic shipping-renderer harness
frames produced by `WorldRenderingTests`. They render the real `CityScene`,
`LotRenderer`, and accepted `CityPresentationSnapshot` contract into an
offscreen `SKView`. They are **not** staged-window captures and do not satisfy
the independent live drawable-window gate by themselves.

Any staged-window capture added later must be named `live-window-*` and record
the exact staged candidate manifest, PID, window size, and capture method in a
separate subsection here.

## Paired authoritative fixture

All frames use seed 42 and the same 24 x 24 city. The strained state is tick 4;
the recovery state is tick 8. At focus coordinate `(10,11)`, the accepted
snapshot reports:

| Frame state | Combined utility | Pollution | Vitality |
|---|---|---|---|
| strained | severe | strained | strained |
| recovery | strained | strained | prosperous |

The recovery removes the industrial source at `(14,11)` in favor of a park,
restores 300 power and 270 water capacity, and restores the focus lot's
condition and occupancy. The two stable accepted event IDs at `(10,11)` are:

- `spatial-v1:1:408bde0e762db5b6f98c37c40bff35b384db7428019515e029357d2799ccc41b:10:11:utility:0:1`
- `spatial-v1:1:408bde0e762db5b6f98c37c40bff35b384db7428019515e029357d2799ccc41b:10:11:vitality:0:2`

## Harness frames

| File | Viewport/state | SHA-256 |
|---|---|---|
| `spatial-strained-default.png` | 1280 x 800, tick 4 strained | `eddec80803ab7f9ef242dfdd8f2012b7385b58c285ff4f7a2b4b4ed4760231a8` |
| `spatial-recovery-default.png` | 1280 x 800, tick 8 recovery with static Reduce Motion transition marks | `e2f2f1e16ace72f7f2140fa4653d4745b39127dd291e98c7def2c9558296f73d` |
| `spatial-recovery-compact.png` | 900 x 600, same tick 8 recovery | `484ce2638430f0e28ec64a189c0cfd2f6ab9cec7e38fee7db9132b1c801f8a13` |

The renderer test verifies the paired states differ, both default and compact
frames remain non-empty, the transition carries stable event IDs, and Reduce
Motion retains static non-color meaning with zero actions. Separate tests prove
event deduplication across repeated renders, undo suppression, deterministic
forward-replay suppression, and at most one retained transition root per
developed coordinate.
