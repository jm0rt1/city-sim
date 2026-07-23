# PLAY-037 staged evidence — `5016740` + `ae85efe`

## Candidate

- Base authority: `52fc2c17643e7987f78bc360196599e3297967da`
- Map identity and Escape commit: `50167403531aa90084e95281b463c513acaf415c`
- Full Keyboard Access commit: `ae85efeedede7e0b2ccee3f8d2ae98bb8e1ae47c`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Default frame: 1,229 x 768 on the proof display
- Explicit compact frame: 900 x 652 for exact 900 x 600 content

The exact integrated baseline no longer reproduced the historical missing-map AX node or incorrect two-step Escape result when the map already held focus. It did still leave the compact map's representable identity implicit and panel dismissal did not explicitly hand focus back to the map. The first checkpoint makes `CityMapSKView` the representable's exact view type, continuously owns its map semantics, and requests map focus after each governed panel dismissal. Live Full Keyboard Access then exposed a remaining Tab trap at the SpriteKit boundary; the second checkpoint hands unmodified Tab and Shift-Tab to the native key-view loop.

## Default journey

The isolated preference domain and data root were cleared before the final product candidate launch. Welcome was the only exposed game surface; Space did not dismiss it or reveal underlying actions. Return explicitly dismissed Welcome into the authored map at Day 1 and 1x, with `City map`, `No block selected`, keyboard help, and map focus present.

After pausing, a coordinate pointer click selected a visible road and opened its Command Center details. Right and Shift-Right moved and revealed the semantic selected block. Objectives was then opened over Command Center. The first Escape closed Command Center only; the second closed Objectives. Both returned focus to the map and retained the selected block. Captures beginning `final-default-` are from the final `ae85efe` product candidate.

## Exact compact journey

The candidate was relaunched with `CITYSIM_COMPACT_WINDOW=1`. The 900 x 652 host frame is the required 900 x 600 content area. The map remained the dominant interactive surface while simultaneous Objectives and Command Center collapsed Objectives to its summary and exposed capped, scrollable diagnostic details.

- Right and Shift-Right moved the semantic map selection to block 19, 13 and kept the selection marker revealed.
- Residential remained selected; the map announced the selected Road, its unavailable build reason, and its Inspect custom action.
- Command Center exposed the selected block action `Demolish Road for $50` without changing target or simulation truth.
- Escape closed Command Center first and expanded Objectives; a second Escape closed Objectives. Tool, selection, paused state, and map focus remained intact.
- The command guide focused its search field. Typing `tax`, then Left and Shift-Right, selected the final query character without moving the map. Escape closed the guide and returned map focus to the unchanged block.

The active host setting was `AppleKeyboardUIMode = 2` (Full Keyboard Access). Starting from the focused map, Tab traversed the HUD and command deck into compact Command Center, reaching `Demolish Road for $50`; Shift-Tab returned to the preceding `City data` control. `compact-fka-selected-action.jpg` retains the final-candidate selected-action focus state.

## Retained captures

- `final-default-fresh-welcome.jpg` — final-candidate default Welcome containment.
- `final-default-pointer-keyboard.jpg` — default pointer selection followed by keyboard reveal.
- `final-default-stacked.jpg` — default Objectives and Command Center before cancellation.
- `final-default-after-two-escapes.jpg` — default map after topmost-first cancellation.
- `final-compact-stacked.jpg` — final-candidate exact compact arbitration with selected block details.
- `final-compact-after-two-escapes.jpg` — final-candidate compact map after both governed surfaces close.
- `compact-fka-selected-action.jpg` — final-candidate Full Keyboard Access focus on the selected block action.
- The remaining captures retain the first-checkpoint default/compact reproduction and comparison journey.

AX labels, values, help, enabled state, custom actions, focus, and native Full Keyboard Access traversal were inspected. Spoken VoiceOver was not exercised or claimed. No build action, demolition, save, load, tax change, or simulation rule was invoked during the proof.
