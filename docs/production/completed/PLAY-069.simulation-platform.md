# PLAY-069 Completion — Regional Capital Runtime Trust

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration; dependent consumer gates disclosed
- **Mutation base:** `ca7c29d263e1a2554b728cfa62f0149af7427411`
- **Contract:** `CONTRACT-015`
- **Product/tests/fixtures:** `4d9c20980d1881b775a5866effeedea5ab6aab19`
- **Evidence:** `docs/production/evidence/PLAY-069/4d9c209/VALIDATION.md`
- **Evidence/completion commit:** this commit

## Outcome

The platform now freezes the current Regional Capital runtime in twelve
deterministic story identities while preserving all eight historical Town
Charter fixtures and their manifest byte-for-byte as authentic
missing-`secondAct` inputs.

Six opening/complication/recovery identities remain unchanged. Two explicit
Charter-midpoint identities are playing at tick 844. Four recovery-specific
Regional Capital identities are won, immutable, fingerprinted, saveable,
recoverable, replayable, undo-safe, and snapshot-identical.

## Exact changed surfaces

Product-independent test support and platform tests:

- `Native/CitySimNative/Tests/CitySimNativeTests/ProductionStoryStateFixtureSupport.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/ProductionStoryStateFixtureTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SpatialConsequenceTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/TerminalVictoryPlatformTests.swift`
- six additive `Fixtures/StoryStates/*-v2.json` state files
- `Fixtures/StoryStates/story-states-manifest-v2.json`

Disposition:

- `docs/production/evidence/PLAY-069/4d9c209/VALIDATION.md`
- `docs/production/claims/PLAY-069.simulation-platform.md`
- `docs/production/completed/PLAY-069.simulation-platform.md`

No production source, gameplay, UI, renderer, package, build script, authentic
legacy fixture, schema/fingerprint version, or legacy Python file changed.

## Acceptance summary

- Platform matrix: 39/39 passed.
- Two current-corpus builds: byte-identical.
- Four terminal routes: exact tick, resolution, digest, persistence, backup,
  replay, undo, post-terminal rejection, analytics, and spatial snapshot.
- Authentic schema-0/schema-1 and all `v1` hashes: unchanged.
- Existing save, fingerprint, snapshot, spatial, size, time, and memory budgets:
  passed.
- Exact staged isolated candidate: built, launched, manifest-verified, and
  terminated by its own PID.

The complete suite executed 234 tests with eight assertions across three
dependent UI/renderer tests. Those failures are precisely recorded in the
validation evidence. They are downstream corpus/action-disposition/performance
adoption work and were not hidden or repaired across lane boundaries.

## Integration and rollback

Integrate the PLAY-069 product/tests/fixtures commit before dependent HUD,
renderer, or quality adoption. Those lanes should consume the current `v2`
manifest while retaining the `v1` corpus for legacy decoding gates.

Rollback removes only the additive `v2` corpus and platform-owned adoption
expectations. No player-data migration, save repair, schema downgrade, or
production code rollback is required.
