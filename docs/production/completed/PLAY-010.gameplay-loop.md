# PLAY-010 Completion — Consequential Early-Game Pressure

- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Status:** ready-for-integration
- **Baseline:** `c4460255ca810ce4de878f20f98a883983cf3dbd`
- **Approved contract:** `87e83355058e0a5b54bf0a261bd8adde45545bb0` (`CONTRACT-001`)

## Player-visible outcome

New Arcadia now opens with a recoverable operating deficit, a small employment gap, and limited utility reserve instead of an already-solved economy. The player is immediately offered two credible responses: cleaner commercial growth plus temporary tax pressure, or faster industrial tax-base growth with added pollution. Waiting produces staged budget, reserve, and hiring warnings before a utility shortfall; deliberate austerity and capacity construction recover the city.

The objective sequence is now `Balance the Books` → `Prepare for Growth` → `Earn the Town Charter`. The charter requires 12 consecutive qualifying daily checks across treasury, cashflow, employment, utility coverage and reserve, happiness, population, and mixed development. A failed day resets the run; the award is permanent, one-time, undo-safe, and visibly routed through the existing objective/message surfaces.

## Ordered commits

1. `d8c20ff6a27d672cf72f089f1f5f1aa04f906201` — `PLAY-010: Create deterministic opening pressure`
2. `a6e303df09388fd1d470216f26e2f061e145833f` — `PLAY-010: Persist Town Charter progression`
3. `860078be4061ad9ca6fe1d77e81198ce53e9e5ef` — `PLAY-010: Retain staged session evidence`
4. `f870160a141e43775afc7d7aeb592e6f0c4da736` — `PLAY-010: Align charter checks with game days` (returned by integration; timing superseded below)
5. `378be2e0cc85514ed25b3b5a2b798a6fb9d0ddfe` — `PLAY-010: Restore daily charter boundaries`

The branch merged accepted `origin/master` at `bba74bead7f522076f5ba9d276b99e4a77dc304d` to acquire CONTRACT-001 without rewriting the pre-contract checkpoint.

## Exact files changed

- `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`
- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityAnalytics.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `docs/production/evidence/PLAY-010-staged-objectives.jpeg`
- `docs/production/evidence/PLAY-010-staged-pressure-warnings.jpeg`

Legacy Python, `SaveGameService`, package topology, renderer contracts, view architecture, and shared command types were not changed.

## Automated validation

- `env CLANG_MODULE_CACHE_PATH=/tmp/citysim-play010-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/citysim-play010-swift-cache swift test --package-path Native/CitySimNative --filter GameplayLoopTests`
  - 10 tests passed, 0 failures in 5.760 seconds.
- `env CLANG_MODULE_CACHE_PATH=/tmp/citysim-play010-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/citysim-play010-swift-cache swift test --package-path Native/CitySimNative --skip-build`
  - 45 tests passed, 0 failures in 28.505 seconds.
  - The corrected 700-day two-strategy horizon passed in 4.652 seconds. Both strategies reached exactly tick 2,800 / Day 701, earned the charter, remained non-failed, and kept positive treasuries through approximately 19.6 minutes at the app's 1× cadence.
  - Renderer diagnostic: 10 pulses averaged 1.921 ms with 5,760 tile-root reuses and 0 updates.
- `git diff --check`
  - Passed with no output.
- `bash -n script/build_and_run.sh`
  - Passed with no output.
- `./script/build_and_run.sh --verify`
  - Built the staged bundle, launched `dist/CitySim.app`, and verified the `CitySimNative` process remained alive.

Coverage includes opening pressure, ignored-growth failure and recovery, the two distinct strategies, tax-demand-happiness tradeoffs, legacy missing-key compatibility through ticks 1–3 with normalization at tick 4, new/awarded JSON round trips, 11 full qualifying days without an award, award on the 12th full day, full-day-boundary reset then later award, one-time permanent award/message, exact undo restoration, and objective/message routing.

## Hands-on staged-app flow

1. Launched the repository-built `dist/CitySim.app` and let the untouched opening run at 1×.
2. Opened the Mayor's Mandate at Day 26. The real HUD showed a `$68 / cycle` deficit, no job openings, 35 power and 31 water spare, and the three ordered objectives with exact blockers.
3. Paused at Day 41 after reserve tightened. The HUD showed `$19,672`, `-$64 / cycle`, 340 residents, 190 jobs, and only 22 power/19 water spare.
4. Opened Notices. The existing Journal presented `Budget Gap` on Day 2, `Utility Reserve Tight` on Day 24, and `Hiring Bottleneck` on Day 33. The hiring notice explained the commercial-versus-industrial tradeoff, and each notice exposed its existing related-data route.
5. Selected the Commercial tool and exercised a pointer action on an occupied tile. The staged app preserved state and returned the correct visible rejection: `Demolish the existing structure before building here.`

HUD values, blockers, and warning copy matched the authoritative simulation/analytics state throughout the run.

## Proof artifacts

- `docs/production/evidence/PLAY-010-staged-objectives.jpeg`
- `docs/production/evidence/PLAY-010-staged-pressure-warnings.jpeg`
- Deterministic journey: `GameplayLoopTests.testTwoStrategiesEarnTheCharterAndSurviveTheTwentyMinuteHorizon`
- Recovery: `GameplayLoopTests.testIgnoredGrowthWarnsBeforeAUtilityShortfallAndCanRecover`

## Compatibility and quality consequences

- **Save:** `CityGameState.progression` is optional, Codable, Equatable, and Sendable. New cities initialize it explicitly. A legacy missing key decodes as `nil` and normalizes only on the next daily boundary. No save-service, schema identifier, migration, or package change was made.
- **Undo:** the existing whole-state undo snapshot restores progression exactly; dedicated coverage proves it.
- **Accessibility:** the real app accessibility tree exposed named/value-bearing treasury, population, happiness, employment, utilities, objectives, notices, tools, and related-data actions. No new custom control was introduced.
- **Compact layout:** existing regular/compact HUD frame coverage passed; this lane made no layout changes.
- **Performance:** progression evaluates once per daily boundary on the fixed city grid. No renderer or observation boundary changed; the full-suite renderer diagnostic remained healthy.

## Shared-contract and merge notes

CONTRACT-001 authorized only the optional `CityProgressionState?`, existing objective/open-objective/open-message mappings, and title-routed `CityMessage` award. The implementation adds no general event system, save migration, new public store type, command, view architecture, or renderer contract.

`origin/master` already contains CONTRACT-001. Integration may merge this branch, or cherry-pick `d8c20ff`, `a6e303d`, `860078b`, `f870160`, and `378be2e` in that order while skipping the synchronization merge `bba74be`.

## Known limitations and deferred work

- The independent coached pointer and keyboard 20-minute acceptance journey remains the PLAY-050/integration gate. This lane supplies the deterministic 19.6-minute horizon plus real staged-app objective/warning/pointer evidence.
- Computer-use coordinate targeting could not place a new map tile because multiple local CitySim bundles share one identifier; element-based pointer input still verified the occupied-tile rejection. Deterministic build, consequence, recovery, and undo flows passed in the native suite.
- Cross-lane rendering and UI work may improve how the same authoritative signals are presented; those lanes must not duplicate progression truth.
