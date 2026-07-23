# PLAY-047 Completion — Frozen Production Story-State Fixtures

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Authority:** `39980d753a566a2a4ea68e320f059d8046d051b7`
- **Preserved PLAY-046 head:** `d89e2a91372d0a5dc36e9398309b3a29e0fd45ae`
- **Authority merge:** `2595efc23933599f07995f02d67ac8f408bd5e0f`
- **Fixture/test commit:** `308b3026d4f8d25485dd93d2808b5c7fe654d9eb`
- **Evidence/consumer commit:** `8d0224fff90585b2c43f7a9d795f1853891d5954`
- **Completion-record commit:** reported in the platform handoff

## Outcome

Renderer, HUD, and quality now share eight committed production story moments:
Commercial and Industrial opening, complication, recovery, and Charter
victory. A test-owned deterministic builder reaches each state through the
accepted seed-42 gameplay path and writes its schema-1 envelope only through
the production `SaveGameService`.

The compact manifest freezes each name, strategy, moment, tick, schema,
fingerprint version, fingerprint-v1 state digest, spatial-v1 digest, file byte
count, and file SHA-256. Two independent complete builds are byte-identical,
and committed resources must match both builds exactly.

## Changed surfaces

Test-only builders and contract coverage:

- `Native/CitySimNative/Tests/CitySimNativeTests/ProductionStoryStateFixtureSupport.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/ProductionStoryStateFixtureTests.swift`

Frozen test resources:

- `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/`

Evidence and consumer contract:

- `docs/production/evidence/PLAY-047/308b302/FIXTURE-CORPUS.md`
- `docs/production/evidence/PLAY-047/308b302/CONSUMER-PATHS.md`
- `docs/production/claims/PLAY-047.simulation-platform.md`
- `docs/production/completed/PLAY-047.simulation-platform.md`

No shipping source, gameplay rule, outcome, event, message, schema identifier,
fingerprint version, authentic legacy byte, renderer, HUD, build script,
package topology, debug menu, or replay architecture changed. Legacy Python
remained untouched.

## Frozen state identities

The manifest freezes:

| Story state | Tick | Fingerprint-v1 digest |
|---|---:|---|
| Commercial opening | 64 | `3ae32cf46bff29d5d9ffb9ecc8de0ea78d7d002fec0058a784b43c3410d11772` |
| Commercial complication | 128 | `ac0e7cb4c690df2854f2f0a5481c05d6239a336b8995f2c23c3e619250633bfb` |
| Commercial recovery | 256 | `53fe959a7f8fc6894b6170e006e0d3e0d7f49cbc25cb1bb8cc3d717e84e6239f` |
| Commercial Charter victory | 844 | `13933981fbaed7ccf5b2228bc40bb1d5435072f7b740affb7b05d25fea5d3083` |
| Industrial opening | 64 | `4fed94e2ba6a3a06eb84fc9db44a9c671268077cacfbba3f3e03f62167037d0f` |
| Industrial complication | 128 | `37c1cf4e620c8af5741fd9f4b4acfa9b7976d49f6149ec88475ac2b260f1529e` |
| Industrial recovery | 256 | `ba6bcfd17094929fed45cd5dc94b209eec16ede7cfab6acfc39c53a30da24ff0` |
| Industrial Charter victory | 844 | `670a8fc6a7a8d23a3c07b8119a87161215cd7b0eaa15b5867e967163c2c461e3` |

Commercial uses the existing Commercial Tax Relief resolution. Industrial
uses the existing Industrial Utility Expansion resolution. The fixtures
preserve authoritative strategy, current phase, resolution, next daily
boundary, analytics, recovery identity, message, simulation status, and
terminal identity.

The 4,860-byte manifest has SHA-256
`aa62273943debe4b841a324584468a1953039f1a399e570321cbca46f4dcb000`.
Exact spatial and file digests are retained in the manifest and corpus
evidence record.

## Persistence, replay, undo, and immutable snapshots

Every fixture is exercised through the production save/load boundary as both:

- a readable primary, returning the exact state paused with
  `City loaded · Simulation paused`; and
- a readable backup-only candidate, returning the exact state paused with
  `Recovered last known-good city · Simulation paused`.

Load clears undo in both routes. The builder independently replays each
opening-to-complication, complication-to-recovery, and recovery-to-victory
boundary to the exact next frozen state. Every playing fixture supports an
exact one-command undo. Charter-victory fixtures reject further simulation
commands without mutation.

Retained `CityPresentationSnapshot` and spatial samples remain unchanged after
the source state advances. The snapshot state, strategy analytics, spatial
samples, and terminal identity agree with the committed manifest.

Authentic schema-0 and schema-1 fixtures retain their original bytes, file
SHA-256 values, and fingerprint-v1 state digests. Schema stays 1 and
fingerprint version stays 1.

## Validation

- Explicit two-build corpus writer: 1/1 passed.
- Focused `ProductionStoryStateFixtureTests`: 5/5 passed in 6.498 seconds.
- Session/strategy/terminal/spatial platform matrix: 38/38 passed in
  26.303 seconds.
- Complete native suite: 164/164 passed in 413.927 seconds.
- `git diff --check`: passed.
- `git diff --cached --check`: passed for each checkpoint.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `./script/build_and_run.sh --verify`: passed for exact fixture commit
  `308b3026d4f8d25485dd93d2808b5c7fe654d9eb`.

The staged candidate was
`simulation-platform-w8bb1822a1e25`, with bundle/preference identity
`com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, isolated root
`dist/test-data/simulation-platform-w8bb1822a1e25`, and manifest
`dist/manifests/simulation-platform-w8bb1822a1e25.manifest`. Inspection found
no story fixture files or test-builder symbols in the production app. Its
verified PID `8901` was terminated after proof.

## Budgets

The two final corpus generations took 1,499.150 ms and 1,489.861 ms.
Fixture envelopes range from 131,891 to 133,229 bytes. Across all eight
fixtures:

- fingerprint: 1.137–1.223 ms;
- immutable presentation/spatial snapshot: 2.242–2.436 ms;
- save: 9.064–9.443 ms;
- load: 2.836–3.186 ms.

All results remain below the existing 2 MB envelope, 5,000 ms corpus,
500 ms fingerprint/snapshot, 1,500 ms save/load, and 128 KiB retained-spatial
ceilings. The dense diagnostic retained digest
`149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`
and its 136,367-byte envelope.

## Consumer adoption and limitations

The exact renderer, HUD, and quality paths are documented in
`docs/production/evidence/PLAY-047/308b302/CONSUMER-PATHS.md`. All consumers
start from a manifest-verified committed JSON envelope and use existing
production load, immutable snapshot, store, renderer, UI, and staged-candidate
boundaries. No production fixture loader is required or permitted.

These fixtures provide reproducible evidence setup. They do not replace the
independent no-coaching PLAY-052 critical journey and cannot prove player
discovery or completion.

## Integration order and rollback

Adopt in this order:

1. authority merge `2595efc23933599f07995f02d67ac8f408bd5e0f`;
2. fixture/test commit `308b3026d4f8d25485dd93d2808b5c7fe654d9eb`;
3. evidence/consumer commit `8d0224fff90585b2c43f7a9d795f1853891d5954`;
4. this completion-record commit.

Rollback removes the test support, the eight test resources, their manifest,
the focused tests, and the PLAY-047 evidence/completion documents. There is no
runtime migration or dependent-lane product rollback.
