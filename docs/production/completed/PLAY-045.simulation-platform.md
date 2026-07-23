# PLAY-045 Completion — Reachable Last-Known-Good Recovery

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Authority:** `ab722bd1ea7c8c132525362bc94bc12d154a78f5`
- **Product and regression-test commit:** `5ce76c783ce96fbfb958bb4388f34c5cefce2ebc`
- **Exact-app evidence commit:** `b9830ff00081acc3ab516838bc087238b87d67f8`
- **Completion-record commit:** reported in the platform handoff

## Player outcome

Load remains reachable when the primary quicksave is absent but the
last-known-good backup survives. The existing authoritative load path restores
the exact backup city paused, clears undo, and presents the existing truthful
recovery feedback. Empty roots remain disabled, primary-only loads are
unchanged, and invalid backup-only attempts do not mutate authoritative state or
report success.

## Changed files

Product:

- `Native/CitySimNative/Sources/CitySimNative/Services/SaveGameService.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`

Regression coverage:

- `Native/CitySimNative/Tests/CitySimNativeTests/BackupLoadAvailabilityTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/StrategyResolutionPlatformTests.swift`

Authority, evidence, and completion:

- `docs/production/claims/PLAY-045.simulation-platform.md`
- `docs/production/evidence/PLAY-045/5ce76c7/`
- `docs/production/completed/PLAY-045.simulation-platform.md`

No save bytes, schema identifier, fingerprint implementation/version, authentic
fixture, gameplay rule, replay model, renderer, UI composition, package
topology, or script changed.

## Contract and compatibility

- `SaveGameService.hasLoadCandidate` performs exactly one primary and one backup
  `fileExists` probe on every check. It does not enumerate, decode, validate,
  preserve, repair, promote, delete, fabricate, or rewrite any file.
- `CityGameStore` receives the same service through one default-preserving
  initializer argument. All production callers retain the existing default
  service and root behavior.
- Load command availability now consumes the service candidate signal.
- `SaveGameService.load()` is unchanged and remains the only validation and
  recovery authority.
- Save schema remains 1 and fingerprint version remains 1.
- Authentic schema-0 and schema-1 fixture file SHA-256 values and fingerprints
  remain frozen. Schema 0 still normalizes missing progression only at tick 4.
- An invalid backup exists as a candidate by design, then the existing load path
  rejects it, preserves the original bytes, retains authoritative store state,
  and shows `No valid save was found`.
- Primary-only load behavior and `City loaded · Simulation paused` feedback are
  unchanged.

## Automated validation

- `BackupLoadAvailabilityTests`: 4/4 passed.
- Focused four-resolution backup test: 1/1 passed.
- Complete native suite: 149/149 passed in 432.774 seconds.
- `git diff --check`: passed.
- `git diff --cached --check`: passed for each checkpoint.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `./script/build_and_run.sh --verify`: staged and launched exact product commit
  `5ce76c7` as isolated manifest PID `25790`.

The matrix proves empty, primary-only, invalid backup-only, authentic
schema-0/schema-1 backup-only, and every Commercial/Industrial recovery
resolution. The resolution cases prove exact fingerprint and analytics,
immutable snapshot equality, paused load, cleared undo, unchanged backup bytes,
and continuation equality after 64 further ticks.

## Measurements and frozen budgets

Availability measurements on the declared Apple Silicon test machine:

| Existing candidates | Checks | Probes | Time |
|---|---:|---:|---:|
| empty | 1,000 | 2,000 | 2.122 ms |
| primary only | 1,000 | 2,000 | 2.186 ms |
| backup only | 1,000 | 2,000 | 2.109 ms |
| primary and backup | 1,000 | 2,000 | 2.047 ms |

Each result is below the 100 ms budget and contains exactly 1,000 primary plus
1,000 backup probes.

Existing dense and resolution ceilings remain unchanged and passed:

- Dense digest:
  `149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`
- Dense envelope: 136,367 bytes
- Dense simulation: 44.609 ms
- Dense fingerprint: 1.354 ms
- Dense immutable snapshot: 2.603 ms
- Dense save: 6.497 ms
- Dense load: 2.980 ms
- Retained spatial sample storage: 46,080 bytes
- Resolution envelopes: 132,585–132,966 bytes
- Resolution fingerprints: 1.300–1.515 ms
- Resolution snapshots: 2.553–2.837 ms
- Resolution saves: 6.458–8.313 ms
- Resolution loads: 2.997–3.216 ms

All remain below the existing 2 MB, 5,000 ms simulation, 500 ms
fingerprint/snapshot, 1,500 ms save/load, and 128 KiB retained-sample ceilings.

## Exact staged recovery proof

The integration-owned relaunch harness started the exact staged bundle compact
against its isolated root with only `quicksave.backup.json` present:

- Candidate: `simulation-platform-w8bb1822a1e25`
- Bundle identifier:
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`
- Proof PID: `26850`
- Backup: 131,197 bytes
- Backup SHA-256:
  `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186`
- State digest:
  `413c3fcadd064b544db7d5f7fd2483f26bac1b97cbaf8e7f1ff1402c1784d2fd`
- State: schema 1, fingerprint version 1, tick 36/Day 10,
  Commercial stewardship opportunity, next scheduled tick 88, nil resolution

File → Load City was enabled. After explicitly returning the restored session
to 1x, Cmd-O restored Day 10 again, selected Pause, disabled Undo, and exposed
`Recovered last known-good city · Simulation paused`. Before/after harness
inventories contain no primary and show the exact same backup size and SHA-256.
The finish phase terminated only proof PID `26850`. Detailed identity,
inventories, process environment, pre-fix reproduction, and accessibility
evidence are retained under `docs/production/evidence/PLAY-045/5ce76c7/`.

## Adoption, rollback, and limitations

Integration should adopt `5ce76c7` before `b9830ff`, then the completion-record
commit. The change is additive and does not require migration or dependent-lane
adoption. Rollback removes the candidate availability property, restores the
store's default field construction and primary-only check, and removes the new
tests/evidence.

Candidate availability intentionally answers only whether a primary or backup
path exists. It does not promise validity; malformed candidates are rejected by
the unchanged authoritative load path. Generic error redesign, durable undo,
replay persistence, backup promotion, UI composition, gameplay, and renderer
work remain out of scope.
