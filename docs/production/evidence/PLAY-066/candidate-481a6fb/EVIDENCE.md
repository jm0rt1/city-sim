# PLAY-066 exact-candidate evidence

- Product candidate:
  `481a6fbf09b8a31dff85941b3b9ebce0ca11715d`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle ID:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged executable SHA-256:
  `e5190f22bc4be130b8fa986ffb64e3ceeb8c24c9c364a72b6dae560055b23076`
- Generated-v4 source/staged manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`
- Isolated Day-53 primary/backup save SHA-256:
  `952d70cb80068880896acc0c7e27ec4683b4cfd3497b5c4cc171bead1eb56f53`
- State: Day 53, paused, treasury `$26,233`, residents `352`.
- Active selection: Industrial block `15,12`.
- Disposition: author evidence complete; independent PLAY-068 review remains
  required. This record does not self-score or self-accept the candidate.

## Binding live routes

Each binding LOD frame came from a separate process of the exact staged
executable, the same isolated Day-53 save root, and an accepted debug-only
deterministic camera hook. The app was loaded with Command-O, the Industrial
lot at `15,12` was selected by pointer, transient load feedback was allowed to
expire, Details was closed, and the full AX tree was retained.

| Window | Visual detail | Environment camera scale | Binding image |
|---|---|---:|---|
| regular | city | `0.85` | `live/accepted/regular-city.jpeg` |
| regular | neighborhood | `0.65` | `live/accepted/regular-neighborhood.jpeg` |
| regular | block | `0.50` | `live/accepted/regular-block.jpeg` |
| compact | city | `0.576345682144165` | `live/accepted/compact-decorated/city.jpeg` |
| compact | neighborhood | `0.52` | `live/accepted/compact-decorated/neighborhood.jpeg` |
| compact | block | `0.45` | `live/accepted/compact-decorated/block.jpeg` |

Regular images are uncropped `1278×768` windows. Compact evidence retains the
uncropped `900×652` decorated windows plus exact `900×600` content crops under
`live/accepted/compact-content/`. The compact crops remove only the 52-pixel
macOS title bar; no world or HUD pixels are hidden.

All six AX trees independently contain both:

- `Day 53. Paused`
- `Selected Industrial, block 15, 12`

The regular and compact city, neighborhood, and block images have distinct
SHA-256 values and visibly distinct map scale/material detail. Public-realm,
lot-context, and typed ambient-life work remains visible around the
representative district without covering the selected factory, its entrance,
or the connected road.

## Same-state comparison

The accepted pre-product Day-53 baseline remains at
`docs/production/evidence/PLAY-066/baseline-0ed9f3a/`. The candidate uses the
same authored save identity and selection truth. The binding candidate frames
must be compared only with the baseline's corresponding regular/compact and
city/neighborhood/block frames.

The earlier Day-51 and ambiguous shortcut captures are retained only in
`live/excluded/`. They are not cited as same-state or LOD evidence.

## Keyboard route exercised

A real focused-map route exercised `0`, then `-`, then `-` again while the
Day-53 Industrial selection remained active. It verified that the renderer
accepted the map-focus command path and preserved selection. Those screenshots
were not used to label the six LOD images because key delivery and the
window-specific city cap made their resolved camera class ambiguous. The
binding comparison instead uses the accepted deterministic camera-scale hook
above.

## Visual result

The exact candidate retains the authored park, non-grid vegetation, organic
low-profile meadow/shrub identities, sidewalk-safe furniture, lamps, frontage
and lot-context dressing, and the existing coherent road/building system.
Typed local activity is nil/zero suppressible, bounded, deterministic,
LOD-aware, and Reduce Motion safe. The final `481a6fb` repair derives the
current bounded activity selection on every render and rebuilds nodes only
when the visible qualitative signature or context changes.

Image files and AX trees are bound by `SHA256SUMS`.
