# PLAY-070 Validation

## Disposition

`63eb5086f79a294d497190d7ff880aefb9c079ac` is a clean UI/input-lane
candidate ready for independent review.

The candidate adopts the accepted Regional Capital state without creating
new gameplay or UI contracts:

- all four authored Regional warning/critical titles have explicit responses
  composed from existing `CityCommandID` values;
- the strategy HUD consumes all 12 current v2 story identities;
- terminal visible and accessibility identity is selected only from durable
  `CityAnalytics.regionalCapitalAwarded`;
- authentic wins with no `secondAct` remain Town Charter wins;
- replay remains the existing `.newRegion` store/catalog intent.

No command, public store type, fixture, gameplay rule, save/schema,
SpriteKit, asset, package, or build-script surface changed.

## Automated gates

- Owned-failure filter:
  - `testStrategyHUDConsumesEveryFrozenStoryMomentFromAuthoritativeAnalytics`
  - `testDiagnosisConsumesExactSpatialSnapshotAndAuthoredNoticeInventoryHasHonestActions`
  - **2 tests, 0 failures**
- `GameStatusOverlayTests`: **7 tests, 0 failures**
- Full native suite: **235 tests, 0 failures, 178.374 seconds**
- `./script/build_and_run.sh --verify`: passed at exact product commit.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.

An initial sandboxed full-suite attempt crashed in AppKit `NSWindow` setup
before assertions. The named test passed alone and the complete suite passed
when rerun in the required native UI execution environment. This was an
execution-sandbox limitation, not a candidate failure.

## Action truth

The exact authored-title inventory proves these existing typed responses:

- `Regional Retail Challenge` and `Regional Retail Pressure`:
  `.inspectorFinances`, `.buildPark`
- `Regional Grid Mandate` and `Regional Freight Overload`:
  `.buildPowerPlant`, `.buildWaterTower`, `.buildPark`

Every response retains its consequence explanation, availability through
`store.canPerform`, and the existing `perform` or `performMapFocused` path.
The accepted Regional midpoint staged journey visibly exposed
`Regional Capital mandate`, `MANDATE · 16 DAYS`, and its two honest actions.
Pointer activation opened the existing Finances/Tax Policy surface. Keyboard
Down/Down/Return selected Park exactly once, announced `Park tool selected`,
selected the existing Park tool, and restored map focus. Escape returned to
Inspect without changing gameplay truth.

## Terminal identity and replay journey

### Current Regional Capital

Regular and exact compact runs loaded the accepted current fixture and
exposed:

- AX modal label: `Regional Capital victory`
- visible heading: `New Arcadia Became a Regional Capital`
- story heading: `Your Regional Capital Story`
- focused CTA: `Start a New Region`
- CTA help: `Starts one fresh authored city and closes this result`

The complete metric/story content and both replay actions were visible and
operable in the 900 x 600 content area without clipping.

### Authentic legacy Charter

The accepted missing-`secondAct` v1 fixture exposed:

- AX modal label: `Town Charter victory`
- visible heading: `New Arcadia Earned Its Town Charter`
- story heading: `Your Charter Story`

No Regional Capital copy appeared.

### Route parity

- Real pointer CTA: terminal closed once; Day 1 authored region appeared;
  feedback was `A fresh region is ready`; focus returned to the city map.
- Return CTA: same result exactly once.
- Space CTA: same result exactly once.
- File menu `New Region`: same result exactly once.
- Command guide: `new region` produced one available `New Region` result;
  Return executed the existing route and restored map focus.
- Escape while terminal was visible left the blocking result and authored
  state unchanged.
- The focused semantic CTA, AX label/value/help, visible focus ring, and
  keyboard activation cover FKA/VoiceOver-critical semantics. The modal AX
  tree suppressed the underlying HUD/map actions.
- Compact proof ran with `CITYSIM_COMPACT_WINDOW=1` and
  `CITYSIM_REDUCE_MOTION_PROOF=1`; terminal copy, focus, and actions remained
  complete.

## Known limitations

- Spoken VoiceOver audio was not recorded. Binding evidence is the live AX
  tree, focused semantic actions, keyboard/FKA-critical traversal, and the
  complete automated accessibility/input suite.
- The exact compact screenshot is 900 x 652 because it includes the 52-pixel
  titlebar; the app content is the required 900 x 600.
- The four exact authored notice titles are exhaustively disposition-tested.
  The staged action interaction uses the accepted Regional mandate fixture;
  it does not synthesize or regenerate an intermediate gameplay fixture.

All exact staged app processes were stopped after the journeys. No push,
integration, rebase, force, pinning, self-score, or self-acceptance occurred.
