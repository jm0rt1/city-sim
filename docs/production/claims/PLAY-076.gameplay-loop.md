# PLAY-076 Claim

- **Title:** Grow the opening into a believable starter town
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Worktree:** `/Users/James/.codex/worktrees/80f0/city-sim`
- **Base authority:** Next published clean integration baseline containing this claim and accepted PLAY-071 product
- **Planned surfaces:** `CityGameState.newCity`, starter/gameplay tests, `docs/production/evidence/PLAY-076/`, and `docs/production/completed/PLAY-076.gameplay-loop.md`
- **Dependencies:** Accepted PLAY-071; exact PLAY-073 real-app sparse-opening finding; published clean baseline; existing building/frontage/progression/recovery contracts
- **Validation/proof:** Exact topology/frontage ledger; Day 1/11 no-choice, Commercial, and Industrial balance; four recovery identities; Charter and Regional Capital inside tick 2,800; PLAY-071 upgrade behavior; deterministic replay; Codable/legacy/save/load/backup/undo; full suite; staged regular/compact pointer and keyboard journeys; additive fixture-adoption packet
- **Status:** Corrected topology authority prepared from the machine-checked
  read-only search; implementation begins only after integration publishes and
  dispatches the exact containing baseline

Build the smallest authoritative opening that reads as a town instead of asking
the renderer to invent population. The corrected, machine-checked target is
exactly 34 connected roads and 12 occupied places across three developed
blocks:

- preserve every accepted occupied place except relocate the Residential at
  `(9,11)` one tile north to `(9,10)`;
- add the internal road divider at `(8,10)` and `(8,11)`; and
- add Residential lots at `(6,10)`, `(6,11)`, `(3,10)`, and `(17,10)`.

This is the minimum full-goal repair: leaving both accepted Residential
coordinates fixed is unsatisfiable because `(9,11)` and `(10,11)` both select
the south frontage and remain an adjacent source alias. The corrected layout
preserves 40 valid empty growth frontages, at least two useful internal parcels
in every block, and no adjacent Residential source alias anywhere in the
opening.

The four new homes must select the truthful authored directions `(6,10)` north,
`(6,11)` south, `(3,10)` east, and `(17,10)` west. The relocated `(9,10)`
home selects north while the retained `(10,11)` home selects south. Do not
start with an additional Commercial, Industrial, park, utility, or service
building; those choices belong to the player. Keep treasury, population, jobs,
happiness, tax rate, utility use/capacity, and public/save shapes unchanged.
The topology-only opening is expected to remain treasury-negative at
`-$126.20/cycle` with 54 power and 48 water spare; starting demand and opening
copy may change narrowly only if exact Day 1/11 scenario tests require it.

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
