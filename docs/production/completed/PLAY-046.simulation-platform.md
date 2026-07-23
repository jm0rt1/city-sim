# PLAY-046 Completion — Terminal Charter Victory Runtime Trust

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Authority:** `05add3485d0052d7f2dba95a0353428e24e3b499`
- **Preserved PLAY-045 head:** `ffb8d6c`
- **Authority merge:** `42bbfec2164833a473baa7d565f886eb41ac1d49`
- **Frozen gameplay source:** `0e3e68e5cac31d9f4b340eba18a6aa6bf8608232`
- **Unmodified gameplay cherry-pick:** `74a4b5ac48d6ac29603e1bb270ff3f087444ab26`
- **Platform product/test commit:** `e1d3ad7a6721dc02564b47c0948eae67a291e71a`
- **Exact-app evidence commit:** `ee12e31af45511d93560dbab2c685a6281b1fa12`
- **Completion-record commit:** reported in the platform handoff

## Player outcome

Charter victory is now a frozen terminal runtime boundary. The accepted
Industrial and Commercial deterministic sessions reach `.won` exactly at tick
844, and every remaining fixture command rejects `simulationNotPlaying`
without mutation. All four strategy recovery identities preserve the same
terminal outcome through replay, schema-1 save/load, corrupt-primary backup
recovery, cleared undo, and immutable presentation snapshots.

## Changed surfaces

Frozen gameplay adoption:

- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`

Platform product and regression coverage:

- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulationCommand.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/TerminalVictoryPlatformTests.swift`

Evidence and completion:

- `docs/production/evidence/PLAY-046/e1d3ad7/`
- `docs/production/claims/PLAY-046.simulation-platform.md`
- `docs/production/completed/PLAY-046.simulation-platform.md`

No gameplay rule was authored in this lane. No UI, renderer, message, gameplay
balance, build script, replay architecture, schema, fingerprint version, or
authentic legacy fixture byte changed.

## Deterministic checkpoints

The accepted sessions retain their last pre-victory identities at tick 840:

- Industrial:
  `fc3e7e9114a0f2bbd9d0f87e512c6fdeb3f7a2b63366f5fff4a1dc0fd9bd2472`
- Commercial:
  `b3207d4b5086937f5f4ee8e9fb882c09733095bb8b88920bdd96ea14ada6947f`

One further accepted daily boundary reaches tick 844 and freezes:

- Industrial:
  `88797da6beb2f646dba6bd5317878614a2ffe89ee83f59e32a32847e03044f30`
- Commercial:
  `05d46bb397c73d6305f145e770a24a85ffc3bf6ac2a75cd64b4f8c35b0072c8d`

The four exact recovery-route terminal fingerprints are:

- Commercial tax relief:
  `d34d24c739e92c61e0396c3218bde1a56ef16bba6b7ed68ba354f74a601ec6a1`
- Commercial public-realm investment:
  `de5e7c9200f02f044a1798cf29587d9de41b2de74eb7a8853739b14e0918f6b5`
- Industrial utility expansion:
  `7354b7cbdb9fc8d2e599d2057769a41e619b702d7d4940c329e644604439929c`
- Industrial green buffer:
  `98daef105054ac7f672bb2d5211b9011c0893745ffcbcd81e8ea10a80073cb38`

Five repeated fingerprints agree for every route. Independent replays produce
the exact same states. The command executor rejects daily-boundary, tax, build,
and demolish fixture commands before any terminal mutation, and 128 direct
simulation steps leave every won state unchanged.

## Persistence, undo, recovery, and snapshots

For every recovery identity:

- schema-1 primary save/load returns the exact state and fingerprint;
- a second save creates an exact last-known-good terminal backup;
- corrupt-primary recovery returns the exact backup, preserves the corrupt
  primary, pauses, clears undo, and retains
  `Recovered last known-good city · Simulation paused`;
- a post-load Undo command remains unavailable and cannot mutate the state;
- `CityPresentationSnapshot` retains the exact state, fingerprint, strategy
  resolution analytics, and terminal identity.

Schema remains 1 and fingerprint version remains 1. Separate authentic-shape
schema-0 and schema-1 awarded-playing tests prove decode/load does not mutate
or normalize. Ticks 1 through 3 remain playing; tick 4, the next daily
boundary, deterministically becomes won without a duplicate award or message.
The normalized state then round-trips through schema 1 and fingerprint version
1 exactly.

## Automated validation

- Focused gameplay/session/resolution/terminal matrix: 55/55 passed.
- `TerminalVictoryPlatformTests` with the exporter absent: 2/2 passed.
- Opt-in exact-save export run: 1/1 passed.
- Final complete native suite at evidence commit: 153/153 passed in
  391.813 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed for every checkpoint.
- `./script/build_and_run.sh --verify`: passed.

The unchanged dense fixture retained digest
`149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`,
136,367 bytes, and 46,080 retained-sample bytes.

## Final measured budgets

Final complete-suite measurements:

| Fixture | Bytes | Fingerprint | Snapshot | Save | Load |
|---|---:|---:|---:|---:|---:|
| Dense | 136,367 | 1.217 ms | 2.348 ms | 6.104 ms | 2.821 ms |
| Commercial tax terminal | 133,148 | 1.369 ms | 2.212 ms | 5.949 ms | 2.809 ms |
| Commercial public realm terminal | 133,155 | 1.279 ms | 2.400 ms | 6.033 ms | 3.422 ms |
| Industrial utility terminal | 133,199 | 1.276 ms | 2.276 ms | 6.365 ms | 3.063 ms |
| Industrial green buffer terminal | 133,204 | 1.291 ms | 2.322 ms | 6.124 ms | 3.018 ms |

Dense simulation completed in 40.844 ms. Every measurement remains below the
existing 2 MB envelope, 5,000 ms simulation, 500 ms fingerprint/snapshot,
1,500 ms save/load, and 128 KiB retained-sample ceilings.

## Exact staged won-state relaunch

The exact product checkpoint staged as:

- candidate `simulation-platform-w8bb1822a1e25`;
- bundle/preference identity
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- isolated data root
  `dist/test-data/simulation-platform-w8bb1822a1e25`;
- manifest
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`.

An opt-in test-only export hook used the production `SaveGameService` twice to
write identical schema-1 primary and backup saves for the frozen Commercial
Tax Relief victory. Each file was 133,148 bytes with file SHA-256
`f5d600d79e82a48b047fd4d8664e49cb8ce081cd46d4cfb4306884eb5ac2bc34`
and authoritative state digest
`d34d24c739e92c61e0396c3218bde1a56ef16bba6b7ed68ba354f74a601ec6a1`.
The hook is inert unless `CITYSIM_PLAY046_EXPORT_ROOT` is explicitly present.

The approved relaunch harness terminated only manifest PID `15033` and
relaunched the exact bundle compact as PID `23921`. Cmd-O restored Day
212/tick 844 with Pause selected, Undo disabled, `All objectives achieved`,
`City loaded · Simulation paused`, and the terminal
`A City Worth Calling Home` presentation. Harness finish retained matching
before/after save inventories and terminated only PID `23921`.

After proof, the pre-existing PLAY-045 primary and backup were restored
byte-for-byte at SHA-256
`e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186`.

## Adoption and rollback

Integration should preserve this order:

1. authority merge `42bbfec`;
2. frozen gameplay cherry-pick `74a4b5a`;
3. platform terminal contract `e1d3ad7`;
4. exact-app evidence `ee12e31`;
5. this completion-record commit.

Rollback removes the platform guard/checkpoint/tests and evidence, then reverts
the frozen gameplay cherry-pick. No migration or dependent-lane contract
change is required. Durable undo, replay persistence, generic recovery error
redesign, UI composition, rendering, and gameplay balancing remain out of
scope.
