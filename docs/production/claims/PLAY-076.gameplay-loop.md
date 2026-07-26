# PLAY-076 Claim

- **Title:** Grow the opening into a believable starter town
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Worktree:** `/Users/James/.codex/worktrees/80f0/city-sim`
- **Base authority:** Next published clean integration baseline containing this claim and accepted PLAY-071 product
- **Planned surfaces:** `CityGameState.newCity`, starter/gameplay tests, `docs/production/evidence/PLAY-076/`, and `docs/production/completed/PLAY-076.gameplay-loop.md`
- **Dependencies:** Accepted PLAY-071; exact PLAY-073 real-app sparse-opening finding; published clean baseline; existing building/frontage/progression/recovery contracts
- **Validation/proof:** Exact topology/frontage ledger; Day 1/11 no-choice, Commercial, and Industrial balance; four recovery identities; Charter and Regional Capital inside tick 2,800; PLAY-071 upgrade behavior; deterministic replay; Codable/legacy/save/load/backup/undo; full suite; staged regular/compact pointer and keyboard journeys; additive fixture-adoption packet
- **Status:** Prepared by integration from the immutable gameplay readiness audit; implementation is blocked until integration publishes and dispatches the next clean baseline

Build the smallest authoritative opening that reads as a town instead of asking
the renderer to invent population. The audited target is exactly 34 connected
roads and 12 occupied places across three developed blocks: preserve all eight
current occupied coordinates, add the internal road divider at `(8,10)` and
`(8,11)`, and add Residential lots at `(5,10)`, `(6,10)`, `(5,11)`, and
`(6,11)`. Preserve 40 valid empty growth frontages and at least two useful
internal parcels in every block.

The four new homes must use their truthful road frontage so accepted N/E/S/W
art and deterministic context can break adjacent repetition without new
renderer state. Do not start with an additional Commercial, Industrial, park,
utility, or service building; those choices belong to the player. Keep
treasury, population, jobs, happiness, tax rate, utility use/capacity, and
public/save shapes unchanged unless exact Swift scenario tests disprove the
audited balance. Starting demand and opening copy may change narrowly.

Return exact Day 1 and Day 11 Swift evidence for no choice and both strategies,
then prove warning, recovery, Town Charter, Regional Capital, PLAY-071
strategy-relative upgrades, replay, Codable compatibility, legacy saves,
save/load, backup, and undo. Downstream fixture versions are additive and
belong to integration/simulation; never rewrite accepted fixture history.

Do not touch SpriteKit, SwiftUI, commands, package/build scripts, shared
contracts, art selection, shipping resources, or legacy Python. Do not sync or
mutate before integration publishes the exact baseline and sends a visible
dispatch. Commit coherent product, test, evidence, and completion outcomes
separately. Do not push, integrate, self-score, self-accept, or pin.
