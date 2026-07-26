# PLAY-078 Claim

- **Title:** Adopt the starter town without rewriting history
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** Next published clean integration commit containing this
  claim
- **Product input:** Frozen PLAY-076 gameplay product
  `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b`
- **Planned surfaces:** `ProductionStoryStateFixtureSupport.swift`,
  `ProductionStoryStateFixtureTests.swift`,
  `VisibleCityStateFixtureSupport.swift`,
  `VisibleCityStateFixtureTests.swift`, `SessionPlatformTests.swift`,
  `StrategyResolutionPlatformTests.swift`,
  `TerminalVictoryPlatformTests.swift`, `SpatialConsequenceTests.swift`,
  simulation-owned `CitySimulationTests.swift`, additive StoryStates v4 and
  VisibleCityStates v3 resources, `docs/production/evidence/PLAY-078/`, and
  `docs/production/completed/PLAY-078.simulation-platform.md`
- **Dependencies:** Published claim authority; clean preserved PLAY-072
  platform lane; exact PLAY-076 product object; existing schema-one,
  fingerprint-v1, replay, snapshot, and fixture-generation contracts
- **Validation/proof:** Historical-corpus byte preservation; two-root
  generation identity; exact manifest/product linkage; focused fixture and
  platform matrix; complete non-renderer suite; full-suite ownership
  classification; staged verification; size/time/memory comparison
- **Status:** Prepared from a clean read-only platform preflight; implementation
  waits for the exact containing integration baseline and routing instructions

Adopt the new current product without mutating history. Preserve StoryStates
v1-v3 and VisibleCityStates v1-v2 byte-for-byte. Add exactly:

- `story-states-manifest-v4.json` and twelve `*-v4.json` story fixtures;
- `visible-city-states-manifest-v3.json` and fourteen `*-v3.json` visible-city
  fixtures.

The new visible manifest must bind to the exact combined PLAY-076 product
authority and generated StoryStates v4 manifest hash. Generate both corpora
twice in independent temporary roots and require recursive byte identity.
Add explicit preservation gates for PLAY-072 Story v3 and Visible v2 while
retaining the authentic v1/v2 checks unchanged.

Replace only deterministic test commands made invalid by the new topology.
Use the row-major road-accessible sequence `(4,8)`, `(5,8)`, `(6,8)`,
`(7,8)` for strategy and recovery preparation. Do not overwrite the new road
at `(8,11)` or the Residential lot at `(6,11)`.

No persisted field, public snapshot shape, command type, save schema,
fingerprint algorithm/version, or load migration changes. Old saves must
continue to decode without mutation. Subsequent ticks legitimately use the
current demand rule and must compare equivalent current-code replays, not
obsolete engine outcomes.

Renderer-owned references, camera expectations, node/draw counts, snapshot
exports, and the 2.1 ms unchanged-pulse budget remain outside this claim.
Return those failures with exact evidence; never relax or re-bless them.

Do not touch PLAY-076 gameplay rules/tests, SpriteKit renderer sources,
SwiftUI/UI, art, shipping manifests, package/build scripts, shared public
contracts, or legacy Python. Commit coherent contract-adoption, generated
fixture, test, evidence, and completion outcomes separately. Do not push,
integrate, self-score, self-accept, or pin.
