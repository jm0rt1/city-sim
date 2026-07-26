# PLAY-071 implementation and staged evidence

- **Published authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Baseline audit:** `506f4b624aa731babdd45e1dc59b02319033d343`
- **Product candidate:** `71375978196cb10f7aa591e2c661bb9b802b91fc`
- **Staged identity:** `gameplay-loop-w8f1a46b88376`
- **Bundle identifier:** `com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376`
- **Status:** gameplay candidate; integration-controlled corpus adoption,
  renderer telemetry, and independent playtest remain open

## Player-visible correction

The accepted city previously kept every Commercial and Industrial building at
level 1 while Residential lots raced to level 4. Pressure and recovery never
changed a lot's condition. The city therefore recorded a strategy story in
text and numbers without retaining that story in its authoritative built
district.

The candidate now:

1. evaluates Commercial and Industrial development against kind-relative
   occupancy, demand, happiness, and utility headroom at deterministic 64-tick
   boundaries;
2. preserves treasury and milestone reserves so automatic density cannot spend
   the player's recovery path;
3. charges each developed level for upkeep and marginal power/water, and adds
   strategy-specific revenue plus an Industrial pollution cost;
4. damages two developed route-family parcels when Regional pressure lands;
5. repairs the worst damage but retains exactly one weathered route-family
   parcel as a visible recovery record;
6. emits one existing `CityMessage` titled `Neighborhood Upgraded` with
   player-facing one-based block coordinates, cause, benefit, and operating
   cost.

No persisted field, public store contract, command, save/schema identifier,
renderer input, fixture format, SwiftUI, SpriteKit, package, build script, art
selection, or legacy Python surface changed.

## Deterministic route evidence

`GameplayLoopTests` passed **39/39** at the exact product candidate:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play071-final-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play071-final-swift \
  swift test --disable-sandbox --package-path Native/CitySimNative \
  --filter GameplayLoopTests
```

The focused assertions prove:

- thin starting utility reserves delay density; after the player adds reserve
  utilities, both strategy families contain a developed level by tick 256;
- both cities retain at least two zone levels and the upgrade message identifies
  `block x + 1, y + 1`;
- developed Commercial levels increase revenue, upkeep, power, and water;
- developed Industrial levels increase revenue, upkeep, power, water, and
  pollution pressure;
- two route-family lots enter distinct distressed/weathered bands at Regional
  pressure, recovery clears distress, and exactly one weathered parcel remains;
- Commercial tax relief, Commercial public realm, Industrial utility
  expansion, and Industrial green buffer all remain viable, earn the Town
  Charter at tick 844, and reach Regional Capital or explicit loss by tick
  2,800;
- all four terminal routes contain at least two upgraded zone lots, multiple
  levels, and one route-family recovery scar;
- ignored setbacks remain costlier but recoverable;
- daily scheduling, late choice, non-flip, exact-once phases, stale-guidance
  retirement, legacy decode, save/load, backup, replay, and exact Undo
  restoration remain green.

The platform corpus generated the following new terminal checkpoints during
the full run:

| Route | Terminal tick | Candidate digest |
|---|---:|---|
| Commercial · tax relief | 1,024 | `d3dc139...` |
| Commercial · public realm | 1,024 | `50f9d91...` |
| Industrial · utility expansion | 1,036 | `4287b7c...` |
| Industrial · green buffer | 1,040 | `3de8dc7...` |

These are observations for integration adoption, not new fixture authority.

## Real staged Commercial route

The exact product candidate passed:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play071-stage-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play071-stage-swift \
  script/build_and_run.sh --verify
```

The script built, staged, and launched
`dist/CitySim-gameplay-loop-w8f1a46b88376.app`.

Using ordinary pointer controls for panels/tools/policy and keyboard controls
for pause, speed, map movement, and placement:

1. A fresh city paused on Day 7. Commercial Stewardship was selected by
   pointer.
2. The first visually chosen map target at block 14,16 rejected placement.
   Keyboard movement found valid block 9,12 and Return placed Commercial,
   proving rejected placement did not prevent commitment.
3. At Day 28 the visible `Protect local storefronts` warning showed 12 days.
   The city was paused again at Day 38 with two days remaining.
4. The player reduced Commercial tax to 9%; the first recovery recorded
   Temporary Tax Relief.
5. The player added a second power plant at block 7,12, a water tower at block
   6,12, and another Commercial lot at block 8,12, then restored tax to 10%.
6. By Day 221 the Town Charter was permanent and the HUD warned that the
   Regional mandate would arrive in seven days.
7. At Day 246 `Regional Retail Pressure` reported two damaged developed
   storefront parcels. Selected block 8,12 was visibly distressed at 52%
   vitality.
8. The player reduced Commercial tax to 8%. By Day 273 the same block was
   weathered at 63% vitality and qualification was 8/12.
9. The terminal overlay reported Regional Capital with **560 residents,
   $64,274 treasury, +$216/cycle, 68% happiness, Commercial Stewardship, and
   Temporary Tax Relief**.

## Real staged Industrial route

The same running candidate started one new authored region from the Commercial
victory overlay:

1. Industrial Expansion was selected by pointer; keyboard movement placed the
   first Industrial lot at block 9,12.
2. Day 27 exposed `Freight Strategy` with 12 days, `+$130/cycle`, 73 jobs, and
   utility truth. By Day 45, `Freight consequence pending` retained ten days;
   the selected Industrial block showed severe power, water, and pollution
   pressure at 63% vitality.
3. `Act` selected a green buffer. Keyboard movement placed the second park at
   block 11,14. At Day 57 the HUD recorded `Green buffer locked in`; at Day 73
   the story was complete.
4. The player built a second power plant at block 7,12, a second water tower at
   block 6,12, and a second Industrial lot at block 8,12.
5. At Day 205 the city had 504 residents and five of twelve Charter days. At
   Day 223 the Charter was permanent and the Regional mandate showed five
   days.
6. At Day 246 `Regional Freight Overload` cost $7,000 and eight happiness and
   reported two damaged developed Industrial parcels. Selected block 8,12 was
   visibly distressed at **41% vitality**.
7. `Act` selected a third park and keyboard placement built it at block 9,15.
   The player then added explicit Regional reserve power at block 6,11 and
   water at block 7,11.
8. The terminal overlay reported Regional Capital with **560 residents,
   $73,671 treasury, +$168/cycle, 58% happiness, Industrial Expansion, and
   Green Buffer**.

The retained Industrial terminal screenshot is
`docs/production/evidence/PLAY-071/industrial-regional-capital-staged.jpeg`.
Commercial public-realm and Industrial utility-expansion were not operated
live in this lane; both are covered by deterministic scenario tests and remain
independent hands-on gates.

## Full-suite and performance disposition

The complete host suite executed **243 tests** with **132 failures** in
196.663 seconds. `GameplayLoopTests` remained 39/39. The failures are not
claimed as a pass:

- integration-controlled story corpus, fingerprints, spatial snapshots, and
  camera expectations freeze the pre-PLAY-071 authoritative lifecycle and need
  companion adoption;
- the state-changing renderer telemetry sample exceeded its existing 2.1 ms
  budget.

The renderer check reproduced independently:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play071-perf-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play071-perf-swift \
  swift test --disable-sandbox --package-path Native/CitySimNative \
  --filter CitySimulationTests/testRendererInitialRenderAndPulsesInvalidateOnlyChangedSpatialTruth
```

Result: **1 test, 1 failure**; 10 pulses took 22.274 ms, averaging **2.227
ms**, above 2.1 ms. PLAY-071 did not change renderer code or relax the
renderer-owned budget. Integration must adopt the new story truth and dispose
the performance gate before accepting the candidate.
