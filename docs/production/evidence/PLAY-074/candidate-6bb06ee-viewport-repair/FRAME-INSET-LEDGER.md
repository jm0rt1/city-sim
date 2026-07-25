# PLAY-074 Viewport Frame and Inset Ledger

All compact captures use a 900 x 652 decorated window with an exact
900 x 600 content area. Measurements are candidate-bound and use the frozen
Day-33 fixture. Screenshot-edge readings may vary by one pixel.

## Compact

| State | Actual bottom chrome frame in content | Visible map height | Published top / bottom inset | Renderer-safe height |
|---|---:|---:|---:|---:|
| Closed | y 528...592, 64 pt | 416 px | 122 / 82 pt | 396 pt |
| Active build decision | y 474...592, 118 pt | 362 px | 122 / 136 pt | 342 pt |
| Details open | y 416...592, 176 pt | 304 px | 122 / 194 pt | 284 pt |
| Post-close settlement | y 528...592, 64 pt | 416 px | 122 / 82 pt | 396 pt |

Before the repair, the visually closed surface continued to publish the
legacy 136 / 116 pt fallback floors, yielding only 348 pt of renderer-safe
height. The repaired closed state publishes the real settled geometry and
restores 48 pt of safe world aperture. Active-decision and Details states also
publish their distinct real frames rather than sharing stale outgoing chrome.

## Regular

| State | Visible screenshot map height | Deterministic content output |
|---|---:|---:|
| Closed | approximately 506 px | 554 pt |
| Active build decision | approximately 463 px | 510 pt |
| Details open | approximately 364 px | 410 pt |
| Post-close settlement | approximately 506 px | 554 pt |

The deterministic regular outputs use top inset 144 pt and bottom insets
90 / 134 / 234 / 90 pt respectively.

## Target and transition continuity

- Residential remained selected on occupied City Hall block 12,12 with the
  accepted unavailable reason.
- Opening Details retained the selected parcel and visible active-target
  highlight.
- Closing Details restored the active build decision and the same block 12,12.
- Entering and exiting Focus City retained the measured pre-focus insets,
  target, and pixel-aligned city geometry until the restored bottom chrome
  reported its settled frame.

Binding frames:

- `before-compact/`: accepted return-base compact states.
- `compact/`: repaired closed, active-decision, Details, post-close, selected,
  Focus City, and focus-restoration states.
- `regular/`: repaired closed, active-decision, Details, and post-close states.
