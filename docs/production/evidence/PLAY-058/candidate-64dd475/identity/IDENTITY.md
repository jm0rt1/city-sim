# PLAY-058 Exact Candidate Identity

- Immutable product candidate:
  `64dd47500fe5e2d4a32a64f6298ded5789d3b773`
- Quality branch staging/evidence merge:
  `37107ea20c7b7edd01af1864b9f452f3e012d948`
- Preserved preregistration:
  `b4337247c56d25d3cb8cc1afb6da180eb8736471`
- Candidate and evidence-branch `Native/CitySimNative` tree:
  `6f0cdf048c675108ce48f5678918b14cd3e89460`
- `git diff --quiet 64dd475..37107ea -- Native/CitySimNative
  script/build_and_run.sh`: passed.

The merge commit differs from the immutable candidate only by the preserved
quality-owned preregistration history. The staged product and build-script
trees are exact candidate bytes.

## Staged identity

- Candidate ID: `playtest-quality-wf967be0ab5b4`
- Bundle ID/preferences:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Bundle:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- Executable SHA-256:
  `b7514b898c9b9465e8f8a296eaf80cef98c10949b7df1d64ee9c562e4f4766a1`
- Staging-manifest SHA-256:
  `33c57faa8ceb663ffba101441443d3f3b8b840d5961c860de1d89beb166c6cf4`
- Info.plist SHA-256:
  `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`
- Atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`
- Generated-v4 manifest SHA-256:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`
- Fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`

## Live process bindings

| Route | PID | Exact injected data root | Environment |
|---|---:|---|---|
| Regular presentation | 42589 | `/private/tmp/citysim-play058-64dd475-regular.BIgkMp` | `CITYSIM_REGULAR_WINDOW=1` |
| Compact presentation | 44096 | `/private/tmp/citysim-play058-64dd475-compact.MMFDVo` | `CITYSIM_COMPACT_WINDOW=1` |
| Compact Reduce Motion | 46165 | `/private/tmp/citysim-play058-64dd475-reduce.PtaZqH` | `CITYSIM_COMPACT_WINDOW=1`, `CITYSIM_REDUCE_MOTION_PROOF=1` |
| Construction/undo | 48257 | `/private/tmp/citysim-play058-64dd475-build.wwMnZb` | `CITYSIM_REGULAR_WINDOW=1` |

Each PID was independently matched to the exact staged executable. One
candidate process existed per route; every exact PID was terminated afterward,
and the final exact-process search returned no match. No other owner's process
was terminated.

Regular captures are uncropped original 1278x768 decorated-window frames.
Compact captures are uncropped original 900x652 decorated-window frames with
exact 900x600 content.
