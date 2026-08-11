# PLAY-107 Claim — additive current story and visible-city corpus successor

- **Title:** Publish deterministic first-storm corpus successors without rewriting history
- **Lane:** Simulation platform
- **Owner:** Agent 201 — Simulation Lead
- **Owning task:** `019febf6-2651-70c2-903a-1f8f20b668d9`
- **Branch:** `codex/citysim-simulation-g003-current6d`
- **Worktree:** `/Users/James/.codex/worktrees/0688/city-sim`
- **Authority base:** `554e653c883a67aded1a1b1c17c12b0413da932c`
- **Product authority:** `703a8968e62654b7037c9b0437686930f46368f8`
- **Player outcome:** The accepted deterministic first ordinary-city storm has a current, byte-stable simulation corpus while every historical PLAY-078 and PLAY-083 fixture remains byte-identical and independently loadable.
- **Status:** Active after a validated schema-2 route and zero-mutation acknowledgement.

## Exact mutation boundary

Add only these successor artifacts:

- twelve `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/*-v5.json` story files;
- `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-states-manifest-v5.json`;
- fourteen `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/VisibleCityStates/*-v4.json` visible-city files; and
- `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/VisibleCityStates/visible-city-states-manifest-v4.json`.

Modify only:

- `Native/CitySimNative/Tests/CitySimNativeTests/ProductionStoryStateFixtureSupport.swift`;
- `Native/CitySimNative/Tests/CitySimNativeTests/ProductionStoryStateFixtureTests.swift`;
- `Native/CitySimNative/Tests/CitySimNativeTests/VisibleCityStateFixtureSupport.swift`; and
- `Native/CitySimNative/Tests/CitySimNativeTests/VisibleCityStateFixtureTests.swift`;
- `Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift`;
- `Native/CitySimNative/Tests/CitySimNativeTests/SpatialConsequenceTests.swift`; and
- `Native/CitySimNative/Tests/CitySimNativeTests/TerminalVictoryPlatformTests.swift`.

The four corpus Swift files may select Story v5 and Visible v4 as current and add byte-exact preservation gates for Story v4 and Visible v3. The three platform test files may change only deterministic current-output expectation literals and identities required by the successor corpora. Visible v4 binds product authority `703a8968e62654b7037c9b0437686930f46368f8`, the exact generated Story v5 manifest SHA-256, save schema `1`, and fingerprint version `1`.

## Immutable history and forbidden scope

- Every existing StoryStates v1-v4 byte and manifest is immutable.
- Every existing VisibleCityStates v1-v3 byte and manifest is immutable.
- `Native/CitySimNative/Tests/CitySimNativeTests/PLAY083LifecycleBindingTests.swift` is immutable and must pass unchanged against frozen Visible v3.
- Gameplay/product sources, UI, renderer, art/resources, package/build scripts, public contracts, other claims, protected dirt, app/QA state, push, integration, and self-acceptance are forbidden.
- No in-place regeneration, deletion, renaming, normalization, or reserialization of historical fixture bytes.

## Deterministic proof and commit boundary

1. Generate Story v5 twice into two fresh isolated temporary roots and require recursive byte identity.
2. Freeze the exact Story v5 manifest SHA-256.
3. Generate Visible v4 twice into two fresh isolated temporary roots and require recursive byte identity, with the exact Story v5 manifest binding.
4. Copy only the accepted successor bytes into the additive paths.
5. Run only `ProductionStoryStateFixtureTests`, `VisibleCityStateFixtureTests`, `SessionPlatformTests`, `SpatialConsequenceTests`, `TerminalVictoryPlatformTests`, and unchanged `PLAY083LifecycleBindingTests`, followed by `git diff --check`.
6. Stage explicit claim-owned paths, inspect the unrestricted full index, require exactly 28 additive fixture/manifest files plus seven modified support/test files and no protected dirt, then create one coherent commit with subject `PLAY-107: Publish deterministic story corpus successors`.

Stop on any nondeterministic replay, old-byte/hash/blob drift, product-authority mismatch, save/fingerprint schema change, path expansion, unexpected staged row, focused failure, or requirement to alter gameplay behavior. No retry, substitute, aggregate suite, stage-only build, app launch, push, or acceptance is authorized. Agent 002 independently reviews the exact candidate before Agent 003 integrates it. Only after accepted integration may Agent 003 run one fresh aggregate suite and, on PASS only, one stage-only build.
