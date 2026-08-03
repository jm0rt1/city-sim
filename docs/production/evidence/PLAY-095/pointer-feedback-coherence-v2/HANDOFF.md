# PLAY-095 pointer-feedback coherence diagnostic handoff

## Binding

- Route: `quality-v2:play-095-pointer-feedback-coherence-luna-v2`
- Route SHA-256: `34a757f4ad78c25b0a30d9f9c8af397820900fa9c12b59cd85d6f4c1484ecebb`
- Authority/base: `6434793cb8506bdc0c1a389b4d9f961e713ab274`
- Starting HEAD: `f55b034a1db57b65b3b525c1313a2222acff94a2`
- Branch/worktree: `codex/citysim-ui-input` / `/Users/James/.codex/worktrees/citysim/ui-input`
- Model route: `gpt-5.6-luna` / `max` (`LUNA_LOCAL_DEBUG`)

## Exact boundary replay

The focused regression drives `CityScene.activatePrimaryActionForTesting` through the same candidate callback and `CitySceneView.Coordinator.performPointerPrimaryAction` used by the pointer bridge. It performs a valid Road placement, renders the resulting authoritative state, then performs the occupied Road attempt at authored block 6,8. The result is coherent throughout: the target and unavailable action are occupied-block truth, feedback is the caution rejection, and Coordinator AX value has the same disclosure without the prior approval. No CitySceneView or CityScene product source was changed.

The frozen PLAY-075 stale-approval contradiction is therefore **not reproduced** at this deterministic CityScene/Coordinator boundary on the exact route baseline. This is a second diagnostic handoff, not a claim that the independent staged-app observation is disproven.

## Focused validation

- `testPointerBlockedPlacementPublishesOneCoherentLatestResult`: PASS (1/1).
- `CityCommandCatalogTests`: PASS (54/54).
- `git diff --check`: PASS.

The route forbids the full Swift suite, build/verify, and app launch. Integration owns those gates and the independent real-app occupied-road pointer/AX review. No store, simulation, renderer, command, save, shared-contract, package, or Integration-owned path was touched.

## Disposition

`DIAGNOSTIC_HANDOFF`: stop after this clean focused result. A product repair is not justified by the non-reproducing deterministic boundary; any remaining contradiction needs the Integration-owned staged-app journey or a new scoped authority.
