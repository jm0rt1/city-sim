# PLAY-055 Candidate Identity

## Git

| Surface | Exact value |
|---|---|
| Combined product | `7b432c4af1ee62553598e70c6103efe7a26e8af9` |
| Quality merge under test | `fc8684a24f5cc36489c9b2b4d8edefe0b6c2e42b` |
| Merge parents | `a6919c2dc991d92d5c6c5946a96c836e4e7a9241`, `7b432c4af1ee62553598e70c6103efe7a26e8af9` |
| Product subtree object at both commits | `2ccdf2cbac36688aef7deeefd95d87f9608c7bac` |
| Build script object at both commits | `f1b5b1f0bdec35be3a7c1cee7e35472daa2a03cb` |
| Branch | `codex/citysim-playtest-quality` |

## Isolated staged app

| Surface | Exact value |
|---|---|
| Candidate ID | `playtest-quality-wf967be0ab5b4` |
| Bundle ID / preference domain | `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4` |
| Bundle | `/Users/James/.codex/worktrees/14c5/city-sim/dist/CitySim-playtest-quality-wf967be0ab5b4.app` |
| Executable | `.../Contents/MacOS/CitySimNative-wf967be0ab5b4` |
| Executable SHA-256 | `78863a8343ccd652441c315e4a52e45fda356adab48a42fd136a3368993632e9` |
| Final staging manifest SHA-256 | `91f2ef287e04c30d2509d543129d7efc74eee414ea024557d8df079726c3ac17` |
| Info.plist SHA-256 | `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe` |
| Atlas manifest SHA-256 | `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d` |
| Generated-v4 manifest SHA-256 | `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe` |

Source and staged generated-v4 manifest and page hashes:

| Resource | SHA-256 |
|---|---|
| `city/page-00.png` | `ddbe4c128c19c6cf89455cc6311fd8c1ee1a0d62a3a24b06d1f2877f4272bde6` |
| `neighborhood/page-00.png` | `d9ffea926ecf424527ef34e60f7b36066949feeeefd3c8cb95ad0fbfcde813d5` |
| `block/page-00.png` | `b1e3a711c8743fb12d916948d9e094051a19b0dcbbd0aa44d5638a7dc99454f0` |
| `block/page-01.png` | `f80a56f21d08d1675d39431cab35a391c000d585994be5b8016962c8be831de8` |

## State, windows and processes

Fixture
`Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-industrial-complication-v1.json`
has SHA-256
`7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`.
Every route loaded seed 42, tick 128, Day 33 paused and reset camera framing
with deterministic `0`.

| Route | PID | Data root | Window/capture | Final RSS | Cleanup |
|---|---:|---|---|---:|---|
| Regular | `55551` | `/private/tmp/citysim-play055-7b432c4/regular` | default content; `1278 × 768` decorated capture | `199184 KiB` / `194.52 MiB` | terminated |
| Compact | `57974` | `/private/tmp/citysim-play055-7b432c4/compact` | exact `900 × 600` content; `900 × 652` decorated capture | `180048 KiB` / `175.83 MiB` | terminated |
| Reduce Motion | `60396` | `/private/tmp/citysim-play055-7b432c4/reduce-motion` | exact `900 × 600` content; `900 × 652` decorated capture | `198912 KiB` / `194.25 MiB` | terminated; defaults restored |
| Staged verify | `62886` | governed staged identity | exact isolated bundle | not retained | terminated |

Post-gate process inspection found no
`CitySimNative-wf967be0ab5b4` process. Separately owned production PID `51487`
remained live at the main-repository `dist/CitySim.app` executable and was not
touched.
