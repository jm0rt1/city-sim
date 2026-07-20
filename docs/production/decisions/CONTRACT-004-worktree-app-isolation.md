# CONTRACT-004: Isolate staged apps by worktree

**Status:** Approved

**Date:** July 19, 2026

**Owner:** Integration; build-script implementation assigned to PLAY-040

## Player outcome

Testing one CitySim candidate cannot change another candidate's welcome state, quicksave, preferences, process, or automation target. Hands-on evidence identifies the exact branch and commit under test.

## Approved contract

1. `script/build_and_run.sh` may derive a sanitized worktree lane identifier from the current branch and stage a lane-specific bundle identifier and display name for non-`master` branches. `master` retains `com.jfmortensen.citysim` and `CitySim`.
2. Worker bundles use `com.jfmortensen.citysim.<lane>` and a visible display suffix such as `CitySim [UI]`. The executable name may remain `CitySimNative` only if process targeting is changed so the script never kills or verifies an unrelated lane.
3. Worker launches set `CITYSIM_DATA_ROOT` to a lane-specific directory under that worktree's ignored `dist/test-data/` root. Master launches retain the production Application Support default unless an explicit test-isolation flag is supplied.
4. Test automation and proof manifests must record branch, full commit, bundle identifier, data root, launch time, and staged bundle path.
5. The script must target the exact staged bundle/process identity it created. It may not use a global `pkill -x CitySimNative` or ambiguous bundle lookup that can terminate or attach to another lane.
6. Isolation directories are generated test state and remain ignored. Scripts may recreate their own lane-specific bundle and data root, but may not remove another lane's state.

## Required behavior and tests

- Two worker bundles can be staged and launched simultaneously with different bundle identifiers, preference domains, and save roots.
- Saving, onboarding dismissal, Reduce Motion, and diagnostics changes in one lane do not appear in the other.
- `--verify` proves the exact launched candidate remains alive and prints its branch, commit, bundle identifier, bundle path, and data root.
- Master staging and production save location remain backward compatible.
- `bash -n`, shell-focused checks, full native tests, and a live two-bundle isolation proof pass.

## Lane effects and adoption order

- **PLAY-040** implements the integration-approved script and injected data-root support before independent save/resume acceptance.
- **PLAY-050** supplies the two-instance acceptance proof and uses only its own isolated root.
- **PLAY-020** and **PLAY-030** use lane bundles for visual/input proof after the script lands on their branches.

## Rollback

Master behavior remains the compatibility anchor. Worker-specific bundle/data directories are disposable generated state; rollback must preserve user production saves and preferences.
