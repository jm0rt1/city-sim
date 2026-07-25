# PLAY-057 Focus City Baseline Audit

Date: 2026-07-25

This packet freezes the unmodified PLAY-057 authority before product work. It
records the exact same-state command surface and map aperture; it is not an
acceptance result.

## Candidate identity

- Branch: `codex/citysim-ui-input`
- Commit: `22f6d7c6422d88ad0c3ef2fc95eb70050e575cec`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged executable SHA-256:
  `f0796c05dea63d50f5b3587defecfcd2bdac701726fc04647a2254a73f50ee89`
- Regular proof PID: `99869`
- Regular launch: `CITYSIM_REGULAR_WINDOW=1`
- Compact proof PID: `97367`
- Compact launch: `CITYSIM_COMPACT_WINDOW=1`

The retained staging manifest is the exact regular proof manifest. Both
processes resolved to the same staged bundle and executable.

## Frozen city state

Every scored frame loaded the committed
`story-industrial-complication-v1.json` fixture as the isolated candidate
quicksave:

- fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- Day 33 / tick 128, loaded paused;
- treasury `$34,037`, net `+$93 / cycle`;
- utility reserve `P 9 / W 14`;
- active priority `Prepare for the load surge`;
- urgency `DECISION · 16 DAYS`;
- 12 notices.

The command deck was captured closed and with Overview Details open. Focus
City does not exist in this authority, so no baseline Focus City frame can be
scored.

## Frames and measured aperture

Measurements use the original screenshot pixels and the opaque HUD/deck
edges. Exact compact includes a 52-point titlebar above the 900 x 600 content.

| Route | Frame | Visible map height | Compact content share |
|---|---:|---:|---:|
| Compact closed | 900 x 652 | 361 / 600 | 60.2% |
| Compact Details | 900 x 652 | 271 / 600 | 45.2% |
| Regular closed | 1,278 x 768 | 448 visible pixels | n/a |
| Regular Details | 1,278 x 768 | 318 visible pixels | n/a |

The regular frame is the repository's deterministic regular-proof size. Its
visible-pixel measurements are retained for direct before/after comparison;
the screen capture does not contain the full 768-point content height plus
titlebar, so it is not presented as a content-share percentage.

## Current behavior

- Closed HUD retains city identity, paused/speed controls, treasury and net,
  five city metrics, the typed priority/urgency, and selected-context truth.
- Opening Details retains the same top HUD and replaces the lower operational
  row with the complete Overview panel.
- Compact closed is world-first, but there is no player command that
  temporarily collapses both control surfaces while retaining critical truth.
- The AX tree exposes the same closed/open state as the pixels and leaves the
  semantic City map focused.

## Excluded first attempt

The first nominal default launch inherited the candidate domain's prior
900 x 600 window preference. It was detected by its 900 x 652 screenshot,
excluded from regular scoring, and retained under `excluded/`. It was replaced
by the explicit `CITYSIM_REGULAR_WINDOW=1` 1,278 x 768 regular route above.

## Proof files

- `play057-before-regular-closed-22f6d7c.jpg`
- `play057-before-regular-closed-22f6d7c.ax.txt`
- `play057-before-regular-details-22f6d7c.jpg`
- `play057-before-regular-details-22f6d7c.ax.txt`
- `play057-before-compact-closed-22f6d7c.jpg`
- `play057-before-compact-closed-22f6d7c.ax.txt`
- `play057-before-compact-details-22f6d7c.jpg`
- `play057-before-compact-details-22f6d7c.ax.txt`
- `regular-staging.manifest`
