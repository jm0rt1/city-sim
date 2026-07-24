# PLAY-048 Combined Runtime Closure

**Exact product candidate:** `002ed20a5419ffcdaee7adb8e7e329bff781f786`

## Accepted lineage

- Wave 006 authority:
  `e3ba50cd478f185265c9ddaad1e319ddb9475942`.
- PLAY-016 gameplay product:
  `a0ce861f7b7b5f5acbed5db63f44c18981c7f140`.
- PLAY-016 gameplay evidence:
  `274d3717ebb4b148a9af79143dc4327c12a3e5ad`.
- PLAY-016 gameplay completion:
  `f84c1bfd73d8aa01badef4064cb1b1b84a826bbe`.
- Platform merge of the frozen gameplay product:
  `461d39f5dd4fec253b261efcdb2cea5259b7ef07`.
- PLAY-048 platform fixture/fingerprint adoption:
  `29cfc272ad74ecd4de741ffe6903e09fc952d875`.
- PLAY-048 drift evidence:
  `60bf0c066cd7a5d75e399b518ae697fbd73690eb`.
- PLAY-024 world topology product:
  `a1e589e68783e25dc5788b055b3b9e786acb4b69`.
- PLAY-024 fresh-start evidence:
  `9791621c7f3a8109500d2c8567e7b2db8fa4d9b7`.
- PLAY-024 world final candidate:
  `002ed20a5419ffcdaee7adb8e7e329bff781f786`.

The world final contains exact platform evidence HEAD `60bf0c0` and normally
fast-forwarded into the clean simulation-platform branch. No conflict
resolution or additional product change was required.

## Deterministic fixture and compatibility proof

The focused platform matrix passed 42/42 in 25.248 seconds:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play048-resume-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play048-resume-swift \
  swift test --disable-sandbox \
  --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play048-resume-build \
  --filter '(SessionPlatformTests|StrategyResolutionPlatformTests|TerminalVictoryPlatformTests|ProductionStoryStateFixtureTests|BackupLoadAvailabilityTests|SpatialConsequenceTests)'
```

The matrix proves:

- stable current, phase, recovery, terminal, and dense version-1
  fingerprints;
- schema-1 primary round trips and exact schema-0/schema-1 legacy loading;
- interrupted-write preservation, corrupt-primary preservation, and validated
  backup recovery;
- exact uninterrupted/save-resume/replay/grouped-speed outcomes;
- exact undo before strategy/recovery mutations and cleared undo after load;
- immutable authoritative, analytics, and 576-sample row-major spatial
  snapshots;
- terminal immutability and legacy awarded-playing tick-4 normalization;
- bounded two-probe load availability without decode or repair.

Two independent explicit fixture exports passed 1/1 in 3.068 and 3.072
seconds:

- `/private/tmp/citysim-play048-resume-a.Z3d5uq`;
- `/private/tmp/citysim-play048-resume-b.dV9kTk`.

`diff -ru` reported no difference between those roots or between either root
and committed `Fixtures/StoryStates`. The eight-state manifest remains:

```text
3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0
```

Authentic inputs remain byte-identical:

- schema 0:
  `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`;
- schema 1:
  `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`.

`SaveGameEnvelope.currentSchemaVersion == 1` and
`CityStateFingerprint.currentVersion == 1`. No migration is required.

## Complete suite

The combined native inventory passed 199/199 in 92.923 seconds:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play048-resume-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play048-resume-swift \
  swift test --disable-sandbox \
  --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play048-resume-build
```

This includes 41/41 `WorldRenderingTests`; the five renderer-owned assumptions
recorded as blockers in `29cfc27/ADOPTION-CHECKPOINT.md` are now adopted
without changing the platform contract.

## Measured budgets

From the complete-suite run:

- corpus builds: 1,516.029 ms and 1,517.339 ms;
- story envelopes: 131,964–133,231 bytes;
- story fingerprints: 1.145–1.247 ms;
- story snapshots: 2.212–2.403 ms;
- story saves: 9.062–9.561 ms;
- story loads: 2.809–2.967 ms;
- dense simulation: 41.397 ms;
- dense fingerprint/snapshot/save/load:
  1.199 / 2.459 / 6.103 / 2.919 ms;
- dense envelope: 136,335 bytes;
- retained spatial samples: 46,080 bytes;
- spatial derivation: 1.152 ms average, 1.220 ms maximum;
- spatial diff: 0.102 ms;
- spatial events: 69;
- 1,000 load-availability checks: 2.086–2.179 ms with exactly 2,000
  existence probes per case.

Every value remains below the existing 5,000 ms dense/corpus, 500 ms
fingerprint/snapshot, 1,500 ms save/load, 2 MB envelope, 128 KiB retained
spatial, and 100 ms availability ceilings.

## Exact staged candidate

The following passed:

```text
git diff --check
bash -n script/build_and_run.sh
bash -n script/persistence_relaunch_gate.sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play048-stage-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play048-stage-swift \
  ./script/build_and_run.sh --verify
```

The staged manifest reports:

- commit: `002ed20a5419ffcdaee7adb8e7e329bff781f786`;
- candidate: `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain:
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- display name: `CitySim [Simulation w8bb1822a1e25]`;
- data root:
  `dist/test-data/simulation-platform-w8bb1822a1e25`;
- bundle:
  `dist/CitySim-simulation-platform-w8bb1822a1e25.app`;
- executable: `CitySimNative-w8bb1822a1e25`;
- manifest:
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`;
- PID: `64151`, independently confirmed alive at the exact staged executable;
- manifest status: `verified-running`.

No platform migration, renderer/HUD redesign, test-resource runtime dependency,
or legacy rewrite was introduced. The deterministic fixtures remain evidence
setup and do not replace the final no-coaching PLAY-053 player journey.
