# PLAY-076 completion

- **Title:** Grow the opening into a believable starter town
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Implementation baseline:** `227202371574f21f209a62153904b2f4c974dd4b`
- **External claim authority:** `20036691842b0fdd8485ad4a924d5949c4b2e2ec`
- **Ordered task commits:**
  1. `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b` — authoritative starter-town topology, approved two-axis simulation rule, and deterministic tests;
  2. `b0031cf5ed6df87cc55d4a2d293d8c80483765f8` — regular/compact staged journeys, persistence proof, validation record, and additive adoption packet.
- **Status:** Complete in gameplay lane; ready for integration-owned additive adoption and independent acceptance

## Player-visible outcome

New Arcadia now begins as a truthful three-block starter town: 34 connected
road tiles, 12 occupied places, six visibly real Residential lots, four
distinct authored Residential directions, and 40 empty road-frontage growth
choices. No decorative building state was delegated to the renderer.

The richer opening preserves the game:

- unchanged `$32,000` treasury, 300 population, 190 jobs, happiness,
  approval, tax, utility use, and capacity;
- a consequential `-$126.20/cycle` Day 1 operating gap with 54 power and 48
  water spare;
- Commercial and Industrial commitment only at the next daily boundary;
- distinct Day 11 cashflow, job capacity, demand, happiness, pollution, and
  utility consequences;
- four durable, non-flipping recovery identities;
- Town Charter at exact tick 844 and Regional Capital between tick 1024 and
  1040 for every recovery route, inside the tick-2,800 horizon;
- strategy-relative development: no tick-64 upgrade, Industrial first at tick
  128 with reserve utilities, and Commercial first at tick 384 after its
  supporting decision.

## Files changed

Product and deterministic tests:

- `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`
- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/StarterDistrictTests.swift`

Evidence and completion:

- `docs/production/evidence/PLAY-076/IMPLEMENTATION-AND-STAGED-EVIDENCE.md`
- `docs/production/evidence/PLAY-076/ADDITIVE-FIXTURE-ADOPTION.md`
- three staged JPEGs and four raw persistence-gate records under
  `docs/production/evidence/PLAY-076/`
- `docs/production/completed/PLAY-076.gameplay-loop.md`

## Validation and proof

- Focused starter/gameplay matrix: **47/47 passed**.
- Bounded non-adoption corpus: **109/109 passed**.
- PLAY-071 mature development behavior: passed.
- Day 1/11 no-choice, Commercial, and Industrial ledgers: exact.
- Four recovery identities, ignored recovery, Charter/Regional horizon,
  replay, legacy decode, Codable, save/load, backup, fingerprint, and Undo:
  passed deterministically.
- Build-script syntax, staged bundle verification, resource packaging,
  launch, and `git diff --check`: passed.
- Exact staged candidate:
  `gameplay-loop-w8f1a46b88376` at
  `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b`.
- Real regular Commercial and compact Industrial routes both used visible
  pointer controls plus keyboard parcel navigation and reached committed
  strategy at paused Day 5 after a truthful blocked-placement diagnosis.
- The saved Commercial route survived exact same-bundle compact relaunch/load;
  the later Industrial save replaced the quicksave and retained Commercial as
  its backup. The gate terminated only its two candidate-bound PIDs.
- Full proof:
  `docs/production/evidence/PLAY-076/IMPLEMENTATION-AND-STAGED-EVIDENCE.md`.

## Compatibility and contract impact

- No new public or persisted state.
- Save schema and fingerprint version remain unchanged.
- No legacy-load mutation or migration.
- No generic development threshold or `maybeUpgrade` change.
- No forecast value enters demand.
- `nearTermPopulationPotential` is private and is called only by the existing
  prospective development utility-reserve guard.
- No renderer, SpriteKit, SwiftUI, command, package/build, art, fixture,
  shipping-resource, shared-contract, or legacy-Python change.

## Integration-owned dispositions

The complete worker suite did not pass: it executed 264 tests with 353
assertion failures and 6 unexpected failures. The failures are retained and
classified, not dismissed. They are confined to fixed-coordinate consumers,
frozen platform/story/visible digests, renderer references, and the renderer
`2.739 ms` result against its `2.1 ms` budget. Integration/simulation owns
additive fixture adoption; rendering owns the performance/reference
disposition. The exact inputs are in
`docs/production/evidence/PLAY-076/ADDITIVE-FIXTURE-ADOPTION.md`.

This lane does not self-integrate, self-score, or self-accept. Final combined
acceptance requires the adopted exact gameplay product plus independent
staged quality verification.
