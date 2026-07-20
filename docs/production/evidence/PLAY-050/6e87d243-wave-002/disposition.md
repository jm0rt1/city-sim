# PLAY-050 Wave 002 Independent Disposition — Reject

- Task/lane: `PLAY-050` / Playtest quality
- Exact product candidate: `6e87d24398fb204cbb4bc2612239d7e295730949`
- Exact playtest candidate merge HEAD: `dfc9a67ca826a12e0df5c0eac11ae336dc314776`
- Exact retained evidence commit: `ce650b8256cef1a469fa38e4884911ad54bb63be`
- Accepted pre-wave authority: `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- Disposition: **reject Wave 002 candidate; PLAY-050 remains open**

## Independent finding

The complete native suite passed 78 tests, but the candidate did not reproduce its pre-published dense fixture fingerprint. The accepted PLAY-040 record declares `fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5` for `dense-24x24` after 400 ticks. The full independent suite and an isolated focused repeat both produced `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77` for that same named fixture and byte count.

The candidate's performance test validates internal save/load equality but does not assert the published dense digest, so its green result does not close this contract failure. The supplied completion artifacts also omit several expectations required by the frozen PLAY-050 persistence gate: tick-4 normalization, partial and awarded Charter states, a named undo checkpoint, and both exact-horizon strategy digests.

## Gate disposition

- Exact candidate merge, ancestry, cleanliness, static checks, declared worker identity, and the 78-test suite: passed.
- CONTRACT-003 frozen fingerprint agreement: failed; critical and reproduced.
- D001 onboarding: remains open and was not marked fixed.
- D002 compact/accessibility: remains open and was not marked fixed.
- Live 32-command/system-route equivalence, modal leakage, D001/D002 visual/AX routes, isolated persistence/recovery, two-candidate isolation, and the uncoached 20-minute session: blocked by the frozen preflight stop and not executed.
- Product fixes, push, integration, and shared-contract changes: none.

## Return

Return `PLAY-050-D003` to the Simulation Platform / Integration contract-evidence owner with the reproduction in `defects/PLAY-050-D003-dense-fixture-digest-mismatch.md`. A replacement candidate needs an exact commit and a complete, integration-authorized digest catalog published before a fresh independent run. The retained D001/D002 records must remain open until that valid candidate is exercised through their complete live checkpoints.
