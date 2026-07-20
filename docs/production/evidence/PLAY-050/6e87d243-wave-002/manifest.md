# PLAY-050 Wave 002 Candidate Manifest — 6e87d243

## Repository identity

- Accepted integration base: `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- Supplied product candidate: local `master` at `6e87d24398fb204cbb4bc2612239d7e295730949`
- Pre-integration rollback point: `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- Playtest branch: `codex/citysim-playtest-quality`
- Frozen evidence tip before merge: `c6d416f113d6888a15eb1d171fa1946ed13fa12d`
- Playtest candidate merge HEAD: `dfc9a67ca826a12e0df5c0eac11ae336dc314776`
- Candidate ancestry: `git merge-base --is-ancestor 6e87d24398fb204cbb4bc2612239d7e295730949 HEAD` passed.
- Divergence after merge: local `master...HEAD` = `0 10`.
- Pre-merge and post-merge worktree: clean.
- Journey: `critical-journey-v4.md`, frozen before candidate execution.

## Declared isolated identity

Observed from `./script/build_and_run.sh --print-identity` at the exact playtest candidate HEAD:

- Bundle identifier / preference domain: `com.jfmortensen.citysim.playtest-quality`
- Display name: `CitySim [Quality]`
- Data root: `/Users/James/.codex/worktrees/14c5/city-sim/dist/test-data/playtest-quality`
- Staged bundle path: `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality.app`
- Executable path: `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality.app/Contents/MacOS/CitySimNative`
- Manifest path: `/Users/James/.codex/worktrees/14c5/city-sim/dist/manifests/playtest-quality.manifest`

The staged bundle, executable hash, `Info.plist` hash, PID, launch time, process command, root inventory, and two-candidate live table are intentionally `blocked/not run`. Automated preflight found the critical fingerprint failure recorded in `defects/PLAY-050-D003-dense-fixture-digest-mismatch.md` before the build/launch stage. No production preferences, Application Support save, or other lane root was touched.

## Frozen fingerprint preflight

| Fixture | Published before run | Independently observed | Result |
| --- | --- | --- | --- |
| `dense-24x24`, 400 ticks, fingerprint v1, 135,456-byte schema-1 envelope | `fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5` in accepted PLAY-040 completion | `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`, identical in the full suite and focused repeat | **Failed — critical** |

The candidate handoff also does not publish all expected digests required by the frozen persistence gate: tick-4 legacy normalization, partial and awarded Town Charter states, a named pre-command undo checkpoint, and both exact tick-2,800 strategy states. PLAY-050 did not derive replacement expectations after observing the candidate.

## Stop disposition

The frozen v4 gate rejects an unchanged-fixture digest mismatch and prohibits beginning the player timer until required expected fixture digests are published. The exact candidate is therefore rejected at automated preflight. D001, D002, live catalog reconciliation, persistence/recovery, isolation, accessibility, and the timed golden journey remain open rather than being marked passed or fixed.
