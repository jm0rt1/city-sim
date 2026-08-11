# PLAY-076 Paused New Region Repair Claim

- **Title:** Start every new region visibly paused on Day 1
- **Lane:** UI and input
- **Owner:** Agent 301 UI/Input Lead, thread `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-play076-paused-new-region-current9898`
- **Worktree:** `/private/tmp/citysim-play076-paused-new-region-current9898`
- **Authority baseline:** Integration master `98982787181131ee9c6857436b50558127d71e51`, tree `46fb7aed824b40a621d1eea66bb058d47a29cf72`
- **Player outcome:** File → New Region immediately presents the authored starter town at tick 0 / Day 1 in a visibly paused state; the first Resume advances at normal 1× speed.
- **Allowed mutation paths:**
  - `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
  - `Native/CitySimNative/Tests/CitySimNativeTests/GameStatusOverlayTests.swift`
- **Required implementation:** In `CityGameStore.newCity()`, preserve the existing fresh-state, tool, focus, and feedback behavior; set the visible speed to `.paused` while retaining `lastNonPausedSpeed = .normal`.
- **Focused proof:** Update the existing New Region store test to require tick 0, Day 1, paused immediately after the transition, then require the first pause/resume action to restore `.normal`. Run that focused test once with isolated writable SwiftPM caches.
- **Commit boundary:** Stage exactly the two allowed paths and create one coherent commit with subject `PLAY-076: Start new regions visibly paused`.
- **Integration/QA boundary:** Agent 003 alone integrates a passing candidate, then runs one exact-candidate aggregate suite and one stage-only build. Independent Agent 004 QA then proves Day 1 paused and Day 11 on the fresh built candidate.
- **Frozen:** Every other product, test, claim, evidence, renderer, simulation, gameplay, art, build, package, and protected-dirt byte; existing PID `76765` remains untouched until the new candidate is ready for an exact QA handoff.
- **Stop:** Return on identity mismatch, an additional required path, any change beyond the new-region startup speed contract and focused expectations, focused failure after the one bounded local repair, or any save/schema/simulation/rendering/UI-layout consequence.
- **Status:** `active`
