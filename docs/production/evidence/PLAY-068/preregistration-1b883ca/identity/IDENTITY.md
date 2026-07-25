# PLAY-068 Frozen Baseline Identity

## Git

- Branch: `codex/citysim-playtest-quality`
- Published preregistration authority:
  `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- Frozen comparison product:
  `1b883ca684b07ba38c5c755b616723bde0cd2230`
- `1b883ca` is an ancestor of authority: exit `0`
- Active product/build diff: empty

## Staged app

- Candidate ID:
  `playtest-quality-wf967be0ab5b4`
- Bundle ID/preferences domain:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Bundle:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- Executable:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- Resource bundle:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app/CitySimNative_CitySimNative.bundle`
- Staging manifest:
  `dist/manifests/playtest-quality-wf967be0ab5b4.manifest`
- Staging-manifest SHA-256:
  `351e847435c334f700712c7f1850a4a4f7da95757b2c19bda28b13c0c339f19e`
- Executable SHA-256:
  `3c4a58a444e481b10d2a64da0d36b9f53fa777522657069c4692abafabee7a5c`
- Info.plist SHA-256:
  `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`
- Source/staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`
- Source/staged generated manifest comparison: exit `0`

`identity/staged-baseline.manifest` is the exact staging record retained before
live interaction.

## Fixture and process isolation

- Fixture:
  `story-industrial-complication-v1.json`
- Fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`
- Regular root:
  `/private/tmp/citysim-play068-baseline-1b883ca-regular`
- Compact root:
  `/private/tmp/citysim-play068-baseline-1b883ca-compact`
- Explicit regular env:
  `CITYSIM_REGULAR_WINDOW=1`
- Explicit compact env:
  `CITYSIM_COMPACT_WINDOW=1`
- Reduce Motion env:
  `CITYSIM_REDUCE_MOTION_PROOF=1`
- Proof camera env:
  `CITYSIM_PROOF_CAMERA_SCALE`

Each route used one exact quality process. `BASELINE-LEDGER.md` records PID and
RSS. All exact quality PIDs were terminated after capture; no other owner
process was used or terminated.
