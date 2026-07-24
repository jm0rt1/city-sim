# PLAY-051 dependency: one active placement target

**Disposition:** shared-contract proposal for integration; no store, command,
simulation, or product renderer mutation has been made for this dependency.

## Reproduced architectural cause

The two surfaces do not invent different build rules. They already consume the
same authoritative `CitySimulation.validateBuild` function, but they can ask it
about different coordinates:

- SpriteKit hover presentation and pointer click use
  `CityScene.hoveredCoordinate` and the coordinate under the event;
- accessibility value/custom action, `canPerformMapCommand`, and Return use
  `CityGameStore.selectedCoordinate`;
- pointer motion does not update `selectedCoordinate`, while keyboard motion
  does not clear or replace `hoveredCoordinate`.

The observed contradictions therefore occur when a pointer hover remains on
one tile while AX/Return are describing and acting on another. A renderer-only
color or label change cannot make both actions agree without choosing new
player-intent semantics.

## Exact surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
  - `hoveredCoordinate` and `renderedSelection` state;
  - `mouseMoved`, `mouseUp`, `updateBuildPreview`, and
    `interactionPreviewStatus`;
  - renderer-owned grounded outline, ghost, and invalid hatch.
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
  - pointer callbacks into `CityGameStore.primaryAction(at:)`;
  - render inputs `selection` and `interactionMode`;
  - AX construction through `CityMapPrimaryActionPresentation`.
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
  - integration-owned `selectedCoordinate`, `canPerformMapCommand`,
    `performMapAction`, and `primaryAction(at:)` player intent.
- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
  - existing authoritative availability/name/disclosure presentation.
- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
  - authoritative `validateBuild`; no change proposed.

## Smallest contract proposal

Integration should approve one store-owned active map-action coordinate and
its input-modality transition rule. Two viable policies exist; the renderer
lane recommends the first:

1. **Single active target (recommended):** in build/bulldoze mode, crossing
   into a new tile publishes that pointer candidate to a narrow bridge callback;
   the store accepts it as the active/selected action coordinate. The store then
   supplies that same coordinate and `CityMapPrimaryActionPresentation` back to
   SpriteKit. Hover outline, AX, click, and Return all describe and execute that
   coordinate. Inspect-mode hover remains non-selecting.
2. **Explicit dual target:** keep pointer hover and keyboard selection separate,
   but add an approved input-mode owner and expose only the current mode's target
   to SpriteKit, AX, click, and Return. This is more state and is not recommended
   for the focused repair.

Under policy 1, the narrow implementation would add a renderer callback such
as `onActionTargetCandidate(GridCoordinate)`, wire it in `CitySceneView`, and
let a store-owned method accept or reject the transition. SpriteKit must stop
revalidating an independently selected coordinate for presentation; it should
consume the store-produced action presentation for the accepted target. Click
and Return must dispatch the same store command/target path. No new gameplay
rule or snapshot field is required unless integration rejects reuse of
`selectedCoordinate` as the active action target.

## Required acceptance matrix

At default and exact 900 by 600, for each state below, assert the same target
coordinate and `CityMapPrimaryActionPresentation` across the grounded preview,
AX availability/disclosure/custom action, pointer click, and Return:

| Case | Authoritative outcome |
|---|---|
| Occupied | unavailable, `.occupied`, no mutation |
| Empty without direct road | unavailable, `.roadAccessRequired`, no mutation |
| Empty with road but insufficient treasury | unavailable, `.insufficientFunds`, no mutation |
| Empty with road and funds | available; click and Return produce identical build/cost state |
| Same no-road tile after an adjacent road is added | transitions immediately from blocked to available; click and Return agree |

The focused test must also alternate pointer and keyboard target changes to
prove that a stale hover cannot disagree with the active AX/Return target. The
full native suite, staged pointer/keyboard flow, accessibility inspection, and
exact-compact proof must follow the approved join.
