# PLAY-048 Starter District Runtime Adoption Checkpoint

**Status:** Platform adoption committed; integration gate blocked by renderer-owned
PLAY-016 adoption failures.

## Exact inputs and commits

- Published authority:
  `e3ba50cd478f185265c9ddaad1e319ddb9475942`.
- Frozen gameplay product:
  `a0ce861f7b7b5f5acbed5db63f44c18981c7f140`.
- Platform merge:
  `461d39f5dd4fec253b261efcdb2cea5259b7ef07`.
- Platform fixture/fingerprint adoption:
  `29cfc27` (`PLAY-048: Adopt starter district runtime fixtures`).

The product checkpoint changed only `CityGameState.newCity` and gameplay-owned
tests. It replaced the single-cross opening with 32 connected road cells,
relocated the water tower, changed opening treasury from $26,000 to $32,000,
and adopted the accepted $90.2 projected-deficit message. It did not change a
persisted field, command, save service, schema identifier, fingerprint
algorithm/version, renderer, or HUD.

## Unchanged-platform drift inventory

The first unchanged platform matrix executed 42 tests. It reported 88 golden
assertions, all confined to four expected adoption boundaries:

1. current, phase, accepted-route, and dense fingerprints/checkpoint values;
2. four recovery-resolution fingerprints;
3. four terminal-victory fingerprints;
4. the eight committed story resources and their manifest.

Every behavioral compatibility test passed before adoption: authentic legacy
bytes, schema-0/schema-1 load, digest validation, corrupt-primary backup
recovery, interrupted-save preservation, injected-root isolation, undo,
replay, grouped speeds, immutable presentation/spatial snapshots, and
backup-aware load availability. There was no rejected fixture command,
SaveGameService rejection, version change, or unexplained state mutation.

The drift is expected because version-1 canonical state includes every
authoritative field. Every current route starts from the changed road topology,
treasury, water-tower coordinate, and opening message. Spatial digests also
change because the road and utility-source geometry changed. The dense
generator fills only empty cells, so changing the opening from 24 to 32 road
cells changes the resulting dense building inventory and its authoritative
economy.

## Adopted frozen fingerprints

- Explicit current progression:
  `28b567b4e0da5302aeb28d81f3644bb6c07c44005b70d4f3dce146494a4ce1e5`.
- Current nil progression:
  `0e966e432ec6eff89e9a3785f2d083d74ccb4a32d6155a55e54eb64de788a888`.
- Industrial tick 840:
  `29c10ada386a509c5c88db8d6390f94bb3c048da220f07cd04707151990102e1`.
- Commercial tick 840:
  `7484cc20bb484b8c2b039341017a35cf302d98e33102f308718896a7d1bc17b2`.
- Industrial victory tick 844:
  `b79feac6f0f9de85201f4605de76d97401361e5cb3140ac11e86811c903a5d16`.
- Commercial victory tick 844:
  `663f1f4b32660ba8e478e1f75edc9e599464530e2494c26f743d35dfde83ba12`.
- Dense fixture `dense-24x24-terminal-wave6-starter-v6`:
  `113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`.

Strategy phase digests:

| Strategy | Opportunity | Complication | Setback | Recovery | Completed |
|---|---|---|---|---|---|
| Commercial | `9fd06662bef502189614d05a1f3d2f711ccbbb5b73bb4053b96d2a968db1a1f8` | `0789341a2bfcdd4b10b358744ac35fd8ae80303c26441e884a840d8b1970c4bf` | `64f13d55464a6e65062861faa306b1f1cccdb828febfeb852feb81c4f35bbfac` | `bf36d78346f44932fcc759c4a227702a50887ead16eb3add38b1acbe27d40c3e` | `e47199e1328ab10817b5bda3647753b585b8005ce0c14eca161d2f3336637da6` |
| Industrial | `2188b29bf14b4948e9dbf7fed81257247ba145d5e63d1ca42b1c8791b4212b16` | `bb7ca9a0e7a58d0c12b007c709bdc5a541f90615aa958f1721c69359abde506b` | `dc95ec8e596d30a44072f0d524f8b51004bcfaaf2119b799aa4fdd3e2832847c` | `4d242e6f14733ac36d3b48c33611107340dcc1324e5522d8d5f822dc53036b58` | `778f10a148d8f742fe3205d0a7c5ba3366c8f26d731cd549861ec8ccef91b632` |

Recovery and terminal digests:

| Resolution | Tick-260 recovery | Tick-844 terminal |
|---|---|---|
| Commercial tax relief | `247af502c64b0dee64faea37926ddb2cd5894b55a9219b6f1b9eeadf4713324a` | `53658735f410722d3b123f2d68bc4d85c4c4ae93847ae213e44577d101ea7b7c` |
| Commercial public realm | `5e417b4561f0d217ce5599ef9069d43a6b35005f739eddb0e0b56ab6e02d5bdd` | `157001094cf3fe9209cc47faef265ab627e3833b2a33ff180e0ffc9bb05f8e8f` |
| Industrial utility expansion | `8b25ff0315ade1379c369973e653e21b5cfc3afe6ec39dbbec0b7b4ec1718073` | `6c15af94cd9430e78e4fb09894ca4592c322daf90d0622b550b474f379683b34` |
| Industrial green buffer | `232d962b7c66d1306ffd357de91a5cc745ac543b6887decadbcb0611dbdcbff9` | `66432973b84648ee55f8051564de8de53180ce48485316117fa34509376e1653` |

## Deterministic story corpus

The existing test-only writer generated the complete corpus independently into:

- `/private/tmp/citysim-play048-fixture-a.oRJXmE`;
- `/private/tmp/citysim-play048-fixture-b.AgBKC4`.

Each writer invocation first built the corpus twice internally. `diff -ru`
reported no difference between the two output roots. The adopted manifest
SHA-256 is
`3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0`.

| Fixture | Bytes | State digest | Spatial digest | File SHA-256 |
|---|---:|---|---|---|
| Commercial opening | 131989 | `530659316df479f38bdb9a2ba3ba20e17699ed376ac0999610f3c8cb9c4d99e6` | `44ac118d7ca019c22e30d226f962a1bcbaef0ccb97bc1a682c67fb52e8080658` | `d19b5e6b27af6133ec90548cd480d3707c4a3e693dfb34e49585d044cd4a0e0a` |
| Commercial complication | 132976 | `2a1b046eb21665206709415e3a1363aeaa0a9a4a60e83e1e1b52ae3c53b50ad4` | `9ad043823a6276777001336e44422b5bfc8d22bfbcf92db10757db8efc507bb0` | `fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a` |
| Commercial recovery | 132846 | `2af6837e2176398673565c1ec893d77c29fe67505239d4234539baa3b053d1ff` | `115bc46a7fb232e5109dcc34cf6740ea89ae90edddeae18f00aebc22baace107` | `d3620bdee148cc0093e7303890df3facba7914208f39079affc29fc882e2e1b4` |
| Commercial victory | 133159 | `58afce6edf8959ab62b9cfaf4e51157c7ba9de45280b2cff893a3b775e868e59` | `f57327ffcc1ebd13d6470730129590e435da8229e970e06a09a854702b60461c` | `4df448848a8fa71a536df60d3fcf9a8d0c096025bc7d04cfcb6af5ad8f772c60` |
| Industrial opening | 131964 | `e603582568908a8acd9cd5e2143b2a86d32e58ae79f59b62fb4cb739e552ce05` | `7c402b624d8f9736ec0a0e3d18c3dbf2350290c44943b25ab20211cf7f1a1bd5` | `b6fb32abafca99592a5ad5f0e7312c0cad7520c556c4b785e19e8894936ce0d3` |
| Industrial complication | 132974 | `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a` | `41ef511b0613a33ae643e60b2a934a5a11edbf14a99a422d3f635c9f133fe7e5` | `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7` |
| Industrial recovery | 132868 | `3ca0fc2094f85dd3dcabfab46cfe51039c927cd5cf44bad07b4f9d8c55b1accc` | `aede3a00ae0c880f8ec84c0c1e5ecb13ab656b04f7ed72e8579b7f9fbbc03a90` | `a9c3e22db19c9c880178b5928e2af867b5de67e2dec686357b845194dd00d411` |
| Industrial victory | 133231 | `b1304ef634fc759ae1c0f0f5e56d4b51febb32c99f4f2cdbe3a1dd19885156f8` | `106c3950ad725469987a123164ca5be387008ff0787d13a1a95d35ae3a6f95bf` | `e5b2c53592149960400e15948518d0aaab9e9977184118d12d3a0c4e96088aab` |

Authentic inputs were not regenerated:

- schema 0:
  `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`;
- schema 1:
  `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`.

Schema remains 1 and fingerprint version remains 1.

## Platform validation and budgets

The focused platform matrix passed 42/42 in 24.521 seconds:

```text
swift test --disable-sandbox \
  --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play048-build \
  --filter '(SessionPlatformTests|StrategyResolutionPlatformTests|TerminalVictoryPlatformTests|ProductionStoryStateFixtureTests|BackupLoadAvailabilityTests|SpatialConsequenceTests)'
```

It proves primary/backup load, corrupt-primary preservation and recovery,
interrupted-write safety, exact save/resume/replay/undo, grouped-speed
equivalence, terminal immutability, legacy tick-4 normalization, immutable
analytics/spatial snapshots, and eight-state byte identity.

Measured focused results:

- corpus builds: 1,609.626 ms and 1,515.191 ms;
- story envelopes: 131,964–133,231 bytes;
- story fingerprints: 1.190–2.320 ms;
- story snapshots: 2.351–3.699 ms;
- story saves: 10.802–75.498 ms;
- story loads: 3.032–7.419 ms;
- dense simulation: 40.691 ms;
- dense fingerprint/snapshot/save/load:
  1.194 / 2.311 / 6.543 / 2.936 ms;
- dense envelope: 136,335 bytes;
- retained spatial samples: 46,080 bytes;
- spatial derivation: 1.215 ms average, 1.714 ms maximum;
- spatial events: 69.

All are below the existing 5,000 ms dense/corpus, 500 ms
fingerprint/snapshot, 1,500 ms save/load, 2 MB envelope, and 128 KiB retained
spatial ceilings.

## Integration blocker

The complete native suite required execution outside the filesystem sandbox
because AppKit tests crash at launch under the restricted runner. It executed
199 tests: 184 passed and 15 assertions failed, all in five
`WorldRenderingTests`:

1. `testEntireAuthoritativeRoadNetworkStaysPhysicalWithoutChangingHitGeometry`
   retained the former cross-road topology and terminus asset identities
   (6 assertions);
2. `testRoundOneShippingStartExportsDevelopedBoundsDefaultAndCompact`
   retained the former opening camera occupancy floor (1 assertion);
3. `testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs`
   retained former developed bounds, camera occupancy, and road-mask asset
   identities (5 assertions);
4. `testRejectedGoldenDistrictReferenceRetainsExplicitLODAssets`
   retained an exact old-opening reference predicate (1 assertion);
5. `testSpatialConsequenceProofExportsSameCityWorseningRecoveryAndCompact`
   retained a focus coordinate whose utility band/event count changed after
   the water-tower move (2 assertions).

These are renderer-owned PLAY-016 consumption assumptions. PLAY-048 explicitly
forbids changing renderer behavior or renderer tests, so this lane did not
update or bless them. `./script/build_and_run.sh --verify` and a PLAY-048
completion record were not run/created after the full-suite stop condition.
World-rendering/integration must adopt the exact authoritative topology before
PLAY-048 can rerun the full gate and close.
