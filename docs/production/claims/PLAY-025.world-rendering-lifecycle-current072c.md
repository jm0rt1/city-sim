# PLAY-025 Current Lifecycle-Legibility Claim

- **Player outcome:** Construction, weathered damage, distress, and recovery are unmistakable on the shipping residential families without labels, invented state, or loss of map readability.
- **Owner:** Agent 401 Renderer/Runtime Lead, thread `019fec7c-28ee-7691-80fd-6ee62f33212c`.
- **Authority:** Integration master `072c127678ea02abe06ec38b1253a512fcc2b44b`; accepted product remains `e6d359c6306d26aeb0e4d0b6af2836064e710bb5`.
- **Branch/worktree:** `codex/citysim-world-rendering-play025-lifecycle-current072c` at `/private/tmp/citysim-play025-lifecycle-current072c`.
- **Maximum mutable product/test paths:**
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldOverlayRenderer.swift`
  - `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- **Task-local additions:** `docs/production/evidence/PLAY-025/current072c-lifecycle/` and `docs/production/completed/PLAY-025.world-rendering-lifecycle-current072c.md` only.
- **First action:** Compare the same authoritative residential lot at construction, maintained, weathered, distressed, and recovered states at block/neighborhood/city LODs and regular/exact 900×600 layouts. If the distinction is already materially clear, return `NO_REAL_GAP` with evidence and no product mutation.
- **Implementation boundary:** If one concrete deficiency exists, change only existing lifecycle material/opacity/overlay presentation. Preserve tile truth, thresholds, geometry, assets, atlas bytes, camera, roads, hit testing, selection, buildability, simulation, UI/input, save state, Reduce Motion meaning, node/draw budgets, and every accepted process.
- **Proof:** One focused `WorldRenderingTests` invocation covering lifecycle classification, construction stages, condition transitions, same-coordinate recovery, all three LODs, and bounded diagnostics; retain same-state regular/compact captures. One bounded local repair is permitted. PASS may stage explicit claimed paths and create one coherent `PLAY-025:` commit; any second failure, path expansion, invented truth, or unreadable state returns the preserved candidate.
- **Integration boundary:** No aggregate, stage build, app launch, PID signal, QA, packaging, push, release, or self-acceptance.
- **Status:** active outcome-fast-path claim.
