# PLAY-046 Terminal Runtime Proof

Date: 2026-07-23

## Candidate identity

- Branch: `codex/citysim-simulation-platform`
- Authority: `05add3485d0052d7f2dba95a0353428e24e3b499`
- Preserved PLAY-045 head: `ffb8d6c`
- Authority merge: `42bbfec`
- Frozen gameplay source: `0e3e68e5cac31d9f4b340eba18a6aa6bf8608232`
- Unmodified gameplay cherry-pick: `74a4b5a`
- Platform checkpoint: `e1d3ad7a6721dc02564b47c0948eae67a291e71a`

## Deterministic contract

The stale accepted-command fixture was classified rather than re-goldened in
place. Its last pre-victory states remain playing at tick 840:

- Industrial digest:
  `fc3e7e9114a0f2bbd9d0f87e512c6fdeb3f7a2b63366f5fff4a1dc0fd9bd2472`
- Commercial digest:
  `b3207d4b5086937f5f4ee8e9fb882c09733095bb8b88920bdd96ea14ada6947f`

One accepted daily-boundary command reaches the frozen tick-844 terminal
states:

- Industrial digest:
  `88797da6beb2f646dba6bd5317878614a2ffe89ee83f59e32a32847e03044f30`
- Commercial digest:
  `05d46bb397c73d6305f145e770a24a85ffc3bf6ac2a75cd64b4f8c35b0072c8`

All remaining daily-boundary fixture commands reject
`simulationNotPlaying`, and the terminal state remains byte-for-byte
unchanged. The typed fixture boundary now applies the same terminal guard to
daily-boundary, tax, build, and demolish commands.

The four exact recovery-route terminal digests are:

- Commercial tax relief:
  `d34d24c739e92c61e0396c3218bde1a56ef16bba6b7ed68ba354f74a601ec6a1`
- Commercial public-realm investment:
  `de5e7c9200f02f044a1798cf29587d9de41b2de74eb7a8853739b14e0918f6b5`
- Industrial utility expansion:
  `7354b7cbdb9fc8d2e599d2057769a41e619b702d7d4940c329e644604439929c`
- Industrial green buffer:
  `98daef105054ac7f672bb2d5211b9011c0893745ffcbcd81e8ea10a80073cb38`

Schema remains 1 and fingerprint version remains 1. Authentic legacy fixture
bytes are unchanged. Separate schema-0 and schema-1 awarded-playing cases prove
that decode/load does not mutate or normalize the state; ticks 1 through 3
remain playing, and the next daily boundary at tick 4 normalizes to won without
a duplicate award or message.

## Runtime matrix

`TerminalVictoryPlatformTests` proves, for every recovery route:

- independent replay reaches the same tick-844 terminal state and digest;
- five repeated fingerprints agree;
- 128 post-terminal simulation steps are immutable;
- daily-boundary, tax, build, and demolish fixture commands reject without
  mutation;
- schema-1 primary save/load preserves state and fingerprint;
- corrupt-primary recovery loads the identical last-known-good terminal
  backup, preserves the corrupt primary, pauses, clears undo, and retains the
  established recovery feedback;
- immutable presentation snapshots preserve state, fingerprint, and analytics.

## Budgets

The full native run reported:

| Route | Bytes | Fingerprint | Snapshot | Save | Load |
|---|---:|---:|---:|---:|---:|
| Commercial tax relief | 133,148 | 1.272 ms | 2.315 ms | 6.088 ms | 2.965 ms |
| Commercial public realm | 133,155 | 1.243 ms | 2.260 ms | 6.191 ms | 2.970 ms |
| Industrial utility | 133,199 | 1.310 ms | 2.225 ms | 6.240 ms | 2.752 ms |
| Industrial green buffer | 133,204 | 1.311 ms | 2.335 ms | 6.373 ms | 2.883 ms |

The unchanged dense diagnostic remained
`149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`
at 136,367 bytes, with 40.872 ms simulation, 1.264 ms fingerprint,
2.471 ms snapshot, 5.882 ms save, and 2.921 ms load.

## Exact staged won-state relaunch

`./script/build_and_run.sh --verify` staged and launched:

- candidate: `simulation-platform-w8bb1822a1e25`
- bundle identifier and preference domain:
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`
- data root:
  `dist/test-data/simulation-platform-w8bb1822a1e25`
- manifest:
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`

The opt-in `CITYSIM_PLAY046_EXPORT_ROOT` test hook used the production
`SaveGameService` twice to create identical primary and backup schema-1 saves
for the frozen Commercial Tax Relief terminal state. Both files were 133,148
bytes with file SHA-256
`f5d600d79e82a48b047fd4d8664e49cb8ce081cd46d4cfb4306884eb5ac2bc34`;
their authoritative state digest was
`d34d24c739e92c61e0396c3218bde1a56ef16bba6b7ed68ba354f74a601ec6a1`.

The integration-owned relaunch harness terminated only manifest PID `15033`
and relaunched the same executable compact as PID `23921`. Cmd-O loaded Day
212/tick 844 with:

- Pause selected;
- Undo disabled;
- `All objectives achieved`;
- the terminal `A City Worth Calling Home` panel;
- `City loaded · Simulation paused`;
- 511 residents, positive cashflow, full utilities, and the preserved won
  state.

The retained harness files are under `won-relaunch/`. `finish` recorded the
same primary/backup bytes and terminated only PID `23921`. After proof, the
pre-existing PLAY-045 primary and backup were restored byte-for-byte; both
again have SHA-256
`e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186`.

## Commands

- Focused platform/gameplay matrix: 55 tests, 55 passed.
- Complete native suite: 153 tests, 153 passed.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `git diff --check`: passed.
- `./script/build_and_run.sh --verify`: passed.
- `script/persistence_relaunch_gate.sh start ...`: passed.
- Cmd-O exact compact won-state load: passed.
- `script/persistence_relaunch_gate.sh finish ...`: passed.
