# PLAY-085 Claim — current-master post-storm decision/recovery successor

- **Title:** Make one post-storm player decision legible, consequential, and recoverable
- **Lane:** Gameplay loop
- **Authority base:** `6d8c283d56eef2020a36546f30262757f3cf04e4`; the worker must
  start only at the Integration bootstrap commit containing this claim.
- **Branch:** `codex/citysim-gameplay-g003-current6d`
- **Worktree:** `/Users/James/.codex/worktrees/e895/city-sim`
- **Owning thread:** `019febf5-f590-7c91-977b-cdeb74614da2`
- **Player outcome:** Within the existing CONTRACT-022 recovery model, a player
  sees one clear choice, its numerical consequence, a visible diagnosis cue,
  and a recoverable next objective in the 20-minute decision loop.
- **Allowed paths:**
  `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`, and
  `docs/production/evidence/PLAY-085/v4/` only.
- **Forbidden:** public/save/UI/renderer/art/resource/package/build contracts,
  migrations, broad balance rewrites, claims, routes, admission, runtime,
  app launch, integration, push, and self-acceptance.
- **Focused gate:** owner executes only the future route-bound contained
  gameplay test; no command is authorized by this claim.
- **Full and independent gate:** Integration owns aggregate verification;
  CTO task `019fe8df-faf7-7b50-a8a3-0d15b1191e10` owns independent product
  judgment; QA remains distinct for real-app evidence.
- **Stop/refill:** Stop on any contract, save, migration, renderer/UI, balance,
  or cross-lane semantic question, path drift, or two failed repairs. Refill
  only through a fresh current-master claim and independently reviewed route.
- **Execution accounting:** Future route must record exact command, inputs,
  outputs, owner/acceptance identities, result hash, and zero shared mutation.
- **Status:** Bootstrap-only; no implementation route or worker execution is
  authorized by this claim.
