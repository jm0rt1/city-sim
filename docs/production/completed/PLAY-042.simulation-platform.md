# PLAY-042 Completion — Durable Strategy Runtime Trust

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** final platform closure verified on accepted beauty baseline
- **Accepted beauty baseline:** `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Platform closure merge:** `970d0f8a3ad24144906760abcf1dbe184f0c3904`
- **Authority base:** `32bfafbc6d4b27f306bcfef9141488f1334235f9`
- **Gameplay source checkpoint:** `6d5df6b37cecfb35604f205cc12bf94b8e69f564`
- **Local gameplay cherry-pick:** `f9ec89a2206fcc2f11fcc3cbe9ece6e54ec3bf5b`
- **Approved contract:** CONTRACT-007; preserve save schema 1 and fingerprint version 1
- **Product/test candidate:** `e0114c18c77cc76460b84fdf1f61317bb92adb79`

## Player outcome

The durable strategy story now survives every platform boundary without becoming a second source of gameplay truth. Awaiting choice, both committed routes, every phase, exact schedule, and derived analytics remain identical across typed replay, speed grouping, save/resume, undo, backup recovery, and immutable presentation snapshots.

The platform lane adopted the gameplay-owned model and rules without changing phase timing, balance, messages, HUD, renderer, or commands. No production save service, fingerprint encoder, schema identifier, or snapshot type changed.

## Ordered commits

1. `f9ec89a2206fcc2f11fcc3cbe9ece6e54ec3bf5b` — `PLAY-013: Make strategy progression durable` (exact cherry-pick of gameplay source `6d5df6b`)
2. `0daaf1399256d30e667a123b4a743a8692f30452` — `PLAY-042: Freeze authentic legacy save fixtures`
3. `e0114c18c77cc76460b84fdf1f61317bb92adb79` — `PLAY-042: Adopt durable strategy session fixtures`
4. Completion-record commit reported in the platform handoff.

## Exact initial failure classification

The first unmodified `SessionPlatformTests` run executed 14 tests and produced 10 assertion failures, all confined to the two approved PLAY-042 adoption tests. The remaining 12 tests passed.

| Original line | Classification | Old expectation | Accepted evidence |
|---|---|---|---|
| 292 | retired opening guidance | industrial messages contain `Choose a Growth Engine` | false after durable commitment |
| 293 | relative schedule copy | `Freight Contract Watch` contains `by Day 25` | title retained; obsolete exact-day wording removed |
| 297 | retired opening guidance | commercial messages contain `Choose a Growth Engine` | false after durable commitment |
| 298 | relative schedule copy | `Main Street Crossroads` contains `by Day 25` | title retained; obsolete exact-day wording removed |
| 301 | industrial terminal fingerprint | `f8ecd67582597fc859ddc91c9de8b5b3842f702581161588d671ae06ec839e13` | `825a7c39fa1d656a6ec1a273f8b9a89ca0dc7a053d71e81eb00e281553782a7c` |
| 305 | commercial terminal fingerprint | `65ce47a635ad3305afcc8871bafb0df1ba0cf245cca0548e1873c87224edb223` | `d5b58792b70d119acc4a35344e1c1c9f141e56ab6c220a9eec20b860c2e01d18` |
| 309 | repeated industrial set | old industrial digest | same new industrial digest in all repeats |
| 313 | repeated commercial set | old commercial digest | same new commercial digest in all repeats |
| 345 | dense progression | `CityProgressionState()` | industrial opportunity committed at tick 4, next tick 68 |
| 347 | dense fingerprint | `ce5d912d97702c5a0a3b84149e432219fe9faca54dcb9b2fa98e0b5ba54f8ef7` | `149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246` |

The four copy failures and six fingerprint/state failures all follow directly from the approved persisted strategy commitment. No unrelated state discrepancy was observed. The accepted industrial and commercial fixtures still hit their exact ticks, treasuries, projected balances, permanent Charters, route-specific titles, and completed phases, and the complete gameplay authority suite passed.

## Authentic legacy compatibility

The frozen files were generated once from detached pre-PLAY-013 source commit `c3c0f4ad109791fe5a90dd120b98a9812ff685e2`. Product validation reads immutable packaged resources and never generates them.

| File | Schema | File SHA-256 | Expected version-1 state digest |
|---|---:|---|---|
| `strategy-legacy-schema0-v1.json` | 0 | `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908` | `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5` |
| `strategy-legacy-schema1-envelope-v1.json` | 1 | `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9` | `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f` |

The test target adopts only the integration-approved `.copy("Fixtures")` resource entry. Schema-0 still loads with nil progression and normalizes only on tick 4. The authentic schema-1 envelope still decodes missing strategy as nil. Both byte hashes and state digests are asserted. Schema 1 contains the same four envelope keys, and fingerprint version 1 remains authoritative.

## Frozen strategy matrix

All states below are reached by the narrow typed command boundary and real simulation steps from seed 42. Each fingerprint repeats five times, every state round-trips exactly through schema 1, and analytics agrees with persisted strategy/phase/schedule.

| Strategy | Phase | Tick | Version-1 digest |
|---|---|---:|---|
| commercial stewardship | opportunity | 4 | `2cace0ea8802121aa20b09290467151a41a50febc9f9387d173ac4ebfd87fd63` |
| commercial stewardship | complication | 68 | `fee970b179d521b263f0a88931c95afe80d3e270428abf93df0a54eeb63f2cde` |
| commercial stewardship | setback | 132 | `c9ccc91744fc55b32bc5d3bd824772e70b7043b3da5d9b72900bc05edcdf771c` |
| commercial stewardship | recovery | 196 | `f8d8d1a1ae89ed6ed34b6b0c82ef1e66a00be28676a7de2dfb598b859aaad5a0` |
| commercial stewardship | completed | 260 | `550a334c2e8d1692696e63f31c74d0be72906cf1acc648c3f3f6124e456f6232` |
| industrial expansion | opportunity | 4 | `6925de40f282ea591af88d799633ad2f49ffd6f5b86ac80e6b29fdbf4ae1fc5b` |
| industrial expansion | complication | 68 | `bf224d530d68bac4934d3ccad61edaa08eb908ce911f73d07c58c91561ac23b4` |
| industrial expansion | setback | 132 | `dccab9562ed39a8b6ceec4234058c0f907ea12da573135ebcaeeb2d374215c63` |
| industrial expansion | recovery | 196 | `57fafd73980a3dc45ada65e8432a8951c1eaa9cdab66fa393e63f2f5fa0a7609` |
| industrial expansion | completed | 260 | `c7e934c3a28bcc915491a731f1e30586af183e5e476c45b4c9c697c9507ef3eb` |

Awaiting choice remains the authentic explicit-progression fixture digest `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f`. Legacy nil progression remains distinct at `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5`.

## Runtime invariants proved

- Identical typed command replay produces exact state and fingerprint.
- Normal, fast, and fastest groupings produce the exact completed industrial state after 256 logical ticks.
- Uninterrupted and midpoint schema-1 save/resume routes produce the exact completed commercial state.
- Whole-state undo restores committed strategy, phase, schedule-derived analytics, authoritative state, and fingerprint.
- A corrupt primary remains byte-for-byte in place and in its preserved corrupt copy while the last-known-good industrial setback backup recovers exact state and fingerprint.
- A presentation snapshot retains its original industrial opportunity analytics while the mutable source advances to complication.
- Every nonnil strategy phase saves and loads without mutation.
- Existing interruption, injected-root, malformed-version, and nil-progression tests remain green.

## Golden reconciliation and performance

The dense generator itself is unchanged, but its industrial majority now commits the approved strategy at the tick-4 daily boundary. That is an intentional canonical-state change, so the fixture is renamed from `dense-24x24-terminal-wave3-v4` to `dense-24x24-terminal-wave4-strategy-v5`. It remains terminal at tick 44 / `.lost`, with the same treasury, population, jobs, and pressured workload; its additive persisted strategy is industrial opportunity with next tick 68.

Two focused repeats and the full-suite run all reproduced digest `149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246` and a 136,367-byte schema-1 envelope:

| Run | Simulation | Fingerprint | Snapshot | Save | Load | Retained samples |
|---|---:|---:|---:|---:|---:|---:|
| focused 1 | 45.090 ms | 1.943 ms | 3.086 ms | 8.183 ms | 3.490 ms | 46,080 bytes |
| focused 2 | 46.062 ms | 1.768 ms | 2.601 ms | 7.170 ms | 3.336 ms | 46,080 bytes |
| full suite | 40.674 ms | 1.320 ms | 2.413 ms | 6.870 ms | 3.096 ms | 46,080 bytes |

All remain well below the existing 5,000 ms simulation, 500 ms fingerprint/snapshot, 1,500 ms save/load, 2 MB envelope, and 128 KiB retained-sample gates. The focused spatial diagnostic also passed at 1.345 ms average / 1.475 ms maximum derivation, 0.520 ms diff, 68 events, and 46,080 retained bytes.

## Exact validation

- `swift test --package-path Native/CitySimNative --filter SessionPlatformTests`: 16 tests, 0 failures in 5.606 seconds.
- Two independent focused dense runs: 1 test each, 0 failures, identical digest and byte count.
- `swift test --package-path Native/CitySimNative --filter SpatialConsequenceTests/testAcceptedAndDenseFixturesMeetDerivationDiffAndStorageBudgets`: 1 test, 0 failures in 0.025 seconds.
- `swift test --package-path Native/CitySimNative`: 127 tests, 0 failures in 375.497 seconds.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/verify_candidate_isolation.sh`: passed.
- `./script/build_and_run.sh --verify`: built and launched exact product/test candidate `e0114c18c77cc76460b84fdf1f61317bb92adb79`.

The staged candidate used identity `simulation-platform-w8bb1822a1e25`, bundle and preference domain `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, data root `dist/test-data/simulation-platform-w8bb1822a1e25`, and exact PID 24529. The manifest recorded `status=verified-running`, and the process was independently confirmed alive at the exact staged executable. Gameplay retains ownership of the continuing causal live journey; PLAY-042 changed no player-facing composition or rules.

## Adoption, risk, and rollback

Integration should adopt the exact gameplay checkpoint and both PLAY-042 commits together. UI/input may consume only the existing derived analytics. Renderer continues to consume immutable snapshots and must not infer strategy rules. Gameplay remains sole owner of phase semantics, balance, message copy, and commands.

Rollback removes the two packaged fixture files, their manifest, the test-target resource entry, and the PLAY-042 platform assertions. The additive gameplay checkpoint can be rolled back independently only by integration. No migration, save repair, schema bump, fingerprint-version bump, or player-data rewrite is required.

## Final beauty-baseline closure

The integrated product was re-proved without product or test changes on
accepted baseline `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`.
Normal merge `970d0f8a3ad24144906760abcf1dbe184f0c3904`
preserves the lane history and has the accepted baseline as its second parent.
The sole PLAY-047 claim conflict was resolved verbatim to `origin/master`; the
post-merge tracked tree is exactly equal to `origin/master`.

The focused platform matrix passed 42/42 in 24.930 seconds. The complete
integrated inventory passed 185/185 in 83.506 seconds. Authentic schema-0 and
schema-1 bytes, every active strategy phase fingerprint, grouped-speed,
uninterrupted/save-resume/replay/undo equivalence, corrupt-primary backup
recovery, immutable analytics and spatial snapshots, all eight production
story fixtures, four terminal routes, and dense/persistence budgets remain
exact.

The dense diagnostic retained digest
`149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`,
136,367 envelope bytes, 46,080 retained spatial bytes, 41.768 ms simulation,
1.366 ms fingerprint, 2.449 ms snapshot, 6.002 ms save, and 3.018 ms load.

`./script/build_and_run.sh --verify` passed for exact merge `970d0f8`. The
isolated staged candidate PID was verified and terminated after proof. Full
commands, fingerprints, fixture identities, measurements, accepted ancestry,
and the no-new-test rationale are retained at
`docs/production/evidence/PLAY-042/970d0f8/BEAUTY-BASELINE-CLOSURE.md`.

There is no current contract risk or migration requirement. Future persisted
authoritative fields still require explicit schema/fingerprint golden review;
gameplay retains strategy rules and UI/renderer remain immutable consumers.
