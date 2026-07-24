# PLAY-034 Completion — Unify the Active Map-Action Target

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-combined-quality-gate
- **Integration authority at synchronization:** `6d7df1efa73b4fbcb3e6acf992a80adbaac148ec`
- **Integration merge:** `a7b2378c834464d2fbb64ea495289cc3d186bf9b`
- **Preserved PLAY-038 history:** `4c92592dcce9669b2024736e01f936ef1874e7e7`
- **Compatible world merge:** `78a8898e4862b6570a3aaeb6a00b9f97176e2f15`
- **World product:** `45dd181221701f7cb73be39b558b7440d86e13b5`
- **World evidence:** `013bdd37c706f2c7326bda870259feb7379570e4`
- **Product commit:** `704784b21294562fba5f145455c44e2de2a64e76`
- **Evidence commit:** `88cebf4d141e13b9be357c7d2767e129cde3ca41`

## Outcome

`CityGameStore.selectedCoordinate` is now the sole stored map-action target for
build and bulldoze modes. A narrow SpriteKit candidate callback publishes a
pointer coordinate through the existing store policy. The store accepts it only
while gameplay commands are enabled and produces one
`CityMapActionTargetPresentation` containing that coordinate and the existing
`CityMapPrimaryActionPresentation`.

SpriteKit consumes that store-produced coordinate, availability, and disclosure
for the grounded preview. It no longer revalidates a separately hovered build
coordinate. Keyboard movement updates the same selected coordinate. Pointer
click first publishes its visual target, then dispatches the existing
`.mapPrimaryAction` command used by Return and accessibility activation. Valid
actions mutate once; unavailable actions still reach the existing durable
store-owned rejection path.

Inspect hover remains renderer-local and non-selecting. Pointer candidate
publication is suppressed by the existing blocking-modal policy and while a
text editor owns focus. Escape ordering, focus generation, HUD-safe reveal,
command inventory, save/session behavior, and simulation validation remain
unchanged.

The inherited exact-compact AX assertion was reproducible because build mode
announced only `Pending` after an existing selection. The UI-owned wording now
retains explicit `Selected target` identity while announcing the pending action;
the assertion and live compact tree pass.

## Closed defect

At exact 900 x 600 content, keyboard selected valid block 14,11. Clicking the
visibly occupied Commercial at block 14,12 changed the sole target, grounded
preview, map AX value, and accepted reason to block 14,12. Treasury remained
$26,000 and Undo stayed disabled. The stale keyboard target did not build.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-034/704784b-compatible-world/*`

No renderer art, pointer hit geometry, hover inspection semantics, simulation
rule, validation order, gameplay progression, save schema, command ID/catalog
inventory, or new shared contract changed.

## Automated validation

- New target, pointer, AX, road-recovery, text-quarantine, and grounded-preview
  tests: 5 passed, 0 failures.
- `CityCommandCatalogTests` plus focused compact/preview renderer tests:
  32 passed, 0 failures in 9.545 seconds.
- Inherited
  `testExactCompactRetainsSemanticMapIdentityKeyboardSelectionAndEscapeFocus`:
  passed after reproducing the pre-fix assertion.
- Full native suite on exact product `704784b`: 180 passed, 0 failures in
  79.321 seconds.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed at default and with
  `CITYSIM_COMPACT_WINDOW=1`.

The focused matrix covers occupied, no-road, unaffordable, valid, and the same
blocked tile becoming available after an adjacent authoritative road change.
It alternates pointer and keyboard targets, proves pointer/Return/AX exactly
once, and preserves modal/text quarantine.

## Staged proof

The exact candidate identity, executable/manifest hashes, default and compact
journeys, accessibility-critical observations, Full Keyboard Access traversal,
and 14 retained Computer Use frames are recorded in
`docs/production/evidence/PLAY-034/704784b-compatible-world/README.md`.

- Candidate: `ui-input-wdbeadac6e0bd`.
- Bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`.
- Executable SHA-256:
  `5c812f17cc58f29ab7ab031898d95534a2ee3b960e2a008edd59cdc5001c1181`.
- Default proof frame: 1,229 x 768.
- Compact proof frame: 900 x 652 for exact 900 x 600 content.
- Fresh Welcome trees exposed only Welcome and its CTA.
- Default pointer, Return, and AX routes each built announced block 14,11 once
  in controlled undo-separated runs.
- Compact keyboard-valid to pointer-occupied alternation changed target and
  reason without mutation.
- Compact Command Center and Escape retained the active target, selected tool,
  paused state, map focus, and visible map.
- With `AppleKeyboardUIMode = 2`, Tab left the map and Space activated the
  focused command-center route once without changing the map target.

AX identity, value, help, focus, enabled state, and custom actions were
inspected separately from Full Keyboard Access. Spoken VoiceOver was not
recorded or claimed.

## Contract and compatibility notes

- **One coordinate:** the existing store selection fulfills CONTRACT-008; no
  second persisted pointer target exists.
- **One presentation:** SpriteKit receives store-produced
  `CityMapPrimaryActionPresentation` truth and does not repeat build validation.
- **One action route:** click, Return, and AX converge on the existing
  `.mapPrimaryAction` store command.
- **Inspect isolation:** inspect pointer hover remains renderer-local and does
  not select.
- **Quality boundary:** `45dd181` remains the integration-designated compatible
  renderer checkpoint. Final renderer acceptance remains quality-owned.

No shared-contract conflict or follow-on proposal is required. No push or
self-integration was performed.
