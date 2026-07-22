# PLAY-033 staged evidence — `dd878b2`

## Candidate identity

- Product commit: `dd878b232be003fffa653185d69872ac4d4a27a4`
- Branch: `codex/citysim-ui-input`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier and preference domain: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged bundle: `dist/CitySim-ui-input-wdbeadac6e0bd.app`
- Isolated data root: `dist/test-data/ui-input-wdbeadac6e0bd`
- Staged manifest: `dist/manifests/ui-input-wdbeadac6e0bd.manifest`

The manifest recorded `status=verified-running` at the exact product commit. The default run used the host-constrained 1,229 x 768 frame. The explicit `CITYSIM_COMPACT_WINDOW=1` run used exactly 900 x 600 content and produced a 900 x 652 decorated frame.

## Retained captures

- `default-paused.jpeg` — default staged city with the visible `PAUSED` state, 1,229 x 768.
- `default-tax-policy-search.jpeg` — command-guide search for `tax`, showing the available `Open Tax Policy and Finances` result, 620 x 560.
- `default-placement-rejection-after-4s.jpeg` — occupied Commercial placement four seconds after rejection; the tool remains selected and both the map and durable action feedback expose the accepted occupied-tile reason, 1,229 x 768.
- `compact-objectives-command-center.jpeg` — exact compact content with Objectives collapsed to summary, Command Center details capped and scrollable, selected Road block 14,13 visible, and the map retaining 246 / 600 points (41%) between measured HUD chrome, 900 x 652 frame / 900 x 600 content.

## Hands-on interaction and accessibility record

- Default pointer and keyboard: Space produced the visible and AX-exposed `PAUSED` state. The Commands button opened the guide with focus in `Search CitySim commands`.
- Warning-to-action: `tax`, `budget`, and `storefront` each returned one available `Open Tax Policy and Finances` route with shortcut `Option-2`. Escape closed the guide and returned focus to the City map; no search text leaked into gameplay shortcuts.
- Placement recovery: `C` selected Commercial. Clicking an occupied structure produced `Action blocked` with `Demolish the existing structure before building here. Commercial remains selected — choose another block.` Build mode, Zones, and Commercial remained selected. The same feedback and tool state remained after an explicit four-second wait and could be dismissed through the existing catalog intent.
- Compact pointer and keyboard: Objectives plus Command Center collapsed Objectives to its summary and kept `Scrollable command-center details`, `City data`, `Close details`, and `Demolish Road $50` in the accessibility tree. Tab from the scroll region reached `City data`; Escape closed Command Center first and the automated priority test covers the next Objectives cancellation.
- Compact measurement: measured top chrome `(8, 9, 884, 178)` and bottom chrome `(8, 433, 884, 155)` leave `433 - 187 = 246` points of interactive map height, or 41% of the 600-point content height.
- Accessibility: changed surfaces expose stable labels, values, selected state, accepted disabled/rejection reasons, focusable search and scroll controls, and the selected map coordinate. This is an AX and Full Keyboard Access-critical semantics inspection; spoken VoiceOver was not claimed.
- Reduce Motion: the existing feedback transition still selects opacity-only animation when Reduce Motion is enabled. No new motion behavior was introduced.

## Boundaries

No PLAY-013 urgency analytics were consumed, and no countdown was inferred from tick or message prose. No simulation rule, renderer overlay truth, save schema/service, world state, or persistence architecture changed. The occupied-tile live check confirms agreement for that tested case only; it is not a general renderer placement-truth claim.
