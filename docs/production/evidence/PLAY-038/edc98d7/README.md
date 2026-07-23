# PLAY-038 staged evidence — `edc98d7`

## Candidate

- Authority: `ab722bd1ea7c8c132525362bc94bc12d154a78f5`
- Product commits:
  - `be41d601389f96b6ab514dc45a16452e087da728` — Charter-accurate victory and replay surface
  - `05428228a690d7769e5a633462fbd6efebfd7eca` — normalized accessibility narration
  - `8779b8b00ed143c06dfa95f740ca8e3cc8b112ff` — deterministic map-focus handoff
  - `edc98d762decebab3c8c43a79a93bc47f26ca74a` — contained Full Keyboard Access traversal
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Executable SHA-256: `974a47ef05e932708ff8d9b546bee5fd3628db90203f701ce14c985ed7831b16`
- Deterministic won quicksave SHA-256: `c54c8ba6278cdae38e34d79a31528ee2b8ad081fe448b54e51d9fd949bac1cc5`
- Genuine default frame: 1,229 x 768 on the proof display
- Explicit compact frame: 900 x 652 for exact 900 x 600 content

The deterministic won fixture uses the existing `.won` state, existing industrial strategy, existing Green Buffer recovery resolution, existing save service, and existing `.newRegion` catalog/store route. It adds no command, simulation rule, progression fact, renderer truth, or save field.

The exact final product commit passed 150 native tests with 0 failures in 391.451 seconds after the staged app was stopped.

## Charter result

The staged result says `Town Charter Secured` and `New Arcadia Earned Its Town Charter`. It reports the existing city metrics and the authoritative strategy/recovery story without calling the town a metropolis:

- Residents: 612
- Treasury: $18,750
- Cashflow: $282
- Happiness: 67%
- Strategy: Industrial Expansion
- Recovery: Green Buffer

Focused tests exercise the same presentation mapping for all four authoritative recovery outcomes: Temporary Tax Relief, Public Realm Investment, Utility Expansion, and Green Buffer.

## Default journey

Only the Charter modal, its scrollable result, Start a New Region, and Load Quicksave appeared in the game-surface AX tree. The hidden HUD, map, speed, build, panel, and toolbar actions were not exposed. Initial focus was Start a New Region.

Against exact commit `edc98d7`, each route started one authored Day 1 region, published one `A fresh region is ready` update, restored 1x, and handed focus to the semantic City map:

- pointer coordinate click;
- Return on the default action;
- Space on the focused action;
- accessibility Press on `victory.start-new-region`.

Escape kept the won result open and restored focus to Start a New Region. Escape, Command+/, and `3` did not expose the command guide, speed controls, map, or underlying HUD and did not alter the 612-resident result.

## Exact compact journey

The candidate was relaunched with `CITYSIM_COMPACT_WINDOW=1`. The 900 x 652 host frame is the required exact 900 x 600 content area. The complete Charter story remained scrollable and both actions stayed visible without off-window content.

Pointer, Return, Space, and accessibility Press again produced exactly one Day 1 region and returned focus to the map. Escape, Command+/, and `3` remained contained by the terminal surface.

With host `AppleKeyboardUIMode = 2`, initial focus was Start a New Region. Tab moved the visible focus ring to Load Quicksave; Space invoked that alternate action and retained the won result. Shift-Tab returned the ring to Start a New Region; Space then invoked one replay and returned focus to the map. This proves forward and reverse Full Keyboard Access traversal stays inside the blocking surface.

## Retained captures

- `default-charter-victory-1229x768.png` — genuine default result and focused replay CTA.
- `compact-charter-victory-900x652-frame.png` — exact 900 x 600 content with both actions reachable.
- `compact-fka-load-quicksave.png` — Tab focus on the alternate Load Quicksave action.
- `compact-fka-start-new-region.png` — Shift-Tab focus returned to the primary replay action.
- `default-ax.txt` and `compact-ax.txt` — critical AX identity, value, actions, focus, and hidden-surface assertions.
- `SHA256SUMS` — candidate executable, won fixture, and retained capture digests.

AX labels, values, help, focus, enabled state, and accessibility Press were inspected separately from spoken VoiceOver. Spoken VoiceOver is not claimed. Final live reachability from a naturally completed frozen PLAY-015 candidate remains the integration/playtest acceptance step authorized by the claim.
