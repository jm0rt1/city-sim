# PLAY-063 Frozen Baseline Identity

## Git identity

- Published authority and frozen shipping baseline:
  `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`
- Accepted non-shipping Industrial L1 source:
  `79668c347e58d602f9627c73cb09e3272a83ef57`
- Branch:
  `codex/citysim-playtest-quality`
- Initial/preregistration divergence:
  `0 0` against `origin/master`
- Product/build parity:
  active product diff from accepted `1799fbc` is empty.

## Staged identity

- Candidate ID:
  `playtest-quality-wf967be0ab5b4`
- Bundle ID/preferences:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Bundle:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- Executable:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- Executable SHA-256:
  `29d73c09d16a3888703c5c21248c8e2d6e8cfbbc194a9ed26e9b925d81e02720`
- Staging-manifest SHA-256:
  `f74a182695c2a6a002d8a63e7fa5d72c03fa9dd133a8b0db731ba807efb7b664`
- Info.plist SHA-256:
  `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`
- Staged generated-v4 manifest SHA-256:
  `c9351451928e035c0631b074d38fc55156325e5fcd19d3ebd4b104c5f90d8aa8`
- Fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`

`identity/staged-baseline.manifest` records exact commit `8f85a0c`,
worktree token, bundle/preferences identity, executable, resource bundle,
launch time, and initial staged PID.

## Process binding

All captures used the exact bundle/executable above, one quality process per
route, and fresh isolated data roots. Regular routes injected
`CITYSIM_REGULAR_WINDOW=1`; compact routes injected
`CITYSIM_COMPACT_WINDOW=1`; Reduce Motion added
`CITYSIM_REDUCE_MOTION_PROOF=1`; explicit LOD routes added
`CITYSIM_PROOF_CAMERA_SCALE`.

Regular images are uncropped 1278 x 768. Compact images are uncropped
900 x 652 decorated windows with exact 900 x 600 app content. Every route
loaded the byte-identical quicksave and remained paused. PIDs and roots are
listed in `BASELINE-LEDGER.md`; all exact processes were terminated after
capture.
