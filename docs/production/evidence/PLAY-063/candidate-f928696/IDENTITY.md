# PLAY-063 Exact Candidate Identity

- Combined candidate and tested source tree:
  `f928696a84676032b20c6306b14d943592e219fb`.
- Immutable preregistration:
  `b9f2aedc985d31329c49d259cbbd1a303b021047`.
- PLAY-062 product:
  `02612e414912fdabcab858b0ca97e1f5edbc2757`.
- PLAY-062 admission evidence:
  `7ea9971f58f9c86cb17c1b978c7af3ae9b230cae`.
- Accepted Industrial source authority:
  `79668c347e58d602f9627c73cb09e3272a83ef57`.
- Frozen published baseline:
  `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`.
- Branch:
  `codex/citysim-playtest-quality`.
- Candidate ID:
  `playtest-quality-wf967be0ab5b4`.
- Bundle ID and defaults domain:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`.
- Staged bundle:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app`.
- Executable:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`.
- Resource bundle:
  `dist/CitySim-playtest-quality-wf967be0ab5b4.app/CitySimNative_CitySimNative.bundle`.
- Staging manifest:
  `dist/manifests/playtest-quality-wf967be0ab5b4.manifest`.
- Staging manifest SHA-256:
  `076da86b3061eeaef1559ad8b88fdf229c892a959a275d4dc9d458b4de2e61b7`.
- Executable SHA-256:
  `3c4a58a444e481b10d2a64da0d36b9f53fa777522657069c4692abafabee7a5c`.
- `Info.plist` SHA-256:
  `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`.
- Source and staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.
- Source/staged manifest byte comparison:
  exit `0`.
- Frozen fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`.
- Loaded envelope digest:
  `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`.

`identity/staged-candidate.manifest` is the exact staging record retained
before live interaction. `identity/live-image-dimensions.txt` records every
retained decorated-window image dimension. Regular captures are 1278 x 768.
Compact captures are 900 x 652 decorated windows around exact 900 x 600 app
content. No capture was cropped or resized.

## Live process binding

Every quality route launched the exact executable above with one isolated
quality PID. Integration PID `93032` and the other owners' distinct bundle
identities were observed but not terminated or used.

| Route | PID | Required environment | Point RSS |
|---|---:|---|---:|
| Staged verify | 94284 | manifest data root | 148,752 KiB |
| Regular same-state/keyboard/build/undo/save | 96765 | `CITYSIM_REGULAR_WINDOW=1`; regular isolated root | 147,056 KiB settled |
| Regular save-relaunch-load | 99742 | same explicit regular route/root | 230,208 KiB launch sample |
| Compact same-state/Details/FKA/overlays/Focus | 403 | `CITYSIM_COMPACT_WINDOW=1`; compact isolated root | 200,448 KiB settled |
| Compact Reduce Motion | 2395 | compact plus `CITYSIM_REDUCE_MOTION_PROOF=1`; reduce root | 126,288 KiB settled |
| Regular city LOD | 7001 | regular plus `CITYSIM_PROOF_CAMERA_SCALE=0.85` | not sampled |
| Regular neighborhood LOD | 8134 | regular plus `CITYSIM_PROOF_CAMERA_SCALE=0.65` | not sampled |
| Regular block LOD | 8730 | regular plus `CITYSIM_PROOF_CAMERA_SCALE=0.50` | not sampled |
| Compact block LOD | 9715 | compact plus `CITYSIM_PROOF_CAMERA_SCALE=0.45` | 223,872 KiB |
| Regular pointer and AX route | 11855 | regular plus proof scale `0.50` | not sampled |

The regular, compact, and Reduce Motion roots were respectively:

- `/private/tmp/citysim-play063-f928696-regular`;
- `/private/tmp/citysim-play063-f928696-compact`; and
- `/private/tmp/citysim-play063-f928696-reduce`.

Each route started from the byte-identical fixture. Every listed quality PID
was terminated with `SIGTERM` after capture. No other owner's PID was
terminated.
