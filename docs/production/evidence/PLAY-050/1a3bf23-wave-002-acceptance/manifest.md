# PLAY-050 Wave 002 Candidate Manifest — 1a3bf23

- PLAY-050 evidence HEAD: `1a3bf232de658212a6f127e31ae59006b3fa2ae3`
- Exact integrated product candidate: `ce544226523b38b2947bb04f336e1d5f570622ec`
- Candidate token: `playtest-quality-wf967be0ab5b4`
- Bundle identifier and preference domain: `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Display name: `CitySim [Quality wf967be0ab5b4]`
- Isolated data root: `dist/test-data/playtest-quality-wf967be0ab5b4`
- Executable SHA-256: `d02da43cf9d8026a5f4be269394841d02e7935a21be72fb804aca90215abf35b`
- `Info.plist` SHA-256: `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`
- Primary long-session PID: `61508`
- Product changes by PLAY-050: none

The candidate was merged without rewriting integration history. A second clone of the same lane and commit staged as token `we1ba` with a distinct bundle identifier, preference domain, data root, executable, and PID. `script/verify_candidate_isolation.sh` passed while both candidates were alive; stopping candidate B did not stop or mutate the primary candidate.

The primary staged PID remained alive for **20:19 wall time** before PLAY-050 stopped only that exact process. A verified launcher relaunch later used PID `66964` solely for exact save/resume confirmation and an explicitly post-gate diagnostic; it was also stopped exactly. No other CitySim owner process was touched.
