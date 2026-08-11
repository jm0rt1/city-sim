# PLAY-073 Claim — current-baseline focus-safe recovery

- **Title:** Keep the developed focus inside the honest camera aperture
- **Lane owner:** Agent 401 — Renderer and Runtime Lead
- **Owning task:** `019fec7c-28ee-7691-80fd-6ee62f33212c`
- **Branch:** `codex/citysim-world-rendering-play073-beta-current21e1`
- **Worktree:** `/private/tmp/citysim-play073-beta-current21e1`
- **Governance baseline:** the claim-bearing descendant of
  `21e1d5d024a9a0a4ae598c86423da694b60c5eae`
- **Accepted product candidate:** `65c0f4dd2054baa0446d4e9c9a3673dfb4a01521`
- **Historical preservation only:** `/Users/James/.codex/worktrees/abfe/city-sim`
  remains at `d3f2c47601bb40fcb09d5d20377bcbe1fe06b532` with exactly two dirty files:
  `CityScene.swift` SHA-256 `3b953c311eb39b7a2dd9c52267d853de3b4eb917846195fcbb6141bc59eabeb3`,
  `WorldRenderingTests.swift` SHA-256 `d96545b6ef3d6a5173152b3d7fab150b695575fcd5257ec0c49b356b6c82173e`,
  binary-diff SHA-256 `8bbed66386ff1498123d648024bc95c95a4b7bc44e9a9ece249fa5735bd14c98`.
  Those bytes are evidence only and may not be copied wholesale, edited,
  staged, cleaned, or used as a worker baseline.
- **Excluded current recovery preservation:**
  `/private/tmp/citysim-play073-current71f-recovery` remains at
  `9e09123cd50373f788ebbc24066a89774c8d123a` with its exact two dirty files
  and all prior focused receipts. It is evidence only and may not be cleaned,
  resumed, copied wholesale, or used as the Beta worker baseline.
- **Allowed paths:**
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
  - `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
  - `docs/production/evidence/PLAY-073/current71f-focus-safe-recovery/`
  - `docs/production/completed/PLAY-073.world-rendering-focus-safe-recovery.md`
- **Frozen outcome:** first map every retained failure line to the exact current
  assertion and axis. Then adapt the intended focus-only, minimal axis
  translation to current fixtures after the existing developed-city camera fit.
  `CityScene.swift` is frozen unless that current mapping proves a product
  defect that the accepted intent actually requires correcting. Preserve zoom,
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
- **Stop:** any failure line cannot be mapped to the current assertion/axis;
  current fixtures make the frozen focus-only translation ambiguous;
  zoom or shared contract must change; any composition/LOD/resource/state or
  path invariant drifts; the single focused proof fails; or subjective visual
  acceptance is required. No repair carousel is authorized.
- **Status:** ready for one validated current-baseline outcome lease after the
  fresh worktree is created at this claim-bearing authority commit.
