# PLAY-033 Completion — HUD Command Center on the Beautiful World

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Accepted baseline:** `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Exact staged product candidate:** `61d5376c86b2c88399b4b24884818dc680cf2c08`
- **Evidence checkpoint:** `03b4cc663b47ea3a342a30210b39fad60d04af54`
- **Evidence root:** `docs/production/evidence/PLAY-033/61d5376-hud-command-center/`

## Player-visible outcome

CitySim's map-first HUD now carries one persistent, calm city priority driven exclusively by existing authoritative analytics. Both Main Street and Freight strategies clearly expose their opening opportunity, complication decision, accepted recovery, and completed story. The HUD shows the authoritative consequence window, gives one short diagnosis route, and offers only legitimate existing remedies.

The paused/running state is unmistakable. Selected build context names the existing active coordinate, availability, and accepted reason. Rejected placement keeps the selected tool and target actionable. Existing `tax`, `budget`, and `storefront` search vocabulary reaches Tax Policy and Finances through the one catalog/store route.

At exact 900 x 600 content, Objectives collapses to summary while Command Center details remain capped and scrollable. The measured interactive map aperture is 246 / 600 points, or 41%. The selected tile, critical action, and map remain visible without overlap or cropping.

## Ordered current-wave commits

1. `49e54c51f603f68f2ec469bab45ebe993823b267` — `PLAY-033: Surface authoritative city priorities`
2. `61d5376c86b2c88399b4b24884818dc680cf2c08` — `PLAY-033: Keep compact urgency immediately legible`
3. `03b4cc663b47ea3a342a30210b39fad60d04af54` — `PLAY-033: Retain command-center proof`

The accepted baseline already contains the earlier PLAY-033 compact arbitration, search, and rejection work. The second current-wave commit is a focused compact legibility correction discovered in the exact staged journey; no history was rewritten.

## Product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/EventFeedView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

No simulation, gameplay, save, renderer, resource, build-script, or shared-contract source changed.

## Authoritative presentation and routing

- `CityStrategyHUDPresentation` consumes only `CityAnalytics.awaitingStrategyChoice`, `committedStrategy`, `strategyPhase`, `strategyDaysUntilConsequence`, and `strategyRecoveryResolution`.
- Message prose, tile counts, and inferred ticks do not determine strategy, urgency, or countdown.
- Diagnostic actions use the existing `CityCommandID` and `CityGameStore.perform` route.
- Map remedies use the existing `performMapFocused` route and focus generation.
- Selected context consumes the existing `activeMapActionTargetPresentation`; it does not create a second target.
- Pause/running presentation reads the existing speed truth.

## Automated validation

- `testStrategyHUDConsumesEveryFrozenStoryMomentFromAuthoritativeAnalytics` covers all eight PLAY-047 frozen fixtures.
- `testStrategyHUDCountdownIgnoresMessageProseAndUrgentRoutesUseCatalogCommands` proves typed countdown and existing catalog remedies.
- `testStrategyHUDDiagnosisAndMapRemediesUseOneStoreIntentAndFocusHandoff` proves one store intent and deterministic map focus generation.
- `testStrategyCommandCenterRendersAtDefaultAndExactCompactSizes` covers both presentation sizes.
- `testMapFirstChromeDefaultsClosed` retains the compact 72-point details cap, adds the 112-point priority cap, and proves at least 40% map height plus exact PAUSED/RUNNING values.
- Existing catalog collision/equivalence, tax synonyms, command-guide availability, durable rejection, map-action coordinate, topmost Escape, modal/text quarantine, save/session, and renderer tests remain green.
- Focused strategy/routing tests: 4 passed, 0 failed.
- Focused command catalog suite: 34 passed, 0 failed.
- Final native suite: 189 passed, 0 failed.
- `git diff --check` passed.
- `bash -n script/build_and_run.sh` passed.

## Exact staged proof

`./script/build_and_run.sh --verify` staged:

- Candidate `ui-input-wdbeadac6e0bd`
- Bundle identifier `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Executable SHA-256 `45390208819d389cd9e1ee47124c6f7f7a465a94f2d148e72fef806f9659cc22`
- Product commit `61d5376c86b2c88399b4b24884818dc680cf2c08`

The candidate domain was cleared before the final default run so a preceding compact proof could not leak its persisted window frame into default evidence.

Retained evidence includes:

- Fresh default and exact compact before/after frames.
- Both strategies at opening, complication, recovery, and Charter victory in both layouts.
- Default Utility warning-to-diagnosis and compact Finance warning-to-diagnosis.
- Live `tax` and `storefront` search plus Return activation.
- Pointer Act-menu route to Park with map focus restoration.
- Default and compact occupied-target rejections still present after 4.5 seconds.
- Topmost Escape and map focus restoration.
- Default and compact FKA Tab/Shift-Tab traces.
- Compact AX Park action with exactly one $900 treasury mutation.

Full Keyboard Access-critical behavior and VoiceOver-critical label/value/help/action semantics were inspected in the live accessibility tree. Spoken VoiceOver audio was not recorded.

## Compatibility

- **Analytics/story:** existing PLAY-013 and PLAY-047 truth is consumed without duplication.
- **Map action:** existing PLAY-034 coordinate/presentation is consumed without creating another target.
- **Commands:** no command or public command/store/focus contract was added.
- **Renderer/gameplay/platform:** no owned rule, validation, art, overlay, save, or session behavior changed.
- **Input:** pointer, keyboard, FKA, and AX actions converge on existing store/catalog/map-action paths.
- **Integration:** no push, merge, rebase, cherry-pick, force operation, or self-integration was performed.
