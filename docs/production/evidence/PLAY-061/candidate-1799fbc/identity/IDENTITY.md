# PLAY-061 Exact Candidate Identity

- **Integration candidate:** `1799fbc2810f14d85511b74a8808bbee1928eef7`
- **Frozen preregistration:** `bd0a06ea676f492e5dc7a354f423f51e6ed4a741`
- **Accepted source authority:** `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`
- **PLAY-060 product / evidence / completion:** `4473f5a1fe827e143701fea6386299db1116ed45` / `528f0e03911b521a2100b9191b4864f2be29631d` / `2c1e9f28004d710cf614c8803d2223de1e5861cb`
- **Branch:** `codex/citysim-playtest-quality`
- **Candidate ID:** `playtest-quality-wf967be0ab5b4`
- **Bundle ID / preference domain:** `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- **Bundle:** `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- **Executable:** `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- **Executable SHA-256:** `29d73c09d16a3888703c5c21248c8e2d6e8cfbbc194a9ed26e9b925d81e02720`
- **Staging manifest SHA-256:** `94d68e2f102ccf3c459950ed95bb85d362f4924ead82d1c6c6df02ccec94b2c6`
- **Info.plist SHA-256:** `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`

The staged manifest names exact commit `1799fbc`, the quality worktree, unique
bundle/preferences identity, executable, bundle, resource bundle, candidate
ID, and verification PID `18870`. The PID was observed running that exact
executable during staged verification and was terminated before live routes.

## Resource identity

- Source and staged generated-v4 manifest:
  `c9351451928e035c0631b074d38fc55156325e5fcd19d3ebd4b104c5f90d8aa8`.
- Block pages:
  `90aeb2c8e56bfc95d8279581ebee60f3dc692e45407aff4e364a0ba087bbff1a`
  and
  `190f1b9e37b33d5c8cfce5bf7d3f91c58283b70bf54d26b190c8585e4d3decce`.
- City page:
  `0510dad5ae9d6ce786edf84217eacc6bf23932eb9ca50246afc559136d5d912f`.
- Neighborhood page:
  `0efaa934b3b58bee17b1dd0b5c6d5fdf02cd0512eb6e718c7018606697ca2cc9`.
- Independent clean pack builds A and B reproduced the same manifest and all
  four page bytes; `diff -qr` returned no output.

## Frozen state and windows

- Fixture:
  `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-commercial-complication-v1.json`.
- Fixture/quicksave SHA-256:
  `fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a`.
- Envelope digest:
  `2a1b046eb21665206709415e3a1363aeaa0a9a4a60e83e1e1b52ae3c53b50ad4`.
- State: seed 42, tick 128, Day 33, Main Street complication, loaded paused.
- Selected comparison target: player block `14,12`.
- Regular window: explicit `CITYSIM_REGULAR_WINDOW=1`, 1280 x 800 content,
  uncropped 1278 x 768 decorated-window capture.
- Compact window: explicit `CITYSIM_COMPACT_WINDOW=1`, exact 900 x 600
  content, uncropped 900 x 652 decorated-window capture.
- Explicit real-app LOD proof scales: city `0.85`, neighborhood `0.65`, block
  `0.50`. Each was a separate exact process and produced a distinct original
  screenshot hash.

## Process and data-root ledger

| Route | PID | Data root | Environment / outcome |
|---|---:|---|---|
| Regular journey | 22997 | `/private/tmp/citysim-play061-regular.uqSkuf` | regular; fixture loaded paused; pointer/keyboard/overlay/build/undo/save |
| Regular persistence relaunch | 29588 | same | regular; exact quicksave loaded paused |
| Exact compact | 30069 | `/private/tmp/citysim-play061-compact.MuESzn` | compact; pointer/keyboard/FKA/AX/Details/search |
| Compact Reduce Motion | 33727 | `/private/tmp/citysim-play061-reduce-motion.ShujVy` | compact plus `CITYSIM_REDUCE_MOTION_PROOF=1` |
| City LOD | 35123 | `/private/tmp/citysim-play061-lod.joKFp2` | regular plus `CITYSIM_PROOF_CAMERA_SCALE=0.85` |
| Neighborhood LOD | 35629 | same | regular plus `CITYSIM_PROOF_CAMERA_SCALE=0.65` |
| Block LOD | 36188 | same | regular plus `CITYSIM_PROOF_CAMERA_SCALE=0.50` |

Every process search resolved exactly one quality executable PID. Each listed
PID was terminated with SIGTERM after its route. The final exact-executable
process search returned no live match. Other owners' production,
simulation-platform, and UI/input CitySim processes were not terminated.
