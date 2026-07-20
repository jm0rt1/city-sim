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
- `docs/production/completed/PLAY-040.simulation-platform.md`

Legacy Python, gameplay balance, progression rules, HUD composition, renderer behavior, and package topology were not changed.

## Deterministic fixtures and contracts

- Canonical fingerprint version 1 uses sorted-key JSON and lowercase SHA-256 over the complete persisted `CityGameState`.
- `progression == nil` remains distinct from an explicit zero-value `CityProgressionState`.
- Seed-42 explicit progression digest: `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f`.
- Seed-42 legacy nil-progression digest: `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5`.
- Accepted industry checkpoint at tick 896: `556c2426cbc1841787e0611fbf253718ae0a2b528d96e22471c9c6ab12e1d8b4`.
- Accepted commerce checkpoint at tick 888: `e2127b28c3c5e3e9684be704f9dd15d4a38457ea5ccf9d5fb1745b00cefae691`.
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
- Dense deterministic 24x24 fixture at 50,000 residents, 400 ticks:
  - simulation: 40.004 ms;
  - fingerprint: 1.370 ms;
  - schema-1 save: 6.712 ms;
  - validated load: 3.170 ms;
  - envelope size: 135,456 bytes;
  - final digest: `fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5`.
- Existing renderer diagnostic remained healthy: ten unchanged pulses averaged 1.830 ms, reused 5,760 tile roots, and rebuilt 0.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Master and worker `--print-identity` shell checks passed, including explicit `CITYSIM_TEST_ISOLATION=1` behavior on master.
- `./script/build_and_run.sh --verify`: built and launched the exact Simulation candidate at full commit `822755cbad5431d868547e3d38d41e8df14e715f`.

## Live two-candidate isolation proof

At 2026-07-20 00:49–00:51 UTC, two tracked candidates from the same full commit were staged and operated simultaneously:

- Simulation: `com.jfmortensen.citysim.simulation-platform`, `CitySim [Simulation]`, PID 16880, root `dist/test-data/simulation-platform`, exact executable `dist/CitySim-simulation-platform.app/Contents/MacOS/CitySimNative`.
- Quality: `com.jfmortensen.citysim.playtest-quality`, `CitySim [Quality]`, PID 19327, root `/tmp/citysim-play040-two-app.6S3Zi1/quality-candidate/dist/test-data/playtest-quality`, exact executable `dist/CitySim-playtest-quality.app/Contents/MacOS/CitySimNative` in the disposable clone.

Both manifests recorded branch, full commit, bundle identifier, display name, root, UTC launch time, staged bundle path, exact executable, PID, and verified-running status. `ps` showed both exact executable paths alive simultaneously.

The preference domains held intentionally opposite values for onboarding, Reduce Motion, and renderer diagnostics, proving the domains did not alias. Invoking **Save City** through the exact Simulation PID created only its root's `quicksave.json`; the Quality root remained empty. Invoking **Save City** through the exact Quality PID then created its independent save. Both were schema 1 / fingerprint version 1:

- Simulation save: 131,908 bytes, envelope digest `83a2a7ef8adb2a93a5015260d4a68fb26e356a81e0667424106e84683c2ca63e`, file SHA-256 `b50930a5bf6a83d277d7b523ce8354e706b42d32b822f75d97c07dda93d84f26`.
- Quality save: 131,910 bytes, envelope digest `997a0bf59f92eaa0402525d2713886582ad8946cc4ac71431aaeb7b2ccd1b5c9`, file SHA-256 `45f77c988816a87695da8df681bea7bf5a93b070256fbd5a7204b0255dddd2f7`.

The real staged windows were positioned side by side and remained responsive through the exact-menu save actions. macOS denied `screencapture` with `could not create image from display`, so no screenshot artifact is claimed; process, manifest, preference, and real save evidence above came directly from both running bundles.

## Compatibility, adoption, and rollback

- CONTRACT-001's optional progression field is authoritative in version-1 fingerprints without changing PLAY-010's tick-4 legacy normalization.
- PLAY-011 and PLAY-050 may use `CitySimulationCommand` only for deterministic fixtures; it is not a general replay or player-command framework.
- PLAY-020 and PLAY-030 may consume `CityPresentationSnapshot` without mutating or duplicating authoritative state.
- PLAY-050 should rerun its independent save/resume, corrupt-primary recovery, onboarding, Reduce Motion, diagnostics, and two-instance acceptance using only its isolated root.
- Integration should take the five implementation commits in order, then this completion record commit. No lane commit changes `master` production identity or default save location.
- Rollback may discard worker `dist/` state. Production preferences and Application Support saves are not migration targets and were not touched by the worker script.

No shared-contract collision remains. The implementation stays within CONTRACT-003 and CONTRACT-004 and is ready for integration review.
