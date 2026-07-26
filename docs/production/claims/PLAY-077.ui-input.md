# PLAY-077 Claim

- **Title:** Keep command chrome from targeting the map
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** Next published clean integration baseline containing
  CONTRACT-017, this claim, and accepted PLAY-074 product
- **Planned surfaces:** `BuildToolbarView.swift`,
  `CityMapPointerTransitionGate.swift`, existing gate consultation in
  `CitySceneView.swift`, private UI-intent recovery logic in
  `CityGameStore.swift` and `CityDirectActionPresentation.swift`, focused
  command/input tests, `docs/production/evidence/PLAY-077/`, and
  `docs/production/completed/PLAY-077.ui-input.md`
- **Dependencies:** Accepted PLAY-074; CONTRACT-014; approved CONTRACT-017;
  next published clean integration baseline
- **Validation/proof:** Pointer-versus-keyboard catalog parity; stationary,
  synthetic, movement, other-window, and lifecycle gate cases; deterministic
  adjacent-road recovery; pointer/Return/FKA/AX commit; Escape and exact Undo;
  regular and exact 900 x 600 staged proof; full native suite and verified
  staged bundle
- **Status:** Accepted and integrated on exact master product
  `897c191355d2fcb18ecc2e8d7358b44e9cae7cd4`. The lane candidate, retained
  evidence, full-suite result, staged bundle, and hands-on default/compact
  journeys are bound by
  `docs/production/evidence/PLAY-077/integration-897c191/VALIDATION.md`.

Do not sync or mutate before the exact baseline dispatch. Once dispatched,
extend the one existing pointer-transition gate only as authorized by
CONTRACT-017. Pointer catalog selection must change the tool exactly once and
must not create a target, move the camera, change treasury/fingerprint/undo,
or reach any map pointer bridge. Keyboard, menu-key, guide, FKA, and AX
activation remain immediate.

Repair `.roadAccessRequired` recovery separately through private existing
store/map intent: choose one deterministic empty cardinal neighbor that
passes current Road validation, preferring an extension of the real road
network and breaking ties row-major. Move the sole active target to that road
block and require the player to confirm. Never consume the blocked Commercial
parcel, auto-build, retain a second target, or change simulation rules. If no
truthful adjacent road target exists, preserve Commercial and explain that
another parcel is required instead of showing a false READY state.

Do not touch `CityScene`, renderer composition or camera policy, gameplay or
simulation validation, persistence, public commands, package/build scripts,
art, shipping resources, or legacy Python. Commit coherent contract-adoption,
product, test, evidence, and completion outcomes separately. Do not push,
integrate, self-score, self-accept, or pin.
