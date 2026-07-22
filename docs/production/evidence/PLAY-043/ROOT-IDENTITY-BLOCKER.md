# PLAY-043 Reproduction — Persistence Bytes Valid, Relaunch Identity Unproven

**Date:** July 22, 2026

**Lane:** Simulation platform

**Authority baseline:** `52fc2c17643e7987f78bc360196599e3297967da`

**Disposition:** blocked on the integration-controlled staged relaunch/data-root contract; no product or script repair is justified from the retained evidence.

## Retained PLAY-051 evidence

The exact production files from the rejected `23d2bf972834b11be82f763d156d111f8ff76bc4` candidate remain at the published production root.

| Artifact | Bytes | SHA-256 | Validation |
|---|---:|---|---|
| `quicksave.json` | 131,197 | `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186` | valid schema 1 primary |
| `quicksave.backup.json` | 118,665 | `f9890b1c954256358ba9dc97f6858db34f0bbd424dafaedf82de75ba655aac3a` | valid schema 0 backup |

A clean temporary build at the Wave 005 baseline loaded the primary as:

- fingerprint version 1;
- digest `413c3fcadd064b544db7d5f7fd2483f26bac1b97cbaf8e7f1ff1402c1784d2fd`;
- tick 36 / Day 10;
- `commercialStewardship`;
- `opportunity`;
- next scheduled tick 88;
- schema-1 source `.primary`.

The retained backup independently loaded as schema 0 at tick 361 with computed digest `9ea1c0ef7cdb8b9c447e7dc0f50254136fdaab9ab0039bb13ad5797597582a76`.

The platform implementation is byte-identical between rejected product commit `23d2bf9` and Wave 005 baseline `52fc2c1`:

- `git diff 23d2bf9..52fc2c1 -- SaveGameService.swift`: zero lines;
- both `SaveGameService.swift` blobs: SHA-256 `b05e27d0f6bc9bf57035953727f6ac3afaefb89085b67dd39a1ba0efbe019894`.

Therefore the retained primary was not rejected by schema, fingerprint version, canonical digest, strategy decoding, or file bytes under the exact implementation that produced the original generic feedback.

## Same-bundle reproduction at Wave 005 baseline

The exact clean baseline staged as:

- candidate: `simulation-platform-w8bb1822a1e25`;
- executable SHA-256: `1e8bacf5bf124f70a75dc5a19159b9dbe89660f6d77640f414e7bb1e0c751ee4`;
- bundle/preference identity: `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- data root: `dist/test-data/simulation-platform-w8bb1822a1e25`.

Pre-edit live flow:

1. Seeded the isolated root with the retained valid primary.
2. Launched exact PID 69092 from the staged executable.
3. Loaded the retained state in the real app. AX reported Day 10, Commercial opportunity state values, `City loaded · Simulation paused`, and Pause selected.
4. Saved from the exact app. AX reported `City saved`.
5. Verified both primary and backup were 131,197 bytes with SHA-256 `e79dc93…`; the primary retained the exact digest, strategy, phase, and next tick.
6. Terminated only PID 69092.
7. Relaunched the same executable without rebuild at compact size as PID 80863.
8. Verified the process environment contained both the exact `CITYSIM_DATA_ROOT` and `CITYSIM_COMPACT_WINDOW=1`.
9. Invoked Cmd-O. AX again reported Day 10, exact state values, `City loaded · Simulation paused`, and Pause selected.
10. Terminated only PID 80863 and confirmed no CitySim executable remained from this proof.

The failure did not reproduce. The exact same executable, root, bytes, and compact relaunch passed.

## Exact rejection classification

The original store mapped every thrown persistence error to the same player string, `No valid save was found`, and the retained quality record did not capture the associated `SaveGameError.noValidSave(primary:backup:)` payload or process root. That historical exception cannot be reconstructed after the fact.

The available evidence rules out a deterministic platform-content rejection and points to a relaunch/root/process-target mismatch in the historical proof:

- both candidates at the reported root are valid;
- the primary's exact digest verifies;
- the same persistence source code accepts both files;
- an exact-root same-bundle restart passes;
- no SaveGameService or build-script change exists between the rejected product and this baseline that could explain an incidental product repair.

Changing validation, schema, digest checks, atomic replacement, or backup recovery would be speculative and would violate the PLAY-043 stop condition.

## Integration-controlled proposal

Add one non-rebuilding persistence-relaunch mode to `script/build_and_run.sh` or an integration-owned companion harness. It must:

1. consume an existing staged manifest and refuse candidate substitution;
2. resolve and print an actual absolute data-root path, including production-default launches;
3. record primary and backup size/SHA-256 before termination;
4. terminate only the manifest's exact executable PID;
5. relaunch the same staged bundle path with the same explicit root plus compact mode, without rebuilding;
6. verify the new PID's exact executable path and process environment root;
7. retain the underlying `SaveGameError.noValidSave(primary:backup:)` diagnostic if load fails;
8. record primary/backup/corrupt-copy hashes after load;
9. terminate the exact proof PID.

Once integration publishes that harness contract, rerun the frozen PLAY-051 primary through it. If an actual SaveGameService rejection is captured, return the exact diagnostic to PLAY-043 for a platform-owned repair. If it passes, close PLAY-043 as a historical candidate-operation defect and use the harness as the regression gate.

PLAY-044 remains blocked. CONTRACT-009 and gameplay-owned recovery resolution were not adopted or modified.
