# Gameplay Execution and Evidence

Read this reference when implementing, validating, or completing a gameplay packet.

## Implement and prove

1. Add focused deterministic tests and scenario fixtures with the behavior.
2. Test early, pressured, recovery, and established states; do not tune one save.
3. Verify conservation, caps, denominators, time units, and failure behavior.
4. Run the focused owner and directly affected gates named in the validated `modelRoute`; the lane coordinator runs the complete Swift suite only at the exact aggregate boundary.
5. Build and operate the staged app through the claimed loop at the exact aggregate candidate boundary rather than once per unchanged execution packet.
6. Confirm HUD and world feedback agree with simulation truth.
7. Capture hands-on evidence of decision, consequence, diagnosis, and recovery.

## Completion

Commit focused work on the lane branch and write the required completion record with exact commands, results, scenario outcomes, proof, and limitations. Do not push or merge. A balanced spreadsheet without an understandable play session is incomplete.
