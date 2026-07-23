# PLAY-043 Completion — Exact Save, Relaunch, and Load Trust

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Wave 005 authority:** `52fc2c17643e7987f78bc360196599e3297967da`
- **Published relaunch harness:** `23d4e73`
- **Integration contract baseline:** `83db6f4482ba4b18f04cdbba7251ebd43ef60d99`
- **Closure evidence commit:** `e19ec8a22b8be460318858952440b316aaa56fd0`
- **Completion-record commit:** reported in the platform handoff

## Player outcome

The retained Commercial stewardship session loads after exact staged-bundle termination and compact relaunch. The load restores the city paused at Day 10 with the exact retained schema-1 bytes and progression fingerprint. Candidate identity, executable, data root, compact mode, before/after save inventory, and exact-PID cleanup are now explicit and reproducible through the integration-owned harness.

The gate produced no `SaveGameService` rejection. PLAY-043 therefore closes as a historical candidate-operation/root-identity defect, not a persistence-validator repair. Product code, save schema 1, fingerprint version 1, digest validation, atomic replacement, corrupt-primary preservation, and backup recovery are unchanged.

## Changed files

- `docs/production/claims/PLAY-043.simulation-platform.md`
- `docs/production/evidence/PLAY-043/RELAUNCH-GATE.md`
- `docs/production/completed/PLAY-043.simulation-platform.md`

The integration-owned `script/persistence_relaunch_gate.sh` arrived from master unchanged.

## Exact retained-save evidence

- candidate: `simulation-platform-w8bb1822a1e25`
- manifest candidate commit: `52fc2c17643e7987f78bc360196599e3297967da`
- executable SHA-256: `1e8bacf5bf124f70a75dc5a19159b9dbe89660f6d77640f414e7bb1e0c751ee4`
- root: `/Users/James/.codex/worktrees/e909/city-sim/dist/test-data/simulation-platform-w8bb1822a1e25`
- proof PID: `89038`, terminated exactly by the finish phase
- primary and backup before/after: 131,197 bytes, SHA-256 `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186`
- retained state: schema 1, fingerprint version 1, digest `413c3fcadd064b544db7d5f7fd2483f26bac1b97cbaf8e7f1ff1402c1784d2fd`, Commercial stewardship opportunity, next scheduled tick 88
- live result: Day 10, paused, `$23,493`, `+$88 / cycle`, 309 residents, 64% happiness, 215 filled jobs, `City loaded · Simulation paused`

## Exact commands and results

- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `./script/persistence_relaunch_gate.sh start --manifest /Users/James/.codex/worktrees/e909/city-sim/dist/manifests/simulation-platform-w8bb1822a1e25.manifest --evidence-dir /private/tmp/play043-relaunch-gate-e909-20260722-1`: `status=ready-for-live-load`, exact PID 89038.
- Live compact Cmd-O through the staged application: passed with the state above and no rejection.
- `./script/persistence_relaunch_gate.sh finish --session /private/tmp/play043-relaunch-gate-e909-20260722-1/relaunch.session`: `status=complete`, exact proof PID terminated.
- Post-finish `ps -p 89038 -o pid=,command=`: empty.
- `git diff --check`: passed before closure commit.

The pre-contract reproduction also independently validated the retained primary and backup, isolated-root save/load, corrupt-primary backup recovery, legacy fixtures, undo/replay, and the full native suite; those commands and hashes remain in `docs/production/evidence/PLAY-043/ROOT-IDENTITY-BLOCKER.md`.

## Adoption and limitations

Integration should retain the published harness as the exact-candidate regression gate. A future live load failure must preserve and report the underlying `SaveGameError.noValidSave(primary:backup:)` diagnostic rather than inferring invalid bytes from generic UI copy.

No product limitation remains within PLAY-043's claimed platform scope. This closure does not claim that the historical process root can be reconstructed after the fact; it records that the retained bytes pass the new exact-identity gate.
