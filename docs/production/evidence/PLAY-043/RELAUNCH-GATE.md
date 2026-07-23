# PLAY-043 Exact-Candidate Relaunch Gate

**Date:** July 22, 2026

**Published harness:** `23d4e73` (`script/persistence_relaunch_gate.sh`)

**Candidate manifest:** `simulation-platform-w8bb1822a1e25`

**Candidate commit recorded by manifest:** `52fc2c17643e7987f78bc360196599e3297967da`

**Disposition:** pass; the retained schema-1 save loaded after exact-bundle compact relaunch, and no `SaveGameService` rejection occurred.

## Exact identity

- staged bundle: `/Users/James/.codex/worktrees/e909/city-sim/dist/CitySim-simulation-platform-w8bb1822a1e25.app`
- executable: `/Users/James/.codex/worktrees/e909/city-sim/dist/CitySim-simulation-platform-w8bb1822a1e25.app/Contents/MacOS/CitySimNative-w8bb1822a1e25`
- executable SHA-256: `1e8bacf5bf124f70a75dc5a19159b9dbe89660f6d77640f414e7bb1e0c751ee4`
- manifest SHA-256: `353235b875aad346e560ce52fed025bd8f945ffcd033d990ee65d0e3d02058d1`
- resolved data root: `/Users/James/.codex/worktrees/e909/city-sim/dist/test-data/simulation-platform-w8bb1822a1e25`
- relaunch environment: exact `CITYSIM_DATA_ROOT` above plus `CITYSIM_COMPACT_WINDOW=1`
- proof PID: `89038`
- cleanup: only PID `89038` was terminated, and it no longer existed after the gate

The harness consumed the existing manifest, performed no rebuild, relaunched the exact staged bundle, and verified the new process command and environment before admitting live load.

## Retained bytes

Both files were identical before and after live load:

| File | Bytes | SHA-256 |
|---|---:|---|
| `quicksave.json` | 131,197 | `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186` |
| `quicksave.backup.json` | 131,197 | `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186` |

This is the retained PLAY-051 primary previously validated as schema 1, fingerprint version 1, digest `413c3fcadd064b544db7d5f7fd2483f26bac1b97cbaf8e7f1ff1402c1784d2fd`, tick 36 / Day 10, Commercial stewardship opportunity, next scheduled tick 88.

## Live operation

After relaunch, the app initially showed Day 1. Cmd-O loaded the retained city and exposed:

- Day 10;
- simulation paused;
- treasury `$23,493`, projected `+$88 / cycle`;
- 309 residents, 64% happiness, 215 filled jobs;
- action confirmation `City loaded · Simulation paused`.

The published finish phase then recorded the unchanged inventories and terminated only the exact proof PID.

## Contract conclusion

PLAY-043 closes as a historical candidate-operation/root-identity defect. The retained bytes are valid under the exact product implementation, and the new integration-owned harness makes candidate, executable, root, compact mode, process targeting, and byte inventories explicit. No save schema, fingerprint version, digest validation, atomic replacement, backup recovery, or product code was changed or weakened.
