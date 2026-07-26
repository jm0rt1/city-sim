# PLAY-071 completion

- **Title:** Make growth visibly transform the city
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Published authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Ordered candidate commits:**
  1. `506f4b624aa731babdd45e1dc59b02319033d343` — retained
     pre-change density and condition audit;
  2. `71375978196cb10f7aa591e2c661bb9b802b91fc` — deterministic
     strategy-family development, marginal consequences, pressure damage,
     recovery scar, analytics, and tests;
  3. `6e1654dd67865b9a49f0be1c21070f217ad40df1` — exact staged
     Commercial/Industrial journey, screenshot, validation, and limitation
     evidence.
- **Status:** clean gameplay candidate for integration-controlled corpus
  adoption, performance disposition, and independent playtest; not
  self-accepted

## Player-visible outcome

A successful or recovered city now changes its authoritative built district:

- Commercial and Industrial lots develop beyond level 1 when their own
  occupancy, demand, happiness, utility, treasury, and milestone-reserve
  conditions justify growth.
- Higher levels create real tax/jobs capacity while adding upkeep and marginal
  power/water load; Industrial density also adds pollution pressure.
- Regional pressure damages two developed strategy-family parcels.
- Recovery removes distress but leaves one weathered parcel as a durable,
  legible consequence/recovery record.
- `Neighborhood Upgraded` identifies the affected block using the UI's
  one-based coordinates and explains cause, payoff, and operating cost.

The behavior is bounded and deterministic. Density pauses once Charter or
Regional qualification begins, preserves the accepted four recovery identities,
and does not make either strategy dominant.

## Changed surfaces

- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityAnalytics.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `docs/production/evidence/PLAY-071/BASELINE-DENSITY-AUDIT.md`
- `docs/production/evidence/PLAY-071/IMPLEMENTATION-AND-STAGED-EVIDENCE.md`
- `docs/production/evidence/PLAY-071/industrial-regional-capital-staged.jpeg`
- `docs/production/completed/PLAY-071.gameplay-loop.md`

## Automated validation

- Final focused gameplay command:

  ```text
  env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play071-final-clang \
    SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play071-final-swift \
    swift test --disable-sandbox --package-path Native/CitySimNative \
    --filter GameplayLoopTests
  ```

  Result: **39 tests, 0 failures** in 21.455 seconds.

- The focused suite proves kind-relative development gates, multiple levels,
  marginal revenue/upkeep/utilities/pollution, one-based upgrade messaging,
  two-lot pressure, one-lot recovery scar, all four recovery identities,
  ignored-recovery cost, Town Charter timing, Regional terminal horizon,
  daily phase ordering, late choice, non-flip, legacy decode, save/load,
  backup, replay, and exact Undo.
- `bash -n script/build_and_run.sh`: passed.
- `git diff --check`: passed.
- Staged build/launch verification: passed for exact product commit
  `71375978196cb10f7aa591e2c661bb9b802b91fc`, identity
  `gameplay-loop-w8f1a46b88376`.

The complete host suite executed **243 tests** with **132 failures** in
196.663 seconds. This is not reported as a pass. Gameplay remained 39/39;
integration-controlled story corpus, fingerprints, spatial/camera expectations,
and renderer telemetry require companion disposition. A targeted retry of the
state-changing renderer telemetry test averaged **2.227 ms** against the
existing **2.1 ms** budget and failed. No renderer or platform fixture surface
was changed to hide those gates.

## Hands-on staged journeys

### Commercial

A fresh, uncoached mixed pointer/keyboard route included one rejected placement,
Commercial commitment, a 12-day warning, Temporary Tax Relief, reserve
utilities, a second Commercial lot, permanent Charter, two visibly damaged
storefronts, and Regional tax recovery. The final overlay reported:

- 560 residents;
- `$64,274` treasury;
- `+$216/cycle`;
- 68% happiness;
- Commercial Stewardship;
- Temporary Tax Relief.

### Industrial

A separate fresh route on the same candidate included Industrial commitment,
the Freight warning, first green buffer, reserve utilities, a second Industrial
lot, permanent Charter, a `$7,000`/eight-happiness Regional setback, two damaged
Industrial parcels, a selected distressed block at 41% vitality, third park,
additional reserve utilities, and terminal recognition. The final overlay
reported:

- 560 residents;
- `$73,671` treasury;
- `+$168/cycle`;
- 58% happiness;
- Industrial Expansion;
- Green Buffer.

Commercial public realm and Industrial utility expansion were not operated live
in this lane. Both remain deterministically green and require independent
hands-on coverage. Full causal details and the retained Industrial terminal
screenshot are under `docs/production/evidence/PLAY-071/`.

## Compatibility and contract impact

- No new public or persisted contract.
- No schema/fingerprint version, command, renderer state, fixture format,
  SwiftUI, SpriteKit, package, build-script, asset, or legacy Python change.
- Existing `level`, `constructionProgress`, `condition`, strategy, objective,
  message, save, Undo, backup, and replay contracts are reused.
- Daily progression, legacy missing-key behavior, Charter permanence, all four
  recovery identities, and Regional terminal immutability remain green.

## Integration handoff

Integration should adopt the new authoritative story checkpoints into the
platform corpus rather than treating pre-PLAY-071 fixture digests as product
truth. The renderer owner must dispose the reproducible 2.227 ms telemetry
failure without relaxing the budget. Independent playtest should run the two
recovery identities not operated live here and confirm the visible level/scar
presentation on the integrated renderer.
