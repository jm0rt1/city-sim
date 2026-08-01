# Simulation Execution and Evidence

Read this reference when implementing, validating, or completing a simulation packet.

## Implement and prove

1. Add deterministic, migration, recovery, malformed-input, or performance tests with the change.
2. Verify repeated runs from the same seed/commands produce the promised state.
3. Verify save/load/undo and renderer/UI snapshot consumers when affected.
4. Run the focused owner and directly affected gates named in the validated `modelRoute`, plus `git diff --check` and affected build-script syntax checks; the lane coordinator runs the complete Swift suite only at the exact aggregate boundary.
5. Launch the staged app and complete the affected player journey at the exact aggregate candidate boundary rather than once per unchanged execution packet.
6. Record measured performance and save evidence, not estimates.

## Completion

Commit the focused contract and implementation with a completion record containing hashes, fixtures, measurements, compatibility, and adoption notes. Do not push or merge. A technically elegant subsystem that has not survived real app use, recovery, and dependent consumers is incomplete.
