# PLAY-044 Implementation Checkpoint — Durable Recovery Runtime Trust

**Date:** July 22, 2026

**Lane:** Simulation platform

**Authority:** PLAY-043 closure plus CONTRACT-009

**Gameplay source commits:** `2deb594948e03bf922db9cb8d026baed3b034c14`, then `227587caca861444d55a828e1e4f0e7a67b764eb`

**Local gameplay adoption:** `10023e5aadaaddb6d64d265e66638d4710eb9a37`, then `e02d2c06a329b0bd3b2d758067a968bb22bc1acc`

**Platform checkpoint:** `705fc5179cf75c386e0dc5817b24d80cfc1bb20d`

## Initial failure classification

The first unchanged `SessionPlatformTests` run executed 16 tests. Fifteen test cases passed; `testAcceptedStrategyCommandsProduceFrozenCheckpoints` produced two assertions for one changed Industrial digest:

- actual `9640c2d5b481e6c257657b3f0a2b7eaf121cb9a44eaba1888b5728a7b83a53be` versus pre-resolution `825a7c39fa1d656a6ec1a273f8b9a89ca0dc7a053d71e81eb00e281553782a7c`;
- the five-repeat set contained the same new digest versus the prior singleton set.

The accepted Industrial fixture intentionally qualifies for `industrialUtilityExpansion`. Its tick 896, treasury 56,433.2, projected balance 310.25, Town Charter, messages, population, jobs, happiness, approval, utilities, and status were unchanged. The platform assertion now requires the typed resolution and its derived analytics before adopting the new digest. The accepted Commercial checkpoint still has nil resolution and retains digest `d5b58792b70d119acc4a35344e1c1c9f141e56ab6c220a9eec20b860c2e01d18`.

No other platform golden changed. Authentic schema-0/schema-1 legacy bytes, nil-progression digests, every nil-resolution strategy-phase digest, and the dense v5 fixture all remained exact.

## Frozen resolution matrix

Each fixture starts from seed 42, commits its strategy at tick 4, reaches setback at tick 132, applies the typed qualifying command, captures the first resolution at tick 196, and completes at tick 260. Every fingerprint is version 1 and repeated five times.

| Resolution | Version-1 digest | Schema-1 bytes in full-suite run |
|---|---|---:|
| Commercial tax relief | `a6c0aec6b0469fb8f9962bdaf4ec4304f66ed4ad64d26fc8eb6de88db5e436f2` | 132,966 |
| Commercial public-realm investment | `9ce0951b499e8885ccafd3e0dd135b98a8e8ce9d75bb4481c39732391b6ac37e` | 132,945 |
| Industrial utility expansion | `2b674038ceb42f2abf506bf438010504184cc19890aa60ec37be2f7b452b7697` | 132,585 |
| Industrial green buffer | `4a3585f2ba00ce4c311b071d2af0ea185716b236c1225990d172e509260a283f` | 132,587 |

The schema-1 envelope remains unchanged. Resolved strategies encode only the additive `recoveryResolution` key. Pre-resolution strategy saves omit that key, load nil without normalization, preserve their exact state, and retain fingerprint version 1. Authentic frozen resources remain:

- schema 0 SHA-256 `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`, state digest `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5`;
- schema 1 SHA-256 `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`, state digest `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f`.

Schema 0 still normalizes progression only at tick 4. Neither save schema 1 nor fingerprint version 1 changed.

## Runtime invariants

For all four resolutions, dedicated platform tests prove:

- independent typed command replay produces exact state and fingerprint;
- normal, fast, and fastest tick grouping produce the same tick-260 completed state;
- uninterrupted and midpoint schema-1 save/resume outcomes are exact;
- corrupt primaries remain byte-for-byte in place and in their preserved corrupt copy while the last-known-good resolved backup recovers exact state and fingerprint;
- whole-state undo returns the exact pre-investment state, fingerprint, and nil resolution after later capture/completion;
- immutable presentation snapshots retain exact recovery-phase state, fingerprint, phase, and derived typed resolution after the mutable source completes;
- resolved analytics equals the authoritative persisted value.

## Measurements

Full-suite resolution measurements:

| Resolution | Fingerprint | Snapshot | Save | Load | Bytes |
|---|---:|---:|---:|---:|---:|
| Commercial tax relief | 1.615 ms | 2.267 ms | 6.158 ms | 2.813 ms | 132,966 |
| Commercial public realm | 1.327 ms | 2.259 ms | 6.250 ms | 2.961 ms | 132,945 |
| Industrial utilities | 1.369 ms | 2.249 ms | 6.033 ms | 2.888 ms | 132,585 |
| Industrial green buffer | 1.248 ms | 2.271 ms | 5.994 ms | 2.932 ms | 132,587 |

All are below the existing 500 ms fingerprint/snapshot, 1,500 ms save/load, and 2 MB envelope budgets.

The unchanged dense v5 fixture reproduced digest `149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`, 136,367 bytes, 43.910 ms simulation, 1.309 ms fingerprint, 2.923 ms snapshot, 6.529 ms save, 3.237 ms load, and 46,080 retained sample bytes. No dense golden changed.

## Exact validation

- First unchanged `SessionPlatformTests`: 16 tests, 2 expected assertions for one Industrial resolution digest.
- `StrategyResolutionPlatformTests`: 5 tests, 0 failures in 5.997 seconds (focused adoption run).
- Reconciled `SessionPlatformTests`: 16 tests, 0 failures in 4.806 seconds.
- `GameplayLoopTests`: 29 tests, 0 failures in 13.580 seconds.
- `swift test --package-path Native/CitySimNative`: 142 tests, 0 failures in 379.365 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/verify_candidate_isolation.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `git diff --check`: passed.
- `./script/build_and_run.sh --verify`: staged and launched exact candidate `705fc5179cf75c386e0dc5817b24d80cfc1bb20d` as PID 97131.

The staged identity was `simulation-platform-w8bb1822a1e25`, bundle/preference domain `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, and isolated root `dist/test-data/simulation-platform-w8bb1822a1e25`. Cmd-O loaded the retained pre-PLAY-014 schema-1 Commercial save at Day 10, paused, with `City loaded · Simulation paused`; exact PID 97131 was then terminated and confirmed absent.

## Boundaries and adoption

No gameplay rule, phase semantic, balance value, message, HUD, renderer, command, save service, schema identifier, fingerprint algorithm, or production resource changed in the platform checkpoint. Integration must adopt both gameplay commits before `705fc51`. UI and rendering may consume the typed analytics value only after integration accepts this ordered candidate.
