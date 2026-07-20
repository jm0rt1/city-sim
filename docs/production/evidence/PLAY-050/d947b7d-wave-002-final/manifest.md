# PLAY-050 Final Wave 002 Candidate Manifest — d947b7d

## Candidate identity

- Accepted integration candidate: `1084ba6ef624f9928d80f30829fe9f651ed68166`.
- Playtest branch: `codex/citysim-playtest-quality`.
- Frozen playtest merge HEAD: `d947b7d660d5778dcf34c165e750db293e060236`.
- Preserved predecessor rejection tip: `dd3f7a64efc84efcce417148c45fdc11d4bdf947`.
- Worktree: `/Users/James/.codex/worktrees/14c5/city-sim`.
- Worktree was clean before merge; product code was not edited by PLAY-050.

## Exact staged application

- Candidate ID: `playtest-quality-wf967be0ab5b4`.
- Bundle/preference identifier: `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`.
- Display name: `CitySim [Quality wf967be0ab5b4]`.
- Data root: `/Users/James/.codex/worktrees/14c5/city-sim/dist/test-data/playtest-quality-wf967be0ab5b4`.
- Bundle: `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality-wf967be0ab5b4.app`.
- Executable: `Contents/MacOS/CitySimNative-wf967be0ab5b4`.
- Executable SHA-256: `ac423fbeeaad09b745fd8ee35c5c87c93bc99bc9104bc24b6600f807abbd7c6f`.
- Info.plist SHA-256: `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`.
- Default launch: `2026-07-20T14:29:18Z`, exact PID `39809`, stopped by exact PID only.
- Compact launch: after resetting only this domain's `hasSeenCitySimWelcome`, `CITYSIM_COMPACT_WINDOW=1`, exact PID `40734`, stopped by exact PID only.
- No other owner's process was stopped or modified.

The manifest written by the staging script named commit `d947b7d660d5778dcf34c165e750db293e060236`, exact bundle, executable, root, launch time, and PID before acceptance interaction began. Production Application Support and production preferences were not used.

## Window and runtime observations

- Default capture: 1,229 x 768 pixels of app content in the retained full-window capture.
- Explicit compact capture: 900 x 632 including window chrome; declared content width was 900 and the tested content size was the configured 900 x 600.
- Compact RSS was 705,280 KiB at 67 seconds during image/AX capture and settled to 111,968 KiB at 4:01 before exact-PID termination.
- A regular launch sample of 875,232 KiB immediately after build/launch was transient and is not represented as settled RSS.
- Reduce Motion settled RSS was not measured because D006 is an immediate rejection condition and the frozen journey prohibits continuing later gates for credit.
