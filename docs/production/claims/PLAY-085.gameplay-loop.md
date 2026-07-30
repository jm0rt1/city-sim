# PLAY-085 Claim — revision 2

- **Title:** Make severe storms visibly damage and recover the town
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Worktree:** `/Users/James/.codex/worktrees/80f0/city-sim`
- **Base authority:** Next published clean Integration commit containing this
  claim
- **Planned surfaces:**
  `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`,
  gameplay-owned tests, `docs/production/evidence/PLAY-085/`, and
  `docs/production/completed/PLAY-085.gameplay-loop.md`
- **Dependencies:** PLAY-076 product integrated at patch-equivalent
  `a2e984a57db0cb83e00d3be515df32d0cea438e8`; existing condition/event/utility/
  park/service/message/replay/save contracts
- **Shared contract:** Approved
  `docs/production/decisions/CONTRACT-022-durable-storm-recovery-ownership.md`
- **Validation/proof:** Exact seed/target/reduction ledger; mitigation and
  12-day repair matrix; messages; strategy-scar isolation; replay/save/undo;
  four strategy/recovery scenarios; complete native suite
- **Status:** Returned candidate preserved; revision-2 repair approved after
  exact published-baseline synchronization

Keep the existing Severe Storm schedule, title, random-seed advancement,
treasury loss, and happiness effect. Extend the event only through stable,
coordinate-ordered completed Residential condition changes. Use existing
utility reserve, parks, and service coverage to mitigate damage and accelerate
repair. Repair only Residential storm damage through sustained healthy
operation; never generically heal Commercial/Industrial strategy scars.

An unmitigated qualifying storm must make at least one lot cross the renderer's
existing weathered threshold. Damage must remain recoverable without changing
kind, level, occupancy, or construction. Messages must truthfully name the
affected count, protective inputs, remedy, and completion. Preserve the exact
seed sequence, fingerprints, replay, undo, persistence, all four strategy
routes, progression, and balance.

Add only the optional internal Codable recovery ownership state approved by
CONTRACT-022. Do not add any other state or public contract; edit
renderer/UI/input/fixtures/package/build/SaveGameService; change schema or
fingerprint versions, event cadence, title, or message capacity; rebalance
generic demand/development/progression; rewrite history; touch art or legacy
Python; push, integrate, pin, self-score, or self-accept. Stop on any such need.
