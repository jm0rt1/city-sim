# PLAY-040 Completion — Trustworthy Session Platform and Isolated Apps

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready-for-integration
- **Baseline:** `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- **Approved contracts:** `CONTRACT-003`, `CONTRACT-004`

## Player outcome

CitySim sessions now have a canonical version-1 state fingerprint, a versioned and validated save envelope, a last-known-good backup, explicit recovery reporting, exact undo/load behavior, and isolated worker-app identities. A corrupt primary is preserved for diagnosis and never silently accepted; the player can recover the previous valid city. Legacy bare-state saves remain readable, including the accepted missing-progression behavior through ticks 1–3 and normalization at tick 4.

Worker candidates no longer share the production bundle identifier, preferences, save root, staged path, or ambiguous process target. `master` remains the compatibility anchor with `com.jfmortensen.citysim`, `CitySim`, `dist/CitySim.app`, and the existing Application Support save location.

## Ordered commits

1. `34ce82d8af87202aabcbdec4d3966d7c426d75a2` — `PLAY-040: Freeze canonical session fingerprints`
2. `885259d65edb848c4b542319fa2fe0c6614559ff` — `PLAY-040: Recover versioned session saves`
3. `82298e44d25efc76683b09d92b0696c006293e3c` — `PLAY-040: Bound deterministic fixture snapshots`
4. `c751c93877e51fd99d39a5ab99369f1d981d052a` — `PLAY-040: Isolate staged lane applications`
5. `822755cbad5431d868547e3d38d41e8df14e715f` — `PLAY-040: Measure dense session performance`

## Exact files changed

- `Native/CitySimNative/Sources/CitySimNative/Models/CityPresentationSnapshot.swift`
- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulationCommand.swift`
- `Native/CitySimNative/Sources/CitySimNative/Services/CityStateFingerprint.swift`
- `Native/CitySimNative/Sources/CitySimNative/Services/SaveGameService.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift`
- `script/build_and_run.sh`
- `script/verify_candidate_isolation.sh`
- `docs/production/completed/PLAY-040.simulation-platform.md`

Legacy Python, gameplay balance, progression rules, HUD composition, renderer behavior, and package topology were not changed.

## Deterministic fixtures and contracts

- Canonical fingerprint version 1 uses sorted-key JSON and lowercase SHA-256 over the complete persisted `CityGameState`.
- `progression == nil` remains distinct from an explicit zero-value `CityProgressionState`.
- Seed-42 explicit progression digest: `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f`.
- Seed-42 legacy nil-progression digest: `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5`.
- Wave 002 industry checkpoint at tick 896: `46a97eaed18277108b4a911a4cb49e2d925f88784b2b6aa75fd37fcf3e6f485c`.
- Wave 002 commerce checkpoint at tick 888: `906783b2a4332e72bb299d129d7b7deca4491f893a8293c5566358bb2fd41dd1`.
- Equivalent 1x, 2x, and 3x tick groupings produce the exact same state and fingerprint after 120 logical ticks.
- `CityPresentationSnapshot` owns an immutable state value and matching fingerprint plus derived analytics.
- `CitySimulationCommand` is deliberately limited to build, demolish, tax rate, and one daily boundary for deterministic PLAY-010 fixtures.

## Save, migration, recovery, and undo

- Schema 1 contains exactly `schemaVersion`, `fingerprintVersion`, `state`, and `digest`.
- Schema-0 bare `CityGameState` remains readable without mutating optional progression during load.
- Saves write and validate a temporary candidate, retain a validated last-known-good backup, and atomically replace the primary.
- Invalid primaries remain byte-for-byte in place and are copied to a uniquely named `*.corrupt-*.json` artifact before backup recovery.
- `SaveGameLoadResult.source` explicitly identifies primary versus backup recovery; the store reports recovered state to the player.
- Interrupted replacement leaves the prior primary readable and fingerprint-exact.
- Save roots are injectable and honor `CITYSIM_DATA_ROOT`; all artifacts stay within that root.
- Whole-state undo restores the exact authoritative state and fingerprint. Loading clears undo history as before.

## Automated validation and measured performance

- Complete native suite: 59 tests, 0 failures in 31.538 seconds.
- Session platform suite: 14 tests, 0 failures in 2.076 seconds.
- Pre-PLAY-011 `dense-24x24-terminal-v1` generator at 50,000 residents, 400 step attempts, terminal tick 44 / `.lost`:
  - simulation: 40.004 ms;
  - fingerprint: 1.370 ms;
  - schema-1 save: 6.712 ms;
  - validated load: 3.170 ms;
  - envelope size: 135,456 bytes;
  - historical pre-PLAY-011 digest: `fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5`.
- Existing renderer diagnostic remained healthy: ten unchanged pulses averaged 1.830 ms, reused 5,760 tile roots, and rebuilt 0.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Master and worker `--print-identity` shell checks passed, including explicit `CITYSIM_TEST_ISOLATION=1` behavior on master.
- `./script/build_and_run.sh --verify`: built and launched the exact Simulation candidate at full commit `822755cbad5431d868547e3d38d41e8df14e715f`.

### Wave 002 integration reconciliation

After PLAY-011, PLAY-020, and PLAY-030 were combined on integration candidate `f0e73b92a32b6623282d4fb30e188932a2a04cb8`, the two strategy checkpoint digests changed under the accepted PLAY-011 simulation semantics. Both replacement digests above repeated exactly in integration's direct run and two independent platform-lane replays. No fixture command, fingerprint version, save schema, or persisted field changed in the repair.

The authoritative PLAY-011 horizon test passed at exact tick 2,800 for both strategies: industry ended with population 560, treasury $156,279, 392 jobs, 53.867 happiness, 499 power use, and 438 water use; commerce ended with population 700, treasury $63,698.60, 350 jobs, 53.329 happiness, 588 power use, and 528 water use. Both retained permanent Town Charters and `.playing` status.

Reconciliation validation:

- `SessionPlatformTests`: 14 tests, 0 failures in 2.351 seconds.
- Complete integrated suite: 78 tests, 0 failures in 38.561 seconds.
- Dense 24x24 diagnostic before the frozen-golden repair: 400 step attempts, terminal tick 44 / `.lost`, fingerprint `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.
- Nil-versus-zero progression fingerprints, legacy tick-4 normalization, schema-0/schema-1 compatibility, corrupt-primary recovery, interrupted-write safety, exact undo, immutable snapshots, and equivalent speed grouping all remained green.

### Wave 002 dense-fixture contract repair

An independent replay of pre-PLAY-011 commit `822755cbad5431d868547e3d38d41e8df14e715f` reproduced `fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5`. Instrumentation also proved the original `ticks=400` label was inaccurate: the 400 loop iterations were step attempts, while the authoritative dense state reached `.lost` at tick 44 and all later calls were no-ops.

The generator itself did not change. PLAY-011 intentionally added commercial/industrial expansion utility load, which changes persisted utility, happiness, approval, demand, and related state before the same tick-44 terminal checkpoint. Canonical fingerprint encoding and fingerprint version 1 did not change. The semantically changed checkpoint is therefore named `dense-24x24-terminal-wave2-v2` and frozen at:

`7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`

`SessionPlatformTests.testDenseSessionSimulationAndPersistencePerformance` now publishes the versioned fixture name and asserts final tick 44, `.lost` status, and the exact digest before validating schema-1 save/load equality. Two independent focused repair runs reproduced the digest exactly:

- run 1: simulation 45.635 ms, fingerprint 1.893 ms, save 7.411 ms, load 3.267 ms, 135,456 bytes;
- run 2: simulation 43.934 ms, fingerprint 1.743 ms, save 7.604 ms, load 3.240 ms, 135,456 bytes.

Repair validation passed 14/14 SessionPlatformTests in 2.679 seconds and the complete 78-test suite in 42.132 seconds. The full run reproduced the same digest a third time. The old `fe710ac9…` value remains valid historical evidence only for pre-PLAY-011 terminal fixture v1; it is not the Wave 002 golden state.

## Live two-candidate isolation proof

At 2026-07-20 00:49–00:51 UTC, two tracked candidates from the same full commit were staged and operated simultaneously:

- Simulation: `com.jfmortensen.citysim.simulation-platform`, `CitySim [Simulation]`, PID 16880, root `dist/test-data/simulation-platform`, exact executable `dist/CitySim-simulation-platform.app/Contents/MacOS/CitySimNative`.
- Quality: `com.jfmortensen.citysim.playtest-quality`, `CitySim [Quality]`, PID 19327, root `/tmp/citysim-play040-two-app.6S3Zi1/quality-candidate/dist/test-data/playtest-quality`, exact executable `dist/CitySim-playtest-quality.app/Contents/MacOS/CitySimNative` in the disposable clone.

Both manifests recorded branch, full commit, bundle identifier, display name, root, UTC launch time, staged bundle path, exact executable, PID, and verified-running status. `ps` showed both exact executable paths alive simultaneously.

The preference domains held intentionally opposite values for onboarding, Reduce Motion, and renderer diagnostics, proving the domains did not alias. Invoking **Save City** through the exact Simulation PID created only its root's `quicksave.json`; the Quality root remained empty. Invoking **Save City** through the exact Quality PID then created its independent save. Both were schema 1 / fingerprint version 1:

- Simulation save: 131,908 bytes, envelope digest `83a2a7ef8adb2a93a5015260d4a68fb26e356a81e0667424106e84683c2ca63e`, file SHA-256 `b50930a5bf6a83d277d7b523ce8354e706b42d32b822f75d97c07dda93d84f26`.
- Quality save: 131,910 bytes, envelope digest `997a0bf59f92eaa0402525d2713886582ad8946cc4ac71431aaeb7b2ccd1b5c9`, file SHA-256 `45f77c988816a87695da8df681bea7bf5a93b070256fbd5a7204b0255dddd2f7`.

The real staged windows were positioned side by side and remained responsive through the exact-menu save actions. macOS denied `screencapture` with `could not create image from display`, so no screenshot artifact is claimed; process, manifest, preference, and real save evidence above came directly from both running bundles.

### CONTRACT-004 same-lane worktree repair

PLAY-050 correctly rejected candidate `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209` after finding an already-running Quality candidate at PID 59491 with the same `com.jfmortensen.citysim.playtest-quality` preference domain and `CitySim [Quality]` display identity. Lane-only naming isolated different lanes but did not isolate two worktrees on the same lane.

Worker identity now includes a deterministic token derived from the canonical worktree root. That token is part of the candidate ID, bundle identifier/preference domain, visible display name, staged bundle path, executable name, data root, and manifest path. Exact process management still compares the full staged executable path. Master remains unchanged at `com.jfmortensen.citysim`, `CitySim`, `CitySimNative`, `dist/CitySim.app`, and the production-default data root.

`script/verify_candidate_isolation.sh` is the durable collision regression. It builds and launches two copies of the same worker branch and commit from distinct roots, verifies each plist against its manifest, requires every identity/root/path/PID dimension to differ, and proves both exact executable paths remain alive after the second launch.

Repair proof used two disposable Simulation worktrees from integration baseline `b8cb4740b9cf94aa04482539f9909ffb22dbdbea`:

- candidate one: token `w5327352f86b3`, bundle/preference domain `com.jfmortensen.citysim.simulation-platform.w5327352f86b3`, display `CitySim [Simulation w5327352f86b3]`, PID 84122, root `/private/tmp/citysim-play040-isolation.yzYs2g/candidate-one/dist/test-data/simulation-platform-w5327352f86b3`;
- candidate two: token `w92219c0152a2`, bundle/preference domain `com.jfmortensen.citysim.simulation-platform.w92219c0152a2`, display `CitySim [Simulation w92219c0152a2]`, PID 84191, root `/private/tmp/citysim-play040-isolation.yzYs2g/candidate-two/dist/test-data/simulation-platform-w92219c0152a2`.

Both candidates remained alive simultaneously. Their preference domains retained opposite `PLAY040IsolationProbe` values, and exact-PID **Save City** actions created independent `quicksave.json` files under only their injected roots. Focused validation passed 14/14 SessionPlatformTests; the complete suite passed 78/78 and reproduced dense fixture `dense-24x24-terminal-wave2-v2` at tick 44 / `.lost` with digest `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`. External Quality PID 59491 remained alive at its original executable path before and after the proof and was never targeted. A separate master-branch identity check reproduced the canonical production values above.

## Compatibility, adoption, and rollback

- CONTRACT-001's optional progression field is authoritative in version-1 fingerprints without changing PLAY-010's tick-4 legacy normalization.
- PLAY-011 and PLAY-050 may use `CitySimulationCommand` only for deterministic fixtures; it is not a general replay or player-command framework.
- PLAY-020 and PLAY-030 may consume `CityPresentationSnapshot` without mutating or duplicating authoritative state.
- PLAY-050 should rerun its independent save/resume, corrupt-primary recovery, onboarding, Reduce Motion, diagnostics, and two-instance acceptance using only its isolated root.
- Integration should take the five implementation commits in order, then this completion record commit. No lane commit changes `master` production identity or default save location.
- Rollback may discard worker `dist/` state. Production preferences and Application Support saves are not migration targets and were not touched by the worker script.

No shared-contract collision remains. The implementation stays within CONTRACT-003 and CONTRACT-004 and is ready for integration review.
