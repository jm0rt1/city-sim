# PLAY-021 Immutable Before Evidence

- **Integrated source commit:** `b8cb4740b9cf94aa04482539f9909ffb22dbdbea`
- **Renderer product ancestor:** `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209`
- **Bundle:** `dist/CitySim-world-rendering.app`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering`
- **Isolated data root:** `dist/test-data/world-rendering`
- **Capture window:** 1228 × 768 including native chrome
- **Baseline process observation:** 139,344 KB RSS

## Fresh integrated captures

- `before-default-live.jpeg` — SHA-256 `ebb7a395c3d1d3e196144c2e92c68f4bb52ad350e2d58e99a2e3f7d75e85e858`
- `before-same-camera-live.jpeg` — SHA-256 `7add34095886f20165065267abbdde8521f336f4ed697978136ad7ee52ef353d`

The first image retains the accepted onboarding composition. The second dismisses
onboarding without changing the camera, city, speed, save, selection, or build
state. Both were captured before any PLAY-021 visual source or resource edit.

## Accepted PLAY-020 immutable references

- `docs/visuals/citysim-play020-wave2-default-live.jpeg` — SHA-256 `042bc6a44f289400ff1b74704892bb12e246c43e7a79b37018ffbad5e560f017`
- `docs/visuals/citysim-play020-wave2-compact-live.jpeg` — SHA-256 `35a099284d26abd623fc2373d7322b5694ec5c3f57df1bb64752cb667de0fe64`
- `docs/visuals/citysim-play020-wave2-city-live.jpeg` — SHA-256 `863c2dc27c2db93efc57563706c37b63eb97dea7f3f49b95c437c275696b9301`
- `docs/visuals/citysim-play020-wave2-block-live.jpeg` — SHA-256 `b90ac6469cc9914b4a136a7b642f293916242746deaeb99e679758efaa9fefdb`

These existing files remain byte-for-byte unchanged and are not represented as
proof of the later integrated UI composition.

## Art-direction reference provenance

`art-direction-reference.png` is a non-shipping OpenAI image-generation concept
created July 19, 2026 from a text prompt for a cohesive isometric miniature city.
SHA-256: `61808086d4fa4b09104cd60d3784e9df29d87cd9da8a5494af4aa2c3c2d5a6e9`.
It sets broad composition, material, palette, and light-direction intent only.
No generated pixel is sampled or shipped in `WorldAssets.atlas`.
