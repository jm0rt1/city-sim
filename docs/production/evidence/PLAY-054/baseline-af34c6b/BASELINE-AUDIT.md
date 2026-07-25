# PLAY-054 Baseline Audit

Date: 2026-07-25

This packet freezes the unmodified integration authority before PLAY-054
product work. It is evidence of the starting condition, not an acceptance
result.

## Exact candidate

- Source: `af34c6b051439f5a30c95729b1614f1a1e60b0e6`
- Branch: `codex/citysim-ui-input`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged executable SHA-256:
  `d4b2588a82154ce9da7eb76bcb09cb7381989f3702c2dbeff4126456e9c0bff5`
- Staging manifest SHA-256:
  `bb20542327e1d31933c0adc6c5ae6a2730fc99cfebc2d0ccd55e1b882c40db95`
- Compact PID: `91081`
- Exact compact process:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app/Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- Compact launch environment: `CITYSIM_COMPACT_WINDOW=1`

The manifest, bundle, process, screenshot, and AX tree all resolve to the lane
candidate above.

## Frozen city state

Every frame uses the exact committed
`story-industrial-complication-v1.json` bytes as `quicksave.json`:

- fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- Day 33 / tick 128 / `.playing`, loaded paused;
- strategy: Industrial complication;
- treasury: `$34,037`;
- net: `+$93 / cycle`;
- utility reserve: `P 9 / W 14`;
- active priority: `Prepare for the load surge`;
- urgency: `DECISION · 16 DAYS`;
- notices: `12`.

This is the same authored state in regular and compact captures. The loaded
pause is existing store truth.

## Original frames

| Frame | Original capture | State |
|---|---:|---|
| `before-default-color.png` | 1,278 × 768 | Regular proof window, deck closed |
| `before-compact-closed-color.png` | 900 × 652 | Exact 900 × 600 content plus 52-point titlebar, deck closed |
| `before-compact-overview-color.png` | 900 × 652 | Exact compact content, Overview open |
| `before-compact-journal-color.png` | 900 × 652 | Exact compact content, Journal open |

The `*-grayscale.jpg` files are ColorSync conversions of the corresponding
original captures. They are contrast-review derivatives only; geometry is
unchanged.

## Measured aperture

Measurements use original screenshot pixels and the opaque HUD/deck edges.
The compact content coordinate begins below the 52-point titlebar.

| Route | Map top | Map bottom | Visible interactive height | Compact content share |
|---|---:|---:|---:|---:|
| Compact closed | `187` | `535` | `348` | `58.0%` |
| Compact Overview open | `187` | `497` | `310` | `51.7%` |
| Compact Journal open | `187` | `497` | `310` | `51.7%` |

The regular closed frame exposes 453 vertical screenshot pixels between the
top command surface and bottom deck. Its issue is not aperture; the wide
1,278-point surface stretches 7–9 point labels across a visually weak strip.

## Reproduced defect

The compact Overview and Journal are data-complete in the accessibility tree
but visually incomplete:

- Overview AX includes city identity, city health, current objective,
  operating position, and `Open journal`. The screenshot shows the Overview
  header and only clipped card rims; there is no complete actionable section.
- Journal AX includes seven grouped notice summaries plus Related data,
  Act, and Dismiss routes. The screenshot shows only the top fragments of four
  cards; there is no complete notice summary.
- The accessibility exposure proves this is not missing analytics, store, or
  command data. The current `66`-point compact details cap clips rendered
  content while leaving it discoverable through AX.

## Before-frame SHA-256

- default color:
  `8959eb85b40e850a959a33559546f3de84b54db19dcf3d930f019b4038fa3b9e`
- default grayscale:
  `efabd5d2ed73ece18065e91d01ce1da4a71dea91f52680fcdaa1c8b9bb572f5f`
- compact closed color:
  `000db1dcbcb5b2bdb7ac21677029d870d250cffe48c3e8bf57fcdddeccaabf50`
- compact closed grayscale:
  `5b049dee5997e63e03b5528133118160d30c7d98c4dd73c8572c9215beea596d`
- compact Overview color:
  `59c3ef50c8592ae242835d11e2cb0a0f52ce344d77eb78b497da582434a92138`
- compact Overview grayscale:
  `af69f47bdbe827415e5403a6f16ad73fbd6407ed905f1a33390c9ae029df591b`
- compact Journal color:
  `98967405da2e285badfe098989634c76d6e1568a0086b9d37825f1fde7d440d5`
- compact Journal grayscale:
  `bc154dd00113f8d2fa020fa4694f3c74e89930f6165f1d2250f93b2c5b7ef413`

## AX artifacts

The four `*.ax.txt` files are complete Computer Use accessibility snapshots,
not manually reconstructed summaries. In particular:

- `before-compact-overview.ax.txt` retains `CURRENT OBJECTIVE`,
  `OPERATING POSITION`, and `Open journal`;
- `before-compact-journal.ax.txt` retains all notice descriptions and actions
  even though their visual cards are clipped.
