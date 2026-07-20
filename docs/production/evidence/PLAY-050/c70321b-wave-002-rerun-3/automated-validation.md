# PLAY-050 Restart 2 Automated Validation

## Static and full-suite gates

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/verify_candidate_isolation.sh`: passed.
- Tokenized `--print-identity`: passed.
- Repository `verify_candidate_isolation.sh`: passed against two same-branch/same-commit roots.
- Complete native suite: 78 tests passed, 0 failures in 37.210 seconds.
- Command catalog: 8/8; City simulation/UI: 36/36; gameplay: 14/14; session platform: 14/14; rendering: 6/6.
- Renderer: 5,760 roots reused, zero updates, 1.718 ms unchanged-pulse average.
- Dense fixture `dense-24x24-terminal-wave2-v2`: 400 step attempts, tick 44, `.lost`, simulation 40.332 ms, fingerprint 1.386 ms, save 6.588 ms, load 2.975 ms, 135,456 bytes, digest `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.
- Lifecycle Reduce Motion diagnostic: three active actions normally and zero with Reduce Motion.

The suite includes the automated blocking-welcome invariant, but live D001 found a separate presentation/input leak: speed selection and the command-guide route remained active while the welcome was displayed.
