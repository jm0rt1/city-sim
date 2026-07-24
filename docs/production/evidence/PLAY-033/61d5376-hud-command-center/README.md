# PLAY-033 HUD Command Center Evidence

- **Accepted baseline:** `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Product checkpoints:** `49e54c51f603f68f2ec469bab45ebe993823b267`, `61d5376c86b2c88399b4b24884818dc680cf2c08`
- **Candidate:** `ui-input-wdbeadac6e0bd`
- **Bundle identifier:** `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- **Staged bundle:** `dist/CitySim-ui-input-wdbeadac6e0bd.app`
- **Staged manifest:** `dist/manifests/ui-input-wdbeadac6e0bd.manifest`
- **Executable SHA-256:** `45390208819d389cd9e1ee47124c6f7f7a465a94f2d148e72fef806f9659cc22`
- **Final fresh-default PID:** `5794`
- **Validation date:** July 23, 2026

## Outcome

The map-first HUD now presents one calm, persistent, typed city priority. The presentation reads only existing `CityAnalytics` strategy fields, including the authoritative 16-day consequence window and recorded recovery. It provides the shortest legitimate route to the existing finance, utility, and map-focused actions without adding a command, target, state field, or simulation rule.

The authoritative simulation state is visibly labeled `PAUSED` or `RUNNING Nx`. The existing active map-action presentation supplies the selected tool, coordinate, availability, and accepted rejection reason. Command search continues to route `tax`, `budget`, and `storefront` to the existing Tax Policy and Finances command.

## Before and after

| Surface | Accepted baseline | PLAY-033 result |
|---|---|---|
| Default | [`before-default-9f38efe.png`](before-default-9f38efe.png) | [`default/industrial-complication-warning-diagnosis.png`](default/industrial-complication-warning-diagnosis.png) |
| Exact compact | [`before-compact-9f38efe.png`](before-compact-9f38efe.png) | [`compact/commercial-complication-warning-diagnosis-panels.png`](compact/commercial-complication-warning-diagnosis-panels.png) |

The fresh default candidate domain exercised the app's authored default window request. The exact compact launch used `CITYSIM_COMPACT_WINDOW=1`, producing 900 x 600 content; retained window captures are 900 x 652 including the title bar.

## Frozen story matrix

Each fixture was loaded through the production quick-load/store route in both the fresh default window and exact compact. The paired PNG and `-ax.txt` files are retained under `default/` and `compact/`.

| Strategy | Moment | Authoritative HUD result |
|---|---|---|
| Commercial | opening | `OPPORTUNITY · 16 DAYS` — Commercial stewardship |
| Commercial | complication | `DECISION · 16 DAYS` — Protect local storefronts |
| Commercial | recovery | `REVIEW · 16 DAYS` — Tax relief locked in |
| Commercial | victory | Existing Town Charter victory surface |
| Industrial | opening | `OPPORTUNITY · 16 DAYS` — Industrial expansion |
| Industrial | complication | `DECISION · 16 DAYS` — Prepare for the load surge |
| Industrial | recovery | `REVIEW · 16 DAYS` — Utility expansion locked in |
| Industrial | victory | Existing Town Charter victory surface |

The focused presentation test also changes message prose while holding analytics constant; the displayed countdown remains unchanged.

## Exact compact arbitration

The exact 900 x 600 commercial-complication journey opened Objectives and Command Center together:

- Objectives collapsed to its compact summary.
- Command Center details remained visibly scrollable, with the Tax Policy control reachable.
- The selected tile and critical action remained exposed.
- The measured interactive map aperture remained `246 / 600 = 41%`, above the required 40%.
- No panel overlapped or pushed the map into an unusable strip.

Evidence: [`compact/commercial-complication-warning-diagnosis-panels.png`](compact/commercial-complication-warning-diagnosis-panels.png) and [`compact/commercial-complication-warning-diagnosis-panels-ax.txt`](compact/commercial-complication-warning-diagnosis-panels-ax.txt).

## Interaction and accessibility journeys

### Warning to diagnosis to action

- Default Industrial complication: the visible `Utility capacity` action opened Utilities with Build power, Build water, Utility map, and reserve values reachable.
- Compact Commercial complication: the visible diagnosis action opened Finances while Objectives remained operable.
- Compact Act menu: `Build a park` selected the existing Park tool and restored map focus.

### Command search

- `tax`, `budget`, and `storefront` are covered by catalog collision/equivalence tests.
- Default live `tax` and compact live `storefront` each produced one available `Open Tax Policy and Finances` result.
- Return activated the same catalog/store intent, closed the guide, opened Finances, and restored map focus.

Evidence: `default/command-search-tax*` and `compact/command-search-storefront*`.

### Durable placement recovery

In both layouts, Commercial was selected and keyboard movement targeted occupied Road block 14,13. Return produced the accepted reason:

> Demolish the existing structure before building here. Commercial remains selected — choose another block.

After 4.5 seconds, the message, selected tool, coordinate, store-owned availability, and map action were still exposed. No alternate target or renderer validation was introduced.

Evidence: `default/rejected-placement-after-4s*` and `compact/rejected-placement-after-4s*`.

### Focus, Escape, FKA, and AX

- Escape closed Command Center before Objectives and preserved tool/selection.
- Final Escape focus returned to `City map`.
- Tab from the map reached `hud.city.identity`; Shift-Tab returned to the map in both layouts.
- The map, city priority, selected context, search field/result, rejection, Tax Policy slider, and map action exposed critical label/value/help/action semantics.
- Compact AX action `Build Park at block 15,14` reduced treasury exactly once from `$25,770` to `$24,870`; the resulting Park made a duplicate action unavailable.
- Pointer, Return, command search, and AX all use the existing store/catalog/map-action paths.

Evidence: `default/fka-tab-loop-ax.txt`, `compact/fka-tab-loop-ax.txt`, `compact/focus-escape-sequence-ax.txt`, and `compact/ax-build-park-once*`.

Full Keyboard Access-critical behavior and VoiceOver-critical accessibility semantics were inspected in the live accessibility tree. Spoken VoiceOver audio was not recorded.

## Automated and staged validation

- Focused strategy presentation and routing tests: 4 passed, 0 failed.
- Focused command catalog suite: 34 passed, 0 failed.
- Final native suite: 189 passed, 0 failed.
- Exact default and compact strategy render tests passed.
- Compact precedence asserts the 72-point details cap, 112-point priority cap, and 41% interactive-map measurement.
- Existing pause/resume, topmost Escape, search availability, durable rejection, active target, focus-generation, save/session, and renderer suites remained green.
- `git diff --check` passed.
- `bash -n script/build_and_run.sh` passed.
- `./script/build_and_run.sh --verify` staged and launched the exact product commit shown above.

## Ownership and compatibility

- No simulation, gameplay, save-schema, renderer, asset, or platform source changed.
- No `CityCommandID`, shared store contract, or second active coordinate was added.
- Strategy is never inferred from message prose, tick count, or tile count.
- PLAY-013 analytics, PLAY-047 story state, PLAY-034 active-target truth, existing catalog/store intents, and existing focus/modal policy remain authoritative.
