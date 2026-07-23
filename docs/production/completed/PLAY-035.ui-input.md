# PLAY-035 Completion — Make Rejected Keyboard Actions Explain Themselves

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Authority:** `3f7542de875d8547341e8dfffef58bdb6194f6c5`
- **Product commit:** `a7604eafcaa042583270bc4f9da07d254d5b8af1` — `PLAY-035: Explain rejected keyboard actions`

## Outcome

Map-command route eligibility is now separate from primary-action mutation availability. A focused Return can route an existing selected coordinate to the store even when its build presentation is unavailable. The store then executes the same governed primary-action attempt used by pointer input, so occupied, road-required, and unaffordable targets expose the existing accepted reason and durable recovery guidance without changing city state.

`canPerformMapCommand` and `CityMapPrimaryActionPresentation.isAvailable` remain truthful about whether activation will mutate state. Invalid build actions remain unavailable in the accessibility value and do not gain a custom AX mutation action. The new `canRouteMapCommand` only answers whether focused input may reach the store. Welcome policy, real map first-responder ownership, tool/coordinate state, Escape, and valid single dispatch remain intact.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`

No `CityScene`, renderer art, simulation validation, save, model, snapshot, target-selection, hover, CONTRACT-008, or PLAY-034 surface changed.

## Automated validation

- `testRejectedReturnRoutesOccupiedRoadlessAndUnaffordableTargetsWithoutAdvertisingAvailability`: passed in 3.432 seconds. It proves pointer/Return reason equivalence, no mutation or undo, stable tool/coordinate/scope, truthful unavailable state, durability beyond 3.2 seconds, and existing dismissal.
- `testFocusedReturnRoutesOneRejectedAttemptButTextAndWelcomeRemainQuarantined`: passed in 0.387 seconds. It proves actual `SKView` focus, one rejected dispatch, one valid dispatch, text-field quarantine, Welcome quarantine, exact $2,400 mutation, and Undo availability.
- Full native suite: 132 tests passed, 0 failures in 365.480 seconds.
- Renderer diagnostics from the unchanged renderer: 5,759 reused tiles, 1 updated tile, 1.500 ms average; 4,286-pulse soak averaged 1.1105 ms.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed at `a7604ea` for default and explicit compact launches.

## Staged proof

Default and exact 900 x 600 content keyboard/AX journeys are retained in `docs/production/evidence/PLAY-035/a7604ea/README.md`.

- Default invalid Return: occupied Road block 14,13 remained selected; AX stayed unavailable with the accepted reason; durable `Action blocked` remained after four seconds; treasury and Undo did not change.
- Default valid Return: available Open Land block 15,14 became Commercial once, treasury decreased exactly $2,400, and Undo became available.
- Compact invalid Return: the same selected target and accepted reason remained visible/accessible after four seconds; map focus and Commercial selection were retained; Escape returned safely to Inspect.

## Compatibility and contract notes

- **Catalog/AX:** action availability and disabled disclosure remain governed by the existing presentation. Routing a rejected key attempt does not advertise it as available.
- **Pointer/keyboard target:** unchanged. PLAY-035 acts only on the current `selectedCoordinate`; it does not synchronize hover or implement CONTRACT-008.
- **Simulation/save:** validation and persistence are untouched. The complete simulation, fingerprint, legacy fixture, replay, undo, and save suites passed.
- **Accessibility:** keyboard focus and AX labels/values/actions were inspected at both sizes. Spoken VoiceOver was not claimed.
- **Reduce Motion:** no animation or transition changed; the full reduced-motion renderer tests passed.

No shared-contract proposal is required beyond the published PLAY-035 authority. No push or integration was performed.
