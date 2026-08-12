# PLAY-085 Current Claim — Severe storm recovery remains a player-visible loop

- **Lane / owner:** Gameplay — Agent 101, Gameplay Lead.
- **Authority / base:** `b7580a580b9c85f63e7686b2f948af5978a6582b`.
- **Existing authority:** `docs/production/claims/PLAY-085.gameplay-loop.md`
  and its approved CONTRACT-022 recovery ownership boundary.
- **Player outcome:** A qualifying severe storm visibly damages residential
  condition, states the protective/recovery inputs, and completes only after
  sustained healthy operation—without changing the established storm schedule,
  seed advancement, treasury/happiness effect, balance, or save schema.
- **Maximum paths:**
  `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`,
  focused gameplay tests, `docs/production/evidence/PLAY-085/currentb758/`, and
  `docs/production/completed/PLAY-085.gameplay-loop-currentb758.md`.
- **Proof / stop:** Prove a fixed-seed severe-storm damage → mitigation →
  recovery sequence plus replay/save/load stability using focused deterministic
  tests. One local repair is allowed. Stop on a save/schema/migration need,
  economy/pacing rebalance, renderer/UI change, a second focused failure, or an
  already-complete current implementation with no specific source-backed gap.
