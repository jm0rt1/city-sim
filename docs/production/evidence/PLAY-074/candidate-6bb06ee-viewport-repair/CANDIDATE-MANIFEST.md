# PLAY-074 Viewport Repair Candidate Manifest

- Branch: `codex/citysim-ui-input`
- Accepted return base: `f8124286f0b12a8433dc5d58d467909cba37e4e5`
- Product commit: `6bb06ee291fe3e7cac8ea7b7c74e367033650ab5`
- Candidate ID: `ui-input-wdbeadac6e0bd`
- Bundle identifier: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged bundle: `dist/CitySim-ui-input-wdbeadac6e0bd.app`
- Executable SHA-256:
  `65a7c36f60f4f8d5b96ea83870d4a5ffea30b858d5cce50bf0af91119c1a7350`
- Retained staging-manifest SHA-256:
  `b8464493a0baf11a5328c721d27e5bcd4b394fa52d47adeb72cdeefa9a4bf1b7`
- Exact `--verify` PID: `36146` (stopped after verification)
- Fixture:
  `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-industrial-complication-v1.json`
- Fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`
- Fixture state: Day 33 / tick 128 / paused / treasury $34,037 /
  +$93 per cycle / population 9 / workforce 14 / 12 notices
- Live-proof environment: `CITYSIM_REDUCE_MOTION_PROOF=1`
- Final candidate process status: stopped; no matching process remained

The retained `staging.manifest` is the immutable launch-time record and
therefore says `verified-running`. The PID was terminated after the journey;
the zero-process result is recorded in `VALIDATION.md`.
