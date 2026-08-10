# PLAY-088 Claim — current-master Phase-B storm-recovery persistence proof

- **Title:** Prove Phase-B persistence and replay of the exact integrated storm recovery
- **Lane:** Simulation platform
- **Authority base:** `6d8c283d56eef2020a36546f30262757f3cf04e4`, which contains
  the accepted PLAY-085 storm-recovery product; the worker must start only at
  the Integration bootstrap commit containing this claim.
- **Branch:** `codex/citysim-simulation-g003-current6d`
- **Worktree:** `/Users/James/.codex/worktrees/0688/city-sim`
- **Owning thread:** `019febf6-2651-70c2-903a-1f8f20b668d9`
- **Player outcome:** The exact integrated damaged/recovering city is proven to
  survive save, backup, snapshot, replay, and Undo without changing unrelated
  buildings or historical bytes.
- **Allowed paths:**
  `Native/CitySimNative/Tests/CitySimNativeTests/StormRecoveryPlatformTests.swift`
  and `docs/production/evidence/PLAY-088/v2/` only.
- **Forbidden:** CityGameState, CitySimulation, SaveGameService, save/schema or
  fingerprint versions, fixture rewrites, UI, renderer, art/resources,
  packages/build, claims/routes, admission, runtime, app launch, integration,
  push, and self-acceptance.
- **Focused gate:** owner executes only a future route-bound Phase-B contained
  persistence/replay test; no command is authorized by this claim.
- **Full and independent gate:** Integration owns aggregate verification;
  CTO task `019fe8df-faf7-7b50-a8a3-0d15b1191e10` independently judges product
  relevance; QA owns any later staged journey.
- **Stop/refill:** Stop on save/schema/fingerprint uncertainty, an absent exact
  integrated PLAY-085 identity, test path expansion, or cross-lane semantic
  conflict. Refill only with a new reviewed current-master route.
- **Execution accounting:** Future route records exact identities, command,
  candidate-bound outputs, owner/acceptance identities, and result hash.
- **Status:** Bootstrap-only; no implementation route or worker execution is
  authorized by this claim.
