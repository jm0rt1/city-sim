# PLAY-034 staged evidence — `704784b` on compatible world

## Candidate

- Integration authority merged at `a7b2378c834464d2fbb64ea495289cc3d186bf9b`.
- Authority tip at synchronization: `6d7df1efa73b4fbcb3e6acf992a80adbaac148ec`.
- Preserved PLAY-038 history: `4c92592dcce9669b2024736e01f936ef1874e7e7`.
- Compatible world merge: `78a8898e4862b6570a3aaeb6a00b9f97176e2f15`.
- World product: `45dd181221701f7cb73be39b558b7440d86e13b5`.
- World evidence: `013bdd37c706f2c7326bda870259feb7379570e4`.
- PLAY-034 product: `704784b21294562fba5f145455c44e2de2a64e76`.
- Candidate: `ui-input-wdbeadac6e0bd`.
- Bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`.
- Staged executable SHA-256: `5c812f17cc58f29ab7ab031898d95534a2ee3b960e2a008edd59cdc5001c1181`.
- Final compact manifest SHA-256: `10fe07d94c8b91b2510529db1c71c7e6b6cb25d9d2ade9a10d84fa076ce3dbc6`.
- Genuine default frame: 1,229 x 768 on the proof display.
- Explicit compact frame: 900 x 652 for exact 900 x 600 content.

The staged app was launched only after its isolated candidate data root and
preference domain were reset. The same reset was repeated before compact proof.
The prior candidate data was preserved under `/private/tmp`; no production or
other lane data was removed.

## Closed compact defect

At exact compact, keyboard navigation first selected valid open land at block
14,11. The map announced `Build Residential at block 14, 11`, available for
$1,800, and showed the grounded valid preview.

A pointer click then targeted the visibly occupied Commercial tile at block
14,12. The sole active target immediately changed to block 14,12, the grounded
preview changed to blocked, and the map exposed the accepted `.occupied` reason:
`Demolish the existing structure before building here.` The treasury stayed
$26,000 and Undo stayed disabled. It did not build at the stale keyboard target.

`08-compact-keyboard-valid-target.jpeg` and
`09-compact-pointer-occupied-target-no-mutation.jpeg` retain the before/after
pair.

## Default journey

Fresh launch exposed only Welcome and its Start Building action in the game
surface accessibility tree. Pointer dismissal returned focus to `City map` at
authored Day 1 and 1x. Space then visibly paused the existing simulation truth.

With Residential selected:

- Right selected occupied Road at block 14,13. Return produced the durable
  `.occupied` feedback without mutation.
- A pointer click on a different occupied Commercial tile changed the active
  map/AX/preview target to block 14,12; treasury and Undo remained unchanged.
- Up selected valid block 14,11. Return built once and changed treasury from
  $25,631 to $23,831.
- Undo restored $25,631. The map's accessibility action
  `Build Residential at block 14, 11` built once and changed treasury to
  $23,831.
- Undo restored again. A pointer click on the same grounded block 14,11 built
  once at that coordinate and changed treasury to $23,831.

Each successful route produced one construction site, one $1,800 charge, one
positive feedback message, and one enabled Undo. The selected Residential tool
was retained after every rejection.

## Exact compact journey

Fresh compact Welcome measured 900 x 632 with its toolbar hidden; after
dismissal the normal host measured 900 x 652, the required exact 900 x 600
content area. Welcome still exposed only its CTA and kept the authored Day 1
state unchanged. Pointer dismissal plus Space paused at Day 1.

The compact catalog selected Residential, and Right/Up/Up selected valid block
14,11. The exact stale-target reproduction then changed to occupied block 14,12
through pointer input without mutation. Up restored the valid block 14,11.

Opening Command Center details retained the same map coordinate, available
action, and grounded preview while keeping the map visible. Escape closed
details and returned map focus without cancelling Residential or the selection.
Return then built block 14,11 once and charged exactly $1,800.

## Full Keyboard Access and accessibility

The active host setting was `AppleKeyboardUIMode = 2`.

- The semantic map continuously exposed one selected coordinate, the primary
  action name, availability/cost or accepted reason, and the Inspect action.
- Tab handed focus from the map into the native key-view loop.
- Space on the focused New Arcadia HUD button opened Command Center exactly
  once. The selected block 14,11 and Residential tool remained unchanged.
- The default accessibility custom action built the announced valid coordinate
  exactly once.
- Blocked targets did not advertise a build action; they retained Inspect and
  the accepted disabled reason.
- Welcome and text-field quarantine are covered by focused tests and the fresh
  Welcome tree.

AX identity, value, help, enabled state, focus, and custom actions were
inspected separately from Full Keyboard Access. Spoken VoiceOver was not
recorded or claimed.

## Automated validation

- New PLAY-034 target/bridge tests: 5 passed, 0 failures.
- Complete `CityCommandCatalogTests` plus focused preview/compact renderer
  tests: 32 passed, 0 failures in 9.545 seconds.
- Full native suite on exact product `704784b`: 180 passed, 0 failures in
  79.321 seconds.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed at default and with
  `CITYSIM_COMPACT_WINDOW=1`.

The matrix covers occupied, road-required, unaffordable, valid, and the same
road-required tile becoming available immediately after an adjacent
authoritative road change. Tests alternate pointer and keyboard targets,
exercise Return/pointer/AX exactly once, and retain modal/text quarantine.

## Retained captures

- `01-default-welcome-contained.jpeg`
- `02-default-pointer-occupied-target.jpeg`
- `03-default-keyboard-valid-target.jpeg`
- `04-default-return-build-once.jpeg`
- `05-default-ax-build-once.jpeg`
- `06-default-pointer-build-same-target.jpeg`
- `07-compact-900x600-welcome-contained.jpeg`
- `08-compact-keyboard-valid-target.jpeg`
- `09-compact-pointer-occupied-target-no-mutation.jpeg`
- `10-compact-details-retains-active-target.jpeg`
- `11-compact-escape-restores-map-target.jpeg`
- `12-compact-return-build-once.jpeg`
- `13-compact-fka-tab-focus.jpeg`
- `14-compact-fka-space-opens-details-once.jpeg`
- `default-ax.txt` and `compact-ax.txt`
- `SHA256SUMS`

No renderer art, pointer hit geometry, simulation validation, gameplay rule,
save field, command inventory, or CONTRACT-008 expansion changed. Final
renderer acceptance remains quality-owned.
