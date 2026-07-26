# PLAY-074 Validation

## Disposition

`93693d0125f6cdd9ee660ea918891c23ed76bb4d` is a clean UI/input-lane
product candidate ready for independent PLAY-075 review.

The candidate makes the existing build intent legible before commitment and
keeps failure recovery map-first:

- active target, footprint, cost/upkeep, availability/reason, likely
  consequence, and cancellation are visible together;
- a blocked primary attempt still reaches the store-owned durable rejection;
- occupied, road-required, and unaffordable states map to one honest existing
  recovery command;
- a valid visible commit uses the existing map-primary intent exactly once;
- the active coordinate remains authoritative through recovery.

No public command, gameplay rule, simulation, save/schema, SpriteKit,
renderer, asset, package, build-script, shared contract, or task-authority
surface changed.

## Product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`

## Automated gates

- New owned tests: **2 tests, 0 failures**
- Complete `CityCommandCatalogTests`: **45 tests, 0 failures**
- Complete native suite: **242 tests, 0 failures, 176.225 seconds**
- Exact staged `./script/build_and_run.sh --verify`: passed at
  `93693d0125f6cdd9ee660ea918891c23ed76bb4d`
- `git diff --check`: passed
- `bash -n`:
  - `script/build_and_run.sh`
  - `script/persistence_relaunch_gate.sh`
  - `script/verify_candidate_isolation.sh`
  - all passed

Two earlier complete-suite attempts encountered the existing renderer timing
budget once and an output-truncated nonzero run. The exact isolated renderer
test then passed at 1.991 ms, and the final captured complete run passed all
242 tests with the renderer diagnostic at 1.990 ms. No product change was
made in response to those timing observations.

## Same-state staged journeys

### Regular occupied target

The complete decision presents Residential at block 12,12, footprint
`1 × 1 block`, `$1,800` plus `$4 / cycle`, Blocked, the accepted occupied
reason, likely `+280 homes`, and visible Bulldoze and Cancel controls.

Return retained Residential and produced the durable rejection. Real pointer
activation of Bulldoze selected the existing tool, preserved block 12,12,
did not charge treasury or create Undo, and restored map focus.

The interactive map aperture remains **463 px**, unchanged from the retained
baseline.

### Exact 900 x 600 road-required target

The complete decision presents Residential at block 14,16 with the same
footprint/cost/consequence and the accepted road-access reason. `Place road`
selected Road without changing the target or city. `Build here` then placed
one Road through the existing primary intent, charged exactly `$120`, and
enabled Undo.

The candidate map aperture is **362 px / 60.3%** of exact content height while
the situational decision is visible. Baseline was **416 px / 69.3%** without
the decision. The normal closed compact rail remains 64 px; only the active
decision temporarily uses the additional 54 px, and the world remains the
dominant surface above the required 40% floor.

## Contract and continuity

- Typed command/store intent remains the sole action route.
- Target and camera ownership remain unchanged.
- Pointer, Return, Space/FKA, menu, guide, Escape, and AX actions were
  exercised in the staged app.
- Focus returned deterministically to the city map after map-focused
  recovery and cancellation.
- Modal and text-entry quarantine remain covered by the complete suite; no
  global shortcut or modal policy changed.
- Undo restored exact valid-build state in the focused regression.
- Save/load behavior remains unchanged: no persistence surface changed, both
  staged layouts loaded the same accepted quicksave, and the full
  persistence suite passed.

## Known limitations

- Consequence copy is a concise projection of existing accepted constants,
  not a promise that later simulation conditions cannot change the outcome.
- `Place road` selects the existing Road tool and preserves the target; the
  player still chooses whether to commit it. No automatic gameplay recovery
  was invented.
- Spoken VoiceOver audio was not recorded; live AX/FKA semantics and the
  complete accessibility/input suite are retained instead.
- The compact screenshot is 900 x 652 because it includes the 52-pixel
  titlebar; app content is the required 900 x 600.

All exact staged app processes were stopped. No push, integration, rebase,
force, pinning, self-score, or self-acceptance occurred.
