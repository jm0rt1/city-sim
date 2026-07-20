# PLAY-040 Companion — PLAY-011 Fingerprint Validation

**Date:** July 20, 2026

**Platform branch:** `codex/citysim-simulation-platform`

**Integration base:** `71a113855dd41ab9d6576e3755183994a74c6118`

**Gameplay product candidate:** `dd49ea5f6d5d2ea13d726e4b5083b4b52bbefb2d`

**Frozen merged validation baseline:** `1d494dbb743d77f4e03bd8ababb9804c0eb6202e`

## Disposition

Accepted for a focused frozen-fixture update. The three changed version-1 digests reproduced exactly in an initial clean build, an incremental rerun, and a second clean scratch build. No unexplained digest, checkpoint, schema, command, tick-boundary, or serialization change was observed.

The gameplay candidate changes only `CitySimulation.swift`, `CityAnalytics.swift`, and `GameplayLoopTests.swift`. At the candidate boundary, the following platform-owned files have identical Git blobs before and after PLAY-011:

| Surface | Blob at integration base and gameplay candidate |
|---|---|
| `CityGameState.swift` | `4ca198a4323de2ea34c20dcb27ba7dc097d3f4cd` |
| `CityStateFingerprint.swift` | `b0485fc6e8a3215d1d065675f5964a7af491c124` |
| `SaveGameService.swift` | `8ebf05ab161aede03d2604587503b720a2963ec9` |
| `CitySimulationCommand.swift` | `a49055acf344f7cfcbdaee62d233793cab16ffb0` |
| pre-update `SessionPlatformTests.swift` | `00872f38227a7d65eb7312610993d6856a6adefd` |

Therefore fingerprint version 1, schema 1, nil-progression representation, and the accepted strategy command sequences are unchanged.

## Repeated digests

| Fixture | Old accepted digest | PLAY-011 digest | Reproduction |
|---|---|---|---|
| Industrial strategy, tick 896 | `46a97eaed18277108b4a911a4cb49e2d925f88784b2b6aa75fd37fcf3e6f485c` | `11adf523ca4af342d3a1126c04d3469bf3e02ddd30c8b77ea22e21c70420c5ff` | identical in 3 runs, including a separate clean scratch build |
| Commercial strategy, tick 888 | `906783b2a4332e72bb299d129d7b7deca4491f893a8293c5566358bb2fd41dd1` | `65c11403d0876fc9af27782e240a4e98b2806b55b8953aa81490934bb860f68c` | identical in 3 runs, including a separate clean scratch build |
| Dense terminal v3, tick 44 / lost | `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77` | `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8` | identical in 3 runs across two scratch builds |

The gameplay handoff prose had the two strategy labels reversed. The fixture code is authoritative: the state built with two `.industrial` commands is tick 896 / 366 jobs and produces `11adf523…`; the state built with tax 0.14 and two `.commercial` commands is tick 888 / 350 jobs and produces `65c11403…`. Assertions, diagnostics, and this evidence use that verified mapping.

The accepted dense fixture name advances from `dense-24x24-terminal-wave2-v2` to `dense-24x24-terminal-wave2-v3`; its generator, 400 step attempts, terminal tick 44, and lost status remain unchanged.

## Meaningful state deltas

PLAY-011 discounts upkeep for each reserve power plant and water tower to 75% before the existing 1.8 upkeep multiplier. One second plant and tower save `$74.25` per daily settlement. Both accepted strategy fixtures contain those reserve facilities for 220 settlements, explaining an exact `$16,335.00` treasury increase without changing population, tick, command order, schema, or seed.

| Checkpoint | Old behavior | PLAY-011 behavior | Explained delta |
|---|---:|---:|---|
| Industrial treasury, tick 896 | `$33,098.20` | `$49,433.20` | `+$16,335.00` reserve-utility discount |
| Industrial projected balance | `$236.00` | `$310.25` | `+$74.25` per settlement |
| Commercial treasury, tick 888 | `$42,058.26` | `$58,393.26` | `+$16,335.00` reserve-utility discount |
| Commercial projected balance | `$329.24` | `$403.49` | `+$74.25` per settlement |

Both strategies remain `.playing`, Town Charter-awarded at `12/true`, treasury-positive, and distinct: industry ends at population 524 / 366 jobs / 54.500 happiness; commerce ends at population 522 / 350 jobs / 55.349 happiness. Their persisted journals now include `Town Charter Standards`, and their existing warning detail says the opportunity arrives "by Day 41". These approved early guidance messages also intentionally change the digests.

The dense fixture contains 62 active power plants and 61 active water towers. Its reserve discount is `$4,497.75` per settlement across 11 daily settlements, exactly explaining its `$49,475.25` treasury delta:

- old treasury `$6,552,587.30`; PLAY-011 treasury `$6,602,062.55`;
- old projected balance `-$133,177.90`; PLAY-011 projected balance `-$128,680.15`;
- population 46,459, jobs 32,739, seed 42, tick 44, `.lost`, and progression `0/false` remain unchanged;
- schema-1 envelope grows from 135,456 to 135,864 bytes because `Town Charter Standards` is now retained in the persisted journal.

## Contract validation

The unchanged platform suite continued to prove:

- explicit progression and legacy nil progression retain distinct version-1 fingerprints;
- legacy schema-0 nil progression remains nil at ticks 1–3 and normalizes only at tick 4;
- equivalent 1x, 2x, and 3x logical tick groupings remain exactly equal;
- typed fixture commands remain Codable and bounded;
- schema-1 save/load round trips exact state and digest;
- digest mismatch preserves the corrupt primary and recovers the validated backup;
- interrupted replacement leaves the known-good primary readable;
- undo restores exact authoritative state and fingerprint;
- immutable presentation snapshots do not drift after later simulation.

## Validation commands

All Swift runs used writable scratch and module-cache paths plus `--disable-sandbox` to avoid the host's read-only pre-existing `.build` database. The stale default `.build` run was discarded because it could not compile the candidate.

```sh
swift test --disable-sandbox --scratch-path /private/tmp/citysim-play040-build --package-path Native/CitySimNative --filter SessionPlatformTests
swift test --disable-sandbox --scratch-path /private/tmp/citysim-play040-build-3 --package-path Native/CitySimNative --filter SessionPlatformTests/testAcceptedStrategyCommandsProduceFrozenCheckpoints
swift test --disable-sandbox --scratch-path /private/tmp/citysim-play040-build-3 --package-path Native/CitySimNative --filter SessionPlatformTests/testDenseSessionSimulationAndPersistencePerformance
```

After freezing v3, `SessionPlatformTests` passed 14/14. The full-suite, staged-verify, syntax, and final cleanliness results are recorded in the PLAY-040 completion addendum.
