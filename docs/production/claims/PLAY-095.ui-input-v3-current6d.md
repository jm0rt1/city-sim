# PLAY-095 Claim — current-master visual-product feedback successor

- **Title:** Make the existing city state more legible at the next player decision
- **Lane:** UI and input
- **Authority base:** `6d8c283d56eef2020a36546f30262757f3cf04e4`; the worker must
  start only at the Integration bootstrap commit containing this claim.
- **Branch:** `codex/citysim-ui-g003-current6d`
- **Worktree:** `/Users/James/.codex/worktrees/6bad/city-sim`
- **Owning thread:** `019febf6-2651-70c2-903a-1f654b947b4d`
- **Historical evidence:** Preserve the detached observer and the clean
  `89382a2b` PLAY-095 candidate as evidence-only; neither is copied, merged,
  or reused as this successor's product baseline.
- **Player outcome:** Using only existing authoritative state, improve one
  decision/recovery cue in the HUD/objectives so the player can recognize the
  current pressure, consequence, and next recoverable action without changing
  UI, simulation, renderer, or save contracts.
- **Allowed paths:**
  `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Views/ObjectivesView.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`,
  and `docs/production/evidence/PLAY-095/v3/` only.
- **Forbidden:** CityGameStore or command public shape, simulation/state/save
  contracts, renderer/resources, historical PLAY-095 files, art/admission,
  runtime, package/build, claims/routes, app launch, integration, push, and
  self-acceptance.
- **Focused gate:** owner runs only a future route-bound contained UI/input
  command; no command is authorized by this claim.
- **Full and independent gate:** Integration owns aggregate verification;
  CTO task `019fe8df-faf7-7b50-a8a3-0d15b1191e10` independently judges product
  coherence; independent QA owns later real-app evidence.
- **Stop/refill:** Stop for any shared command/store/simulation/renderer/save
  contract need, an interaction ambiguity, a path expansion, or two failed
  repairs. Refill only through a fresh reviewed current-master route.
- **Execution accounting:** Future route records exact command, candidate
  identity, owner/acceptance identities, proof level, output hash, and result.
- **Status:** Bootstrap-only; no implementation route or worker execution is
  authorized by this claim.
