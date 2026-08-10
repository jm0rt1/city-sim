# PLAY-085 Claim — VS-001 gameplay consequence/recovery slice

- **Title:** Make the first VS-001 decision consequential, legible, and recoverable
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Worktree:** `/Users/James/.codex/worktrees/73f1/city-sim`
- **Authority baseline:** The current Integration master commit containing this claim
- **Owning thread:** `019fe8f2-43ac-7700-9eaf-e1918d933a35`
- **VS-001 contract:** One map-first build → diagnose → adjust slice in which the
  latest authoritative state explains costs, validity, consequences, remedies,
  cancellation, and recovery. The slice must improve the coherent 20-minute
  understand → decide → observe → diagnose → recover journey.
- **Owned roots:**
  `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests`, and
  `docs/production/evidence/PLAY-085/v3/`
- **Bounded deliverable:** Implement or repair one gameplay-owned consequence
  and recovery slice using existing contracts (the severe-storm recovery path is
  the current candidate), with deterministic fixtures and evidence for state,
  messages, replay, save/resume, and recovery. Preserve existing event timing,
  seed progression, identities, and balance unless the approved contract already
  specifies the change.
- **Dependencies:** `CONTRACT-022`, the existing simulation/persistence APIs,
  and the VS-001 first-wave outcome. New public contracts, UI/renderer behavior,
  art, save schema changes, or cross-lane semantics require Integration escalation.
- **Focused proof:** Gameplay-owned deterministic scenario, replay/fingerprint,
  save/load, undo, and diff/path checks.
- **Independent/full gate:** Integration joins the exact commit for the full
  Swift suite, staged build, and real-app journey; independent QA owns the final
  candidate disposition.
- **Stop/refill:** Stop on identity drift, public-contract or migration need,
  cross-lane semantic conflict, balance ambiguity, or two failed repairs. Refill
  only with another disjoint gameplay-owned fixture/evidence packet after this
  checkpoint is committed.
- **Forbidden:** Renderer, UI/input, package/build, world-art, resources,
  shared claims/contracts, admission, runtime selection, app launch, production,
  push, integration, and self-acceptance.
- **Status:** Fresh current-master claim; route publication and implementation
  remain separately gated.
