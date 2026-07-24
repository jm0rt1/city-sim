# PLAY-034 Claim

- **Title:** Unify the active map-action target
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** Integration authority commit containing CONTRACT-008 and this claim
- **Claimed:** July 21, 2026
- **Planned surfaces:** store-owned map action target, `CitySceneView` bridge, narrowly authorized `CityScene` adapter, direct-action presentation, focused UI/renderer tests, accessibility, and staged evidence
- **Dependencies:** approved CONTRACT-008 and an accepted/integrated PLAY-022 renderer base
- **Validation/proof:** five-case target matrix, alternating pointer/keyboard changes, click/Return equivalence, AX/custom actions, modal/text quarantine, default and exact 900 x 600 staged journeys, focused/full suites
- **Status:** accepted and integrated — product/evidence/completion `704784b`, `88cebf4`, and `7de4412` are ancestors of integration merge `37894a6`; independent combined approval is retained in `52ea60b`

Implement one store-owned active action coordinate only after integration supplies the accepted renderer baseline. Keep inspect hover non-selecting and preserve the existing command, focus, modal, save, simulation, and snapshot authorities.

Do not begin on the current unaccepted renderer branch, duplicate validation, introduce a second target, or mix this task into PLAY-033 commits.
