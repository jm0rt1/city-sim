# PLAY-012 Three-Act Candidate Checkpoint

- **Product commit:** `49764b89dbdcfa46add838114db9a95b4f5ba6ae`
- **Authority/base:** `3e8ffe405b00783121c08a06fadc7e0335d7d7aa`
- **Lane:** gameplay loop
- **Disposition:** blocked pending platform fixture adoption and real no-coaching live proof

## Product scope

The candidate changes only:

- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`

It does not change models, save schema/version, public store/snapshot contracts, commands, input, UI, renderer, assets, package topology, build scripts, or legacy Python.

## Deterministic three-act evidence

The fixed daily-boundary timeline is:

| Beat | Tick | 1x simulation time | Maximum gap from prior beat |
| --- | ---: | ---: | ---: |
| Opening growth-engine prompt | 4 | 00:01.68 | 1.68 seconds |
| Strategy warning | 32 | 00:13.44 | 11.76 seconds |
| Strategy-specific opportunity | 96 | 00:40.32 | 26.88 seconds |
| Complication forecast | 160 | 01:07.20 | 26.88 seconds |
| Avoided or realized setback | 224 | 01:34.08 | 26.88 seconds |
| Recovery review and authored payoff | 288 | 02:00.96 | 26.88 seconds |
| Durable Town Charter in both fixtures | 844 | 05:54.48 | Objective values advance on daily boundaries during this interval |

These are deterministic simulation timestamps, not live wall-clock or pointer/keyboard observations. No live timestamps are claimed.

Each route contains three consequential commands before payoff: choose the strategy zone, double down before the opportunity for greater upside and exposure, then answer the complication. Commerce trades cleaner job growth and happiness against tax relief or a park. Industry buys faster jobs/cash with higher pollution and utility load, then answers through reserve utilities or a green buffer. Preparing early avoids the direct shock only by accepting lower tax/demand, park capital/upkeep, or utility capital/upkeep.

The focused suite proves representative zoning, park recovery, and utility decisions change treasury and authoritative analytics within four ticks, or 1.68 seconds at 1x. It also preserves ignored-setback recovery, transient Charter reset, one-time durable award, legacy decode, JSON round trip, exact undo, and 2,800-tick survivability.

## Validation

### Passed

- `swift test --package-path Native/CitySimNative --filter GameplayLoopTests`
  - 19 passed, 0 failed in 10.020 seconds on the preserved candidate.
- `git diff --check`
  - passed with no output before the product commit.
- `bash -n script/build_and_run.sh`
  - passed with no output.
- `./script/build_and_run.sh --verify`
  - passed for exact commit `49764b8`.
  - candidate `gameplay-loop-w8f1a46b88376`;
  - bundle `com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376`;
  - isolated data root `dist/test-data/gameplay-loop-w8f1a46b88376`;
  - staged PID `2669` remained alive at verification.

### Full-suite platform drift

The full native run executed 94 tests. 85 passed. Nine assertions failed, all inside two platform-owned frozen-fixture tests; gameplay 19/19, CitySimulation 36/36, command catalog 11/11, proof-window 1/1, and world rendering 13/13 passed.

`SessionPlatformTests.testAcceptedStrategyCommandsProduceFrozenCheckpoints` produced eight expectation failures:

1. industrial treasury expected `$49,433.20`; candidate produced `$56,433.20`;
2. commercial treasury expected `$58,393.26`; candidate produced `$58,993.26`;
3. industrial warning expected copy containing `by Day 41`; candidate truthfully says `by Day 25`;
4. commercial warning expected copy containing `by Day 41`; candidate truthfully says `by Day 25`;
5. industrial digest expected `11adf523ca4af342d3a1126c04d3469bf3e02ddd30c8b77ea22e21c70420c5ff`; candidate produced `f8ecd67582597fc859ddc91c9de8b5b3842f702581161588d671ae06ec839e13`;
6. commercial digest expected `65c11403d0876fc9af27782e240a4e98b2806b55b8953aa81490934bb860f68c`; candidate produced `65ce47a635ad3305afcc8871bafb0df1ba0cf245cca0548e1873c87224edb223`;
7. the five-repeat industrial digest set expected the old industrial digest and consistently produced the new one;
8. the five-repeat commercial digest set expected the old commercial digest and consistently produced the new one.

`SessionPlatformTests.testDenseSessionSimulationAndPersistencePerformance` produced one expectation failure:

9. dense v3 digest expected `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8`; candidate produced `ce5d912d97702c5a0a3b84149e432219fe9faca54dcb9b2fa98e0b5ba54f8ef7`.

The dense fixture still ended deterministically at tick 44 in `.lost`, round-tripped exactly, stayed within performance limits, and produced a 136,590-byte save. These changes require independent PLAY-041/platform adoption; the gameplay lane did not edit frozen platform expectations.

## Live proof blocker

The exact staged candidate launched and passed process verification, but the mandated Computer Use runtime did not return app state for the exact bundle on either attempt:

- first `node_repl` / Computer Use `get_app_state` attempt: user-aborted after 2,275.1 seconds (37 minutes 55.1 seconds);
- second clean-kernel attempt with a requested 10-second tool timeout: user-aborted after 5,922.0 seconds (98 minutes 42.0 seconds).

Because the Computer Use skill prohibits substituting `osascript`, System Events, JXA, or CGEvent automation, the worker did not bypass the failed runtime. No pointer/keyboard actions, no no-coaching journey, no wall-clock decision timestamps, and no screenshots are claimed or invented.

## Required closure

1. PLAY-041/platform independently reviews and adopts or rejects the candidate checkpoint values and fingerprints.
2. PLAY-051 or integration runs the exact staged candidate through a real no-coaching pointer-and-keyboard journey, recording first decision, every decision gap, complication diagnosis, recovery, payoff, and strategy distinction.
3. Integration—not this worker—decides whether the combined candidate satisfies Wave 003.
