# PLAY-069 Validation — Regional Capital Runtime Trust

- **Lane:** `codex/citysim-simulation-platform`
- **Mutation base:** `ca7c29d263e1a2554b728cfa62f0149af7427411`
- **Published rollback:** `27dd8bf4f2961b0c781755900bd60f9b866da51b`
- **Contract:** `CONTRACT-015`
- **Product/tests:** `4d9c20980d1881b775a5866effeedea5ab6aab19`
- **Date:** July 25, 2026

## Corpus contract

The authentic `v1` corpus remains eight files plus
`story-states-manifest-v1.json`. Every byte and SHA-256 is unchanged. Those
files remain the authoritative missing-`secondAct` compatibility inputs, and
the two historical `*-charter-victory-v1` states remain readable as legacy
Town Charter terminals rather than being relabeled or regenerated.

The current `v2` manifest contains twelve deterministic states:

- the six unchanged opening, complication, and recovery `v1` files;
- Commercial and Industrial Charter-midpoint `v2` files at tick 844; and
- four recovery-specific Regional Capital terminal `v2` files.

The corpus is test support only. Production has no fixture dependency.

| Current identity | Tick | Status | Fingerprint v1 |
|---|---:|---|---|
| Commercial Charter midpoint | 844 | playing | `01ccd07c28bab7fd9fe7898c90d7eb660c2826b122d215a13d6965655c38f353` |
| Industrial Charter midpoint | 844 | playing | `35d4d69ac0f7b17d442bf40fe4d6b3b442eee027c7bec0e23c4444fd0c12d768` |
| Commercial tax-relief Regional Capital | 1040 | won | `7b369309ef0a64dd8a9c0f11914fee0f94e4c9a6495639d86b356b6d4d6d2c11` |
| Commercial public-realm Regional Capital | 1060 | won | `115dc11b4d5a138387d55064773187c71c5fd85b23f76349e55225bad7dc4145` |
| Industrial utility-expansion Regional Capital | 1036 | won | `8a1de464c82480dcf5299c0903002066bd60bcebe3b533b7cf52f2ef51be3639` |
| Industrial green-buffer Regional Capital | 1236 | won | `f69193c9c472af05d4968c83d24aad7532c3dfd09620328f34f64543ea9e2cc4` |

The six new fixture SHA-256 values are, in table order:

```text
bf7d2234043ca757fd62a711d55168f9c26be646a61cb1ab9f662eb47bd69824
17040195a2c76f7bb149b6d89c22e3b3dfdf6be1325a32cca917d2555c42840b
3c9b71abd681676ed5d8acd58bb8f41e9fb88c24f95281c0f41b0b61cf144d02
2a2044f43c05cf5b87e87f1f1a4a2f75c9c222f1a812e99128859a24094a0676
78781f5bc0e989ea41cb3fed1de2a445211fa0aa0e9634173bcd8b615cb13d5d
f25bca43bf2c6506200a969eb16e3cde25cb14fc092c8f31303f621dfe334a9d
```

`story-states-manifest-v2.json` is
`a793dc9ea5cfc50b7482fb7f4bf4e7a3a3c5e9cfb1cad6e47722fc17cbf22153`.
Two independent builds reproduced every current fixture byte exactly; corpus
construction measured 5,952.581 ms and 5,876.260 ms.

## Authentic compatibility

The following authentic hashes stayed frozen:

```text
schema-0 JSON   28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908
schema-1 JSON   56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9
v1 manifest     3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0
```

All eight historical fixture file hashes also repeated exactly. Schema remains
1 and fingerprint version remains 1. Missing `secondAct` continues to decode
as `nil`; no authentic input was rewritten.

## Deterministic platform proof

The focused matrix covered:

```text
SessionPlatformTests
TerminalVictoryPlatformTests
ProductionStoryStateFixtureTests
SpatialConsequenceTests
```

Result: **39/39 passed, 0 failures, 48.199 seconds**.

It proves:

- all four recovery routes construct the exact terminal tick, strategy,
  recovery resolution, Regional Capital award, and one recognition message;
- uninterrupted replay and grouped `1/2/4` speed execution agree;
- exact save/load and corrupt-primary last-known-good backup recovery agree;
- load pauses simulation, clears undo, preserves corrupt primary bytes, and
  reports the existing recovery feedback;
- pre-terminal mutation followed by undo returns to the exact fingerprint;
- terminal commands and another 128 simulation steps reject or remain
  immutable;
- presentation analytics and row-major spatial snapshots retain the exact
  strategy, resolution, terminal, coordinate, diagnostic, and local-activity
  identities; and
- both historical Charter terminals and all current states remain loadable.

The dense diagnostic fixture remains tick 44 / lost with fingerprint
`113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`,
136,335 save bytes, 92,160 retained spatial bytes, and existing recovery
semantics.

## Budgets

Across the focused run:

- Regional saves: 131,964–133,838 bytes, below 2 MB;
- fingerprints: at most 1.5 ms, below 500 ms;
- immutable snapshots: at most 3.8 ms, below 500 ms;
- saves: at most 13 ms, below 1,500 ms;
- loads: at most 14.4 ms, below 1,500 ms;
- spatial derivation: 2.490 ms average / 3.402 ms maximum;
- complete spatial snapshot: 4.212 ms average / 6.078 ms maximum;
- retained spatial samples: 92,160 bytes.

Dense simulation/fingerprint/snapshot/save/load measured
42.453 / 1.252 / 4.712 / 7.046 / 2.795 ms. Existing size, timing, and memory
gates remain satisfied.

## Complete-suite disposition

The exact host-access native run executed 234 tests in 185.972 seconds.
Every platform-owned case passed. Eight assertion failures occur across three
dependent test cases:

1. `CityCommandCatalogTests.testDiagnosisConsumesExactSpatialSnapshotAndAuthoredNoticeInventoryHasHonestActions`
   reports six UI-owned inventory/action-disposition assertions. The four new
   missing dispositions are `Regional Retail Challenge`,
   `Regional Grid Mandate`, `Regional Freight Overload`, and
   `Regional Retail Pressure`.
2. `CityCommandCatalogTests.testStrategyHUDConsumesEveryFrozenStoryMomentFromAuthoritativeAnalytics`
   expects the historical eight-state corpus but now receives twelve.
3. `WorldRenderingTests.testGoldenNeighborhoodShippingRendererExportsThreeLODsAndCompact`
   reports historical cold-update time 7.197374943643808 seconds above its
   6.03-second renderer ceiling.

These are disclosed adoption gates, not platform contract failures. No UI,
renderer, HUD, gameplay, package, or build-script file was changed.

## Exact staged runtime

`./script/build_and_run.sh --verify` built and launched exact product commit
`4d9c20980d1881b775a5866effeedea5ab6aab19`:

- candidate `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- display name `CitySim [Simulation w8bb1822a1e25]`;
- isolated data root
  `dist/test-data/simulation-platform-w8bb1822a1e25`;
- exact executable
  `dist/CitySim-simulation-platform-w8bb1822a1e25.app/Contents/MacOS/CitySimNative-w8bb1822a1e25`;
- manifest
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`;
- PID 20487, confirmed alive at the exact executable;
- manifest status `verified-running`.

The isolated root retained byte-identical primary and backup schema-1 saves
with file SHA-256
`3c9b71abd681676ed5d8acd58bb8f41e9fb88c24f95281c0f41b0b61cf144d02`
and state digest
`7b369309ef0a64dd8a9c0f11914fee0f94e4c9a6495639d86b356b6d4d6d2c11`.
They identify the won Commercial tax-relief terminal. Only PID 20487 was
terminated after proof.

`git diff --check`, staged diff checking, and Bash syntax checks for the
existing build and persistence relaunch scripts passed.

## Stop boundary and consumers

Renderer, HUD, and quality consumers should use the `v2` manifest for current
Regional Capital evidence setup. The `v1` manifest remains the authentic
missing-`secondAct` compatibility corpus and must not be used as current
terminal truth. Neither corpus replaces the no-coaching player journey.

PLAY-069 changes no production gameplay, schema/fingerprint version, saved
model, save service, UI, renderer, command, package, build script, or legacy
Python. Integration must route the disclosed UI/renderer failures to their
owning lanes rather than changing the platform corpus back to eight states.
