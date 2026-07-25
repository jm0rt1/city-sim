# PLAY-070 Completion — Make Regional Capital Victory Actionable and Truthful

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-independent-quality-review
- **Controlled claim authority:**
  `3991cf342e1e9c0e0359408d912a3f027571f93b`
- **Accepted product mutation base:**
  `c9d4baef3bd52fce9970c2e02d42ab646905be50`
- **Exact staged product candidate:**
  `63eb5086f79a294d497190d7ff880aefb9c079ac`
- **Evidence root:**
  `docs/production/evidence/PLAY-070/candidate-63eb508/`

The evidence/completion commit containing this record is reported in the lane
handoff because a commit cannot embed its own identity.

## Outcome

The accepted Regional Capital truth is now adopted by the existing command
surface:

- `Regional Retail Pressure` and `Regional Retail Challenge` expose Tax Policy
  diagnosis and Park recovery through existing commands.
- `Regional Freight Overload` and `Regional Grid Mandate` expose Power, Water,
  and Park recovery through existing commands.
- The strategy command center consumes all 12 current v2 story identities,
  including Regional mandate and Regional Capital completion.
- Current awarded second-act wins visibly and semantically say Regional
  Capital.
- Authentic missing-`secondAct` wins remain Town Charter results.
- `Start a New Region` remains the existing `.newRegion` command/store route.

The terminal decision is state-driven from existing
`CityAnalytics.regionalCapitalAwarded`; no view-derived gameplay rule was
added.

## Product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/GameStatusOverlay.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameStatusOverlayTests.swift`

No command, public store type, gameplay, simulation, save/schema, renderer,
asset, fixture, package, build script, shared contract, or task-authority
surface changed.

## Verification

- Owned failing filter: **2 tests, 0 failures**
- `GameStatusOverlayTests`: **7 tests, 0 failures**
- Complete native suite: **235 tests, 0 failures, 178.374 seconds**
- Exact staged `build_and_run.sh --verify`: passed at the product candidate.
- Executable SHA-256:
  `02fc1cccaa049332a123c7f012ee4d9f0babea8ae6f03041e93980158dfcc1de`
- Regular terminal captures: 1278 x 768.
- Compact terminal capture: 900 x 652 frame, exact 900 x 600 content.
- `git diff --check` and repository shell syntax: passed.

Real staged journeys covered Regional action pointer/keyboard routes,
regular/compact terminal results, authentic legacy/current identity, pointer,
Return, Space, File menu and command-guide replay, topmost Escape, deterministic
map-focus restoration, FKA/AX-critical semantics, modal suppression, and
compact Reduce Motion.

Spoken VoiceOver audio was not recorded; the live AX tree, focused semantic
actions, FKA-critical keyboard routes, and complete automated accessibility
suite are the claimed evidence.

All staged app processes were stopped. No push, integration, rebase, force,
pinning, self-score, or self-acceptance was performed.
