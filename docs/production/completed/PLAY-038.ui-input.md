# PLAY-038 Completion — Make Town Charter Victory Decisive and Replayable

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Authority:** `ab722bd1ea7c8c132525362bc94bc12d154a78f5`
- **Merge checkpoint:** `41d19f14aeef440f3dd860fec30690f92dcff3cb`
- **Product commits:**
  - `be41d601389f96b6ab514dc45a16452e087da728` — `PLAY-038: Make Charter victory replayable`
  - `05428228a690d7769e5a633462fbd6efebfd7eca` — `PLAY-038: Polish Charter victory narration`
  - `8779b8b00ed143c06dfa95f740ca8e3cc8b112ff` — `PLAY-038: Return replay focus to the map`
  - `edc98d762decebab3c8c43a79a93bc47f26ca74a` — `PLAY-038: Contain replay focus traversal`

## Outcome

The existing `.won` state now presents a blocking, Charter-accurate result instead of claiming the player built a metropolis. It consumes existing authoritative analytics to show the city metrics, committed strategy, and one of the four existing recovery resolutions. The result is responsive at the normal default size and exact 900 x 600 content, with scrollable evidence and a fixed, reachable action footer.

Start a New Region uses only the existing `CityCommandID.newRegion` and `CityGameStore.perform` route. Pointer, Return, Space, and accessibility Press each execute one transition. The store resets the authored city once, restores 1x, publishes one feedback message, and advances its existing map-focus generation so focus cannot fall through to an arbitrary HUD control.

The terminal state is paused and accepts only the existing New Region, Save, and Load routes. Underlying game surfaces are hidden from pointer hit testing and accessibility. Escape retains the terminal result and restores primary focus; gameplay, renderer, speed, panel, command-guide, and map routes remain inert. The two result actions share one explicit focus model, keeping forward and reverse Full Keyboard Access traversal inside the modal.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/GameStatusOverlay.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameStatusOverlayTests.swift`
- `docs/production/evidence/PLAY-038/edc98d7/*`

No command ID, catalog inventory, simulation rule, progression state, save schema, renderer surface, spatial target, PLAY-034, or CONTRACT-008 implementation changed.

## Automated validation

- `GameStatusOverlayTests`: 6 tests passed, 0 failures on final product code.
  - all four existing strategy/recovery outcomes map to truthful Charter copy;
  - terminal command quarantine and the existing replay route;
  - underlying game-surface suppression;
  - default and exact compact rendering;
  - won save/load exactness and paused state;
  - deterministic won fixture exporter for staged proof.
- `CityCommandCatalogTests`: 26 tests passed, 0 failures on the first product checkpoint.
- Full native suite on the pre-FKA final checkpoint: 150 tests passed, 0 failures in 401.916 seconds.
- Full native suite on exact final product commit `edc98d7`: 150 tests passed, 0 failures in 391.451 seconds.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed at both default and `CITYSIM_COMPACT_WINDOW=1`.

## Staged proof

The exact candidate identity, executable and fixture hashes, complete default/compact journeys, AX snapshots, FKA traversal, containment checks, and screenshots are retained in `docs/production/evidence/PLAY-038/edc98d7/README.md`.

- Default frame: 1,229 x 768 on the proof display.
- Explicit compact frame: 900 x 652 for exact 900 x 600 content.
- Pointer, Return, Space, and accessibility Press each produced one Day 1 fresh region and map focus.
- Escape, Command+/, and speed input left the result, metrics, and primary focus intact.
- The terminal AX tree exposed only the result and its two actions from the game surface.
- With `AppleKeyboardUIMode = 2`, Tab reached Load Quicksave, Shift-Tab returned to Start a New Region, and Space invoked the focused action.

AX inspection and Full Keyboard Access were exercised separately from spoken VoiceOver; spoken VoiceOver is not claimed. The claim explicitly permits deterministic won fixtures. Final live reachability from a naturally completed frozen PLAY-015 candidate remains for integration/playtest acceptance.

## Contract and compatibility notes

- **One intent path:** replay is the existing catalog/store `newRegion` intent; there is no new command or duplicate state.
- **Authoritative truth:** story presentation reads `.won`, current city metrics, committed strategy, and recovery resolution only.
- **Modal authority:** terminal containment derives from existing store state and command policy; no second gameplay truth or renderer guard was introduced.
- **Save/session:** won fixture save/load stayed exact and paused; the full deterministic, persistence, fingerprint, strategy, spatial, renderer, and soak suites remained green.

No shared-contract proposal is required. No push or integration was performed.
