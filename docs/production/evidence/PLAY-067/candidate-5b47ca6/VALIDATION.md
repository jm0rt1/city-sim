# PLAY-067 Candidate Validation

## Player-visible result

The closed command layer now reads as one situational strip around the city:
current objective, authoritative priority/urgency, projected treasury
trajectory, selected target, mode, and the existing legitimate action route
are visible without opening a panel. Regular layouts use their width for the
complete priority explanation and build categories. Compact keeps the same
truth in a shorter, calmer hierarchy.

Details is progressive disclosure. The selected target remains in the command
row; the first card is the existing next action, followed by identity and
diagnostic context. No gameplay rule, target, camera, command, or validation
was copied into the view.

## Exact aperture

Measurements use opaque HUD/deck edges on the original candidate pixels.
Regular values are visible-pixel measurements. Compact percentages use the
exact 600-point content height.

| Route | Frame | Visible map height | Compact content share |
|---|---:|---:|---:|
| Regular closed | 1278 x 768 | 507 px | n/a |
| Regular Details | 1278 x 768 | 363 px | n/a |
| Regular Focus City | 1278 x 768 | 634 px | n/a |
| Compact closed | 900 x 652 | 415 / 600 | 69.2% |
| Compact Details | 900 x 652 | 304 / 600 | 50.7% |
| Compact Focus City | 900 x 652 | 495 / 600 | 82.5% |

The binding compact candidate exceeds the claim floors in closed and Details
states and visibly retains the active city target. The prior inherited-window
attempt is segregated and excluded rather than relabeled.

## Live interaction and accessibility

- Real pointer opened Details in regular and compact layouts; Road block 13,12
  and the same map action remained authoritative.
- Escape closed Details first, retained Inspect and Road block 13,12, and
  returned semantic focus to the City map.
- Real pointer entered and exited Focus City in regular and compact layouts;
  target/action and map focus remained unchanged.
- `Shift-Command-F` entered Focus City and Escape exited it with the same
  target and map focus.
- `Command-/` opened the searchable command guide. Query `tax` exposed
  `Open Tax Policy and Finances`; Return opened the existing Finances/Tax
  Policy surface. Escape closed it without cancelling the selected target.
- Full Keyboard Access-critical Tab traversal moved from the semantic City map
  to `hud.city.identity`; no hidden or duplicate action appeared.
- Binding AX trees expose `hud.strategy.priority`,
  `hud.city.trajectory` with `Losing $82 per cycle`,
  `hud.selected.context`, the Details open/closed state, semantic City map
  primary/secondary actions, warning notice count/severity in Focus City, and
  Road block 13,12 throughout.
- Compact proof ran with `CITYSIM_REDUCE_MOTION_PROOF=1`; composition, command
  routes, focus, and AX semantics remained intact.

Pointer and keyboard activation continue to use the existing typed
catalog/store routes. The implementation adds no command and changes no menu,
guide, shortcut, modal/text quarantine, camera, or map-input contract.

## Automated validation

- Focused layout/catalog tests: 3 tests, 0 failures.
- Complete native suite at product commit: **226 tests, 0 failures,
  119.396 seconds**.
- `git diff --check`: passed.
- Repository shell syntax (`bash -n`): passed.
- Exact `./script/build_and_run.sh --stage-only`: passed and produced the
  manifest/executable bound in `CANDIDATE-MANIFEST.md`.

## Known limitations

- Aperture values are manual measurements on retained original pixels,
  corroborated by the focused layout tests.
- Live AX hierarchy and Full Keyboard Access-critical traversal were retained;
  spoken VoiceOver audio was not recorded or claimed.
- The rejected inherited-window captures are retained for auditability but are
  explicitly non-binding.
- PLAY-068 and integration own independent acceptance. This lane does not
  self-score or self-accept.
