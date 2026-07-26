# PLAY-078 Starter-Town Platform Adoption Validation

- **Published authority:** `e6ba5ef7018030dcb3419b79ec19104a1c70e8e2`
- **Frozen gameplay source:** `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b`
- **Unmodified local gameplay commit:** `85b8963193fde123be6e3e9321860c19aa61969c`
- **Platform checkpoint adoption:** `05c1291866d047cfc995c82fb69a465210561119`
- **Fixture/test checkpoint:** `30bbf2fefea4868b65fb9fa5a280873912d7b525`
- **Lane:** `codex/citysim-simulation-platform`
- **Date:** July 26, 2026

## Input and contract verification

The gameplay input was applied once without conflict, amendment, or history
rewrite. Its four submitted blobs match the frozen source commit exactly:

```text
Sources/CitySimNative/Models/CityGameState.swift
Sources/CitySimNative/Services/CitySimulation.swift
Tests/CitySimNativeTests/GameplayLoopTests.swift
Tests/CitySimNativeTests/StarterDistrictTests.swift
```

The product adds two roads and four net Residential lots to the authored
starter town and changes current demand calculations. It does not add a model
field or change Codable shape, save/load behavior, schema 1, fingerprint
version 1, the canonical fingerprint algorithm, commands, or public
presentation snapshots.

Platform fixture commands that previously targeted the new road at `(8,11)`
or the new Residential lot at `(6,11)` now use the approved row-major,
road-accessible sequence `(4,8)`, `(5,8)`, `(6,8)`, `(7,8)`.

## Additive corpus identity

Historical files were not modified. Explicit preservation gates freeze:

```text
schema-0 legacy       28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908
schema-1 legacy       56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9
StoryStates v1        3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0
StoryStates v2        a793dc9ea5cfc50b7482fb7f4bf4e7a3a3c5e9cfb1cad6e47722fc17cbf22153
StoryStates v3        bb27da325a259eb4186c54a749e6eb0391731a7f277860103099813ded7fba69
VisibleCityStates v1  e9ee17bc14a5d61334a9598bddb5d25bc1cfe0cb12443f0b08cb6100526af236
VisibleCityStates v2  babc84514ccae064f3d1b856868ef14a4bc0d54e3477597b24e41349601a5eeb
```

Two explicit generation runs wrote each new corpus to independent roots:

```text
/private/tmp/citysim-play078-story-a
/private/tmp/citysim-play078-story-b
/private/tmp/citysim-play078-visible-a
/private/tmp/citysim-play078-visible-b
```

Recursive comparison reported no difference for either pair. The new compact
identities are:

```text
StoryStates v4        cfbff099a9064f83cbf1a279987722191ec23acc1f03b915bba816169543003a
VisibleCityStates v3  9eed6405adc84b8bdf025bb2ac1365b327c8659bdbf0384bc6f172d6c9a2aace
```

The Visible v3 manifest binds to local combined product authority
`85b8963193fde123be6e3e9321860c19aa61969c` and the Story v4 manifest hash.
Story v4 adds twelve current story states. Visible v3 adds fourteen current
vacant, construction, active, pressured, recovering, upgraded, and terminal
states across both strategies.

## Legitimate drift

All current fingerprints legitimately change because the authoritative
starter state has 34 roads, six Residential lots, a three-block opening
ledger, and subsequent simulation uses the accepted PLAY-076 demand rules.
Historical bytes and historical digests remain frozen.

Representative current identities:

```text
new city, progression     ee95ebc98d8314e2ae2661baa03bc11809a70811cec1fdfb5633930ee78186d3
new city, nil progression bba31f738c9b3b4d4e91d22714d151520736cf3aa48fabb67f15e0b2d9bbceb7
dense terminal v8         d9faccd7c23b6632d3ff6213eece9ed60868388b059132bef2e7f908cf1009a7
Commercial terminal/tax   034d788b7e0e8685e3ab32afcf924f9fce12e67e06cdaa756962489cf61a2d9d
Commercial terminal/park  a0c5c5fcfe0d9d5f114ff1c80e1fa010a9e9f2c9497cb77055ebf9700a0c812e
Industrial terminal/util  35ea7b790487e76f1dd6db8014db978b64ebb11e354db3ff4efe3ca55dd2fc9b
Industrial terminal/park  be55197b95550c6c25c716cffc3cff1bd973b7b3f44faf71dae2b7daf499ac17
```

Primary load, corrupt-primary backup recovery, paused load, cleared Undo,
uninterrupted replay, save/resume, grouped-speed equality, immutable
analytics/spatial snapshots, four terminal routes, and post-terminal command
rejection all remain exact.

## Validation results

Focused platform matrix:

```text
ProductionStoryStateFixtureTests   8/8
SessionPlatformTests              16/16
SpatialConsequenceTests           15/15
StrategyResolutionPlatformTests    6/6
TerminalVictoryPlatformTests       2/2
VisibleCityStateFixtureTests       7/7
Total                             54/54 in 64.004 seconds
```

Complete non-renderer command:

```text
swift test --package-path Native/CitySimNative \
  --skip 'WorldRenderingTests|CitySimulationTests/testRenderer'
```

Result: **198/198 passed in 173.504 seconds**. This includes all 30
non-renderer `CitySimulationTests`.

Complete native suite result: **271 tests executed; 59 assertion failures in
13 renderer-owned tests; all 198 non-renderer tests passed** in 212.406
seconds. Exact renderer-owned failing tests:

```text
CitySimulationTests.testRendererInitialRenderAndPulsesInvalidateOnlyChangedSpatialTruth
CitySimulationTests.testRendererInvalidatesOnlyOneChangedBuildingTile
CitySimulationTests.testRendererRoadMutationInvalidatesTargetConnectedRoadAndAdjacentFrontage
WorldRenderingTests.testCorridorAmbientLifeHasBoundedConnectedContextAndIsReduceMotionSafe
WorldRenderingTests.testDevelopedMassCameraIgnoresRemoteOpportunityAndNumericOccupancy
WorldRenderingTests.testEntireAuthoritativeRoadNetworkStaysPhysicalWithoutChangingHitGeometry
WorldRenderingTests.testIndustrialStrainCameraPrioritizesTheDominantDistrictWithoutHidingRemoteTruth
WorldRenderingTests.testOpeningCameraRefitsOnceAfterTheShippingViewportSettles
WorldRenderingTests.testRejectedGoldenDistrictReferenceStaysIneligibleAndRetainsExplicitLODAssets
WorldRenderingTests.testRoadEnclosedCommonsStayVacantAndJoinTheAuthoritativeFrontageNetwork
WorldRenderingTests.testRoundOneShippingStartExportsDevelopedBoundsDefaultAndCompact
WorldRenderingTests.testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs
WorldRenderingTests.testTypedPlacementTargetKeepsMeaningfulDistrictAndRoadContextAtBothShippingSizes
```

These failures retain obsolete renderer assumptions for 32 roads, old
developed bounds, old contextual/camera scales, and old invalidation
coordinates. The unchanged renderer pulse telemetry measured 2.728 ms against
the retained 2.1 ms threshold. PLAY-078 does not alter or bless any of those
renderer contracts.

Measured platform maxima remained within their existing limits:

```text
Story generation pair    5.664 s / 5.641 s   limit 20 s each
Visible generation pair  2.135 s / 2.138 s   limit 20 s each
Largest Story fixture    134,219 bytes       limit 2 MiB
Largest Visible fixture  134,184 bytes       limit 2 MiB
Fingerprint              1.411 ms max        limit 500 ms
Snapshot                 3.725 ms max        limit 500 ms
Save                     10.378 ms max       limit 1,500 ms
Load                     3.286 ms max        limit 1,500 ms
Retained spatial samples 92,160 bytes        existing bound
Dense simulation         45.648 ms           existing bound
```

Repository and staged checks:

```text
git diff --check                  passed
bash -n script/build_and_run.sh   passed
./script/build_and_run.sh --verify
                                   passed at 30bbf2fefea4868b65fb9fa5a280873912d7b525
```

The staged candidate used deterministic isolated identity:

```text
candidate_id       simulation-platform-w8bb1822a1e25
bundle_identifier  com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25
preference_domain  com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25
data_root          dist/test-data/simulation-platform-w8bb1822a1e25
manifest           dist/manifests/simulation-platform-w8bb1822a1e25.manifest
process_id         94615 (terminated after verification)
```

## Disposition

The simulation-platform adoption is ready for integration review. Renderer
owners must adopt or correct the 13 disclosed test contracts on the combined
product; those failures are intentionally unchanged and remain outside
PLAY-078.
