# PLAY-050 Baseline Candidate Manifest

## Candidate identity

- Product commit: `c4460255ca810ce4de878f20f98a883983cf3dbd`
- Evidence-contract commit: `14b5c21`
- Branch: `codex/citysim-playtest-quality`
- Journey: `critical-journey-v1`
- Staged app: `dist/CitySim.app`
- Product-code delta from baseline: none
- Overall disposition: **failed**, with the integrated 20-minute gate also **blocked** on PLAY-010/020/030/040 contracts

## Independent validation

| Check | Result |
| --- | --- |
| `swift test --package-path Native/CitySimNative` with writable module caches | 35 passed, 0 failed in 22.582 seconds |
| `git diff --check` | Passed |
| `bash -n script/build_and_run.sh` | Passed |
| `./script/build_and_run.sh --verify` with writable module caches | Built, staged, launched, and found `CitySimNative` |
| Real-app inspection | Performed through the staged `.app` using macOS accessibility state and retained screenshots |

The first sandboxed test attempt failed before product compilation because Swift could not write its module cache. The escalated rerun used `/private/tmp/citysim-play050-clang-cache` and `/private/tmp/citysim-play050-swiftpm-cache`; it is the reported candidate result.

Test diagnostics reported:

- initial tiles: 576;
- initial nodes: 10,309;
- ten-pulse tile reuse: 5,760 reused, 0 updated;
- average ten-pulse render update: 1.811 ms;
- overlay nodes: 1,533.

These diagnostics are supporting evidence, not a mature-city performance qualification.

## Proof inventory

| Artifact | SHA-256 | Provenance | What it proves | Limitation |
| --- | --- | --- | --- | --- |
| `visuals/first-run-day19-onboarding.jpg` | `8db277db94e1a4cf08d1fe93c4569532d206631e9cc0f6cbf1981249547dfc9a` | Computer Use capture of staged app | Welcome overlay can coexist with advanced Day 19 state | Preference was forced false to reproduce onboarding; not a valid timed fresh-player run |
| `visuals/save-resume-day42.jpg` | `beaa2d7b4d78869c77cf711937ba8a74ceabdd0f87486e21191f094e6b1dfd06` | Computer Use capture after quit/relaunch/⌘O | Day 42 values reload and the simulation resumes paused | No versioned save manifest or authoritative state hash exists |
| `visuals/compact-900x600-command-center.jpg` | `4abd236cb5a570292a5e7418417b8abb03b42760d959f214800ab29fcacb824d` | Computer Use capture with `CITYSIM_COMPACT_WINDOW=1` | Compact command center alone is legible and actionable | Does not cover simultaneous objectives panel |
| `visuals/compact-objectives-details-clipped.jpg` | `e6fe406930eff2937942ff31a9d3b56be94d3d3f359bbd8dd2bc720ea2c97ceb` | Computer Use capture after ⌘J and ⌥⌘I | Simultaneous compact surfaces push command-center content below the usable window | Static proof is paired with AX output showing an empty details collection |

## Save hygiene

There was no pre-existing CitySim quicksave. PLAY-050 created one through the real app, observed SHA-256 `6b59d11e5e610065db0331eea7794ffe74d0b86b08ee10d524632592cc015d95`, then moved only that created file to `/private/tmp/citysim-play050-quicksave-c446025.json`. The original preferences were restored to `hasSeenCitySimWelcome=1` and `reduceGameMotion=0` after the run.

## Dependencies

- PLAY-010: authoritative pressure, Town Charter milestone, two strategies, overextension, and recovery invariants.
- PLAY-020: named truthful pressure/recovery world states and camera bookmarks.
- PLAY-030: governed non-spatial command inventory, focus contract, Full Keyboard Access scope, and compact surface arbitration.
- PLAY-040: stable fixture ID, seed, version, state hash, versioned save, replay, and isolated recovery contract.

## Shared-contract proposal for integration review

Independent save/resume testing currently targets the player's fixed Application Support path. Before the integrated gate, approve the smallest debug/test-only save-root injection that leaves the production default unchanged. This affects simulation platform, integration launch tooling, and playtest quality. Compatibility tests should prove that the default URL is unchanged, an explicit temporary root is honored, and production saves cannot be silently redirected. PLAY-050 does not implement this proposal.
