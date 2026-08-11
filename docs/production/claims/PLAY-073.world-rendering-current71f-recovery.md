# PLAY-073 Claim — current-baseline focus-safe recovery

- **Title:** Keep the developed focus inside the honest camera aperture
- **Lane owner:** Agent 401 — Renderer and Runtime Lead
- **Owning task:** `019fec7c-28ee-7691-80fd-6ee62f33212c`
- **Branch:** `codex/citysim-world-rendering-play073-current71f`
- **Worktree:** `/private/tmp/citysim-play073-current71f-recovery`
- **Governance baseline:** current claim-bearing descendant of
  `8f538aeb0ddc8873252d4d6ba6191125143c509a`
- **Accepted product candidate:** `4b57e43c4e2329a7d83b97494ea9e9942ba69814`
- **Historical preservation only:** `/Users/James/.codex/worktrees/abfe/city-sim`
  remains at `d3f2c47601bb40fcb09d5d20377bcbe1fe06b532` with exactly two dirty files:
  `CityScene.swift` SHA-256 `3b953c311eb39b7a2dd9c52267d853de3b4eb917846195fcbb6141bc59eabeb3`,
  `WorldRenderingTests.swift` SHA-256 `d96545b6ef3d6a5173152b3d7fab150b695575fcd5257ec0c49b356b6c82173e`,
  binary-diff SHA-256 `8bbed66386ff1498123d648024bc95c95a4b7bc44e9a9ece249fa5735bd14c98`.
  Those bytes are evidence only and may not be copied wholesale, edited,
  staged, cleaned, or used as a worker baseline.
- **Allowed paths:**
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
  - `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
  - `docs/production/evidence/PLAY-073/current71f-focus-safe-recovery/`
  - `docs/production/completed/PLAY-073.world-rendering-focus-safe-recovery.md`
- **Frozen outcome:** adapt the intended focus-only, minimal axis translation to
  current fixtures after the existing developed-city camera fit. Preserve zoom,
  scale, LOD, resource selection, topology, occupancy, hit testing, state,
  performance ceilings, and all non-focus composition behavior. The focused
  test must independently derive and assert the current-fixture focus bounds,
  safe viewport margin, minimal translation, deterministic repeat, and
  unchanged composition invariants.
- **Focused proof:** one route-listed SwiftPM invocation selecting the exact
  current PLAY-073 focus-safe renderer test, plus `git diff --check`.
- **Commit:** one coherent `PLAY-073:` commit staging only actual changed paths.
- **Forbidden:** fixture/corpus mutation; asset/resource/art/source admission;
  simulation/gameplay/UI/input/save/package/build changes; historical `/abfe`
  mutation; aggregate/build/app/QA/push/integration/release actions.
- **Stop:** current fixtures make the frozen focus-only translation ambiguous;
  zoom or shared contract must change; any composition/LOD/resource/state or
  path invariant drifts; focused proof fails twice; or subjective visual
  acceptance is required.
- **Status:** ready for a validated schema-2 outcome lease after the fresh
  current-baseline worktree is created at the claim-bearing authority commit.
