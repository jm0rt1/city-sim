# PLAY-050 Wave 002 Rerun Manifest — f9b54fc

## Repository and candidate identity

- Accepted pre-wave authority: `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- Rejected predecessor: `6e87d24398fb204cbb4bc2612239d7e295730949`
- Exact repaired product candidate: local `master` at `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209`
- Preserved previous PLAY-050 disposition tip: `9f7a097b5ea9dbfe5cae8795629c193e5243ea4f`
- Playtest candidate merge HEAD: `85ad9e266cfa0597d5d422008ebd2ef448fb25b3`
- Branch: `codex/citysim-playtest-quality`
- Candidate ancestry: `git merge-base --is-ancestor f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209 HEAD` passed.
- Divergence after merge: local `master...HEAD` = `0 13`.
- Pre-merge, post-merge, post-build, and post-stop worktree: clean.
- Journey: frozen `critical-journey-v4.md` plus the July 19 repaired-candidate restart dispatch.

## Exact staged quality candidate

- Build invocation: isolated Swift caches plus `./script/build_and_run.sh --verify`.
- Branch/commit printed by build: `codex/citysim-playtest-quality` / `85ad9e266cfa0597d5d422008ebd2ef448fb25b3`.
- Bundle identifier / preference domain: `com.jfmortensen.citysim.playtest-quality`.
- Display name: `CitySim [Quality]`.
- Data root: `/Users/James/.codex/worktrees/14c5/city-sim/dist/test-data/playtest-quality`.
- Staged bundle: `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality.app`.
- Executable: `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality.app/Contents/MacOS/CitySimNative`.
- Executable SHA-256: `b3e81dc0bad3b16b588587e0f9f092161853f1bfe5ca6ca5c9034853780dc682`.
- `Info.plist` SHA-256: `5b95ab8d5cc303da4a8021667ce5084ca66f90ce44d0729f89924d94447ebdfc`.
- Launch time: `2026-07-20T02:22:23Z`.
- Exact PID: `32451`.
- Exact process path matched the executable above.
- Stop: exact `kill -TERM 32451`; subsequent process inventory showed PID 32451 absent.
- Data-root inventory after stop: directory present and empty; no save, backup, temporary, corrupt, or fixture files.

Read-only production quicksave preflight and post-stop values remained identical: 118,665 bytes, timestamp `2026-07-19T20:50:56-0400`, SHA-256 `f9890b1c954256358ba9dc97f6858db34f0bbd424dafaedf82de75ba655aac3a`. The candidate did not access or modify it.

## Critical simultaneous identity collision

Before onboarding reset or player interaction, exact-path process inventory found another active quality candidate:

| Field | Repaired candidate A | Active external candidate B |
| --- | --- | --- |
| Product commit | `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209` via merge HEAD `85ad9e2…` | `822755cbad5431d868547e3d38d41e8df14e715f` |
| Bundle | current worktree `dist/CitySim-playtest-quality.app` | `/private/tmp/citysim-play040-two-app.6S3Zi1/quality-candidate/dist/CitySim-playtest-quality.app` |
| Bundle identifier | `com.jfmortensen.citysim.playtest-quality` | `com.jfmortensen.citysim.playtest-quality` |
| Display name | `CitySim [Quality]` | `CitySim [Quality]` |
| Preference domain | `com.jfmortensen.citysim.playtest-quality` | `com.jfmortensen.citysim.playtest-quality` |
| Data root | current worktree `dist/test-data/playtest-quality` | external clone `dist/test-data/playtest-quality` |
| PID | `32451` (stopped by PLAY-050) | `59491` (left alive and untouched) |
| Executable SHA-256 | `b3e81dc0…` | `37f215e3…` |
| `Info.plist` SHA-256 | `5b95ab8d…` | `5b95ab8d…` |

The two different candidates have disjoint save roots and process paths but the same bundle identifier, display name, and preference domain. Existing shared preference values before reset were `hasSeenCitySimWelcome=1`, `reduceGameMotion=0`, `showRendererDiagnostics=0`, plus a saved 900-point window frame. Changing them for candidate A would also change the domain observed by candidate B, so D001, D002, Reduce Motion, diagnostics, focus/window, and onboarding evidence cannot be attributed to one candidate.

The frozen candidate manifest explicitly blocks interaction when a preference domain equals another active candidate or candidate identity is ambiguous. No preference was reset and no app UI action was performed after the collision was confirmed.
