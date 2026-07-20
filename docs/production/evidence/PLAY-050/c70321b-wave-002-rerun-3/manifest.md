# PLAY-050 Wave 002 Restart 2 Manifest — c70321b

## Repository identity

- Exact product candidate: local `master` at `c70321b7c61465efe77f600878f74b8093013cb7`.
- Fingerprint-repair parent: `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209`; ancestry passed.
- Management authority ancestor: `b8cb4740b9cf94aa04482539f9909ffb22dbdbea`; ancestry passed.
- Preserved prior evidence HEAD: `a84b5c51c4e7bd795d0110b4c7614a15872867a9`.
- Playtest candidate merge HEAD: `8f692625c6821285036d29cc6f65379c6fa2f8b1`.
- Branch: `codex/citysim-playtest-quality`.
- Candidate ancestry: `git merge-base --is-ancestor c70321b7c61465efe77f600878f74b8093013cb7 HEAD` passed.
- Divergence immediately after merge: local `master...HEAD` = `0 16`.
- Worktree was clean before merge, after merge, after builds, and before evidence creation.

## Primary staged candidate

- Canonical worktree root: `/Users/James/.codex/worktrees/14c5/city-sim`.
- Worktree token: `wf967be0ab5b4`.
- Candidate ID: `playtest-quality-wf967be0ab5b4`.
- Bundle/preference domain: `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`.
- Display name: `CitySim [Quality wf967be0ab5b4]`.
- Data root: `/Users/James/.codex/worktrees/14c5/city-sim/dist/test-data/playtest-quality-wf967be0ab5b4`.
- Bundle: `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality-wf967be0ab5b4.app`.
- Executable: `Contents/MacOS/CitySimNative-wf967be0ab5b4`.
- Executable SHA-256: `b3e81dc0bad3b16b588587e0f9f092161853f1bfe5ca6ca5c9034853780dc682`.
- `Info.plist` SHA-256: `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`.
- Final manifest SHA-256: `3810de1faf1d40f6856950eaa2dc502bc954e1674fe2977f4523d2deb73003c3`.
- D001 pointer PID: `93951`; D001 leakage PID: `95144`. Each was stopped by exact PID after its run.
- Observed D001 full-window capture: 900×652 pixels including 52 pixels of window chrome. This did not satisfy the frozen default 1440×900 start requirement.

The production quicksave and legacy quality preference domain were not used. External legacy quality PID `59491` remained alive and untouched before, during, and after the isolation and D001 work.

## Disposition

CONTRACT-004 same-lane isolation passed independently. D001 then failed critically because gameplay speed and the command guide leaked through the blocking welcome. The wave was stopped before D002, remaining catalog traversal, persistence/recovery, and the 20-minute journey.
