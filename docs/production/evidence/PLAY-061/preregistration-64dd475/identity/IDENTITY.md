# PLAY-061 Frozen Baseline Identity

## Git identity

- Published authority:
  `91f885925fd601786fa95dbb969b71fefef5ddcd`
- Frozen product:
  `64dd47500fe5e2d4a32a64f6298ded5789d3b773`
- Accepted Commercial source:
  `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`
- Branch:
  `codex/citysim-playtest-quality`
- Frozen product/build parity:
  `git diff --quiet 64dd475..91f8859 -- Native/CitySimNative/Sources
  Native/CitySimNative/Resources Native/CitySimNative/Package.swift
  script/build_and_run.sh` passed.

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
  `fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a`

The staging manifest records evidence-branch commit `37107ea` because the
retained bundle was originally staged for exact accepted candidate `64dd475`.
Its product and build-script trees are byte-identical to the frozen candidate
and to published authority `91f8859`.

## Process binding

All captures used the exact bundle ID and executable above, one quality process
per route, and isolated `/private/tmp/citysim-play061-64dd475-*` data roots.
The regular route injected `CITYSIM_REGULAR_WINDOW=1`; compact routes injected
`CITYSIM_COMPACT_WINDOW=1`; Reduce Motion added
`CITYSIM_REDUCE_MOTION_PROOF=1`; explicit compact LOD routes added
`CITYSIM_PROOF_CAMERA_SCALE` with values `0.576345682144165`, `0.52`, or
`0.45`.

Exact PIDs were 74387, 77001, 78748, 85416, 86532, and 88764. Each process was
terminated after its route. The final exact-executable process search returned
no live PID.

Regular evidence is uncropped 1278 x 768. Compact evidence is uncropped 900 x
652 with exact 900 x 600 app content.
