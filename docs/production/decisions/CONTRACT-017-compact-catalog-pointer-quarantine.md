# CONTRACT-017: Compact catalog pointer quarantine

**Status:** Approved for PLAY-077 adoption

**Date:** July 25, 2026

**Owner:** Integration

## Player outcome

Choosing a build tool from the compact catalog changes only the tool. The
pointer event that dismisses the catalog must not fall through to the newly
exposed map, invent a target, move the camera, or trigger a map action.

## Problem

Exact staged compact proof on `1c36543` established a pointer/keyboard
differential:

- pointer Build → Catalog → Commercial selected Block 20,18 and moved the
  camera to empty grass; and
- keyboard `C` selected Commercial while preserving `No block selected` and
  the authored-district camera.

Both routes use the same typed command. The compact catalog popup has no
pointer-transition quarantine, so its stationary release/hover can reach
SpriteKit after SwiftUI removes the popup. Restoring the prior coordinate or
camera after the map accepts the event is rejected because it hides transient
target churn and cannot safely undo a map action.

## Approved contract

1. The single UI/input-owned `CityMapPointerTransitionGate` approved by
   CONTRACT-014 may add one origin: pointer activation of a compact
   build-catalog item.
2. The catalog item must begin the gate before it dispatches the existing
   typed build command and before popup dismissal exposes the map.
3. The gate captures the main content window and converts the transient menu
   event's screen location into that window's coordinates as its stationary
   anchor.
4. Only pointer-originated catalog activation begins this gate. Keyboard
   shortcuts, keyboard menu selection, command-guide execution, Full Keyboard
   Access, and accessibility activation remain immediate and must not begin a
   quarantine.
5. While active, the existing `CitySceneView` bridge rejects pointer target
   candidates and pointer primary/secondary actions. Keyboard and
   accessibility map commands, rendering, and camera behavior remain
   unchanged.
6. The gate clears only through the existing same-window movement threshold
   or safe lifecycle cancellation. Popup removal, layout recomposition,
   synthetic hover, or zero-delta movement must not clear it.
7. Reuse the one existing gate. Do not add a second command path, persisted or
   replayed state, renderer workaround, coordinate restoration, delayed map
   cleanup, or fixture-specific exception.
8. Catalog selection must dispatch its typed build command exactly once while
   coordinate, camera, state fingerprint, treasury, undo depth, and map action
   count remain unchanged.

## Implementation boundary

UI/input owns the repair. `BuildToolbarView` may bind the compact catalog to
its main content window and begin the existing gate for pointer activation.
`CityMapPointerTransitionGate` may generalize its origin metadata without
changing its map-blocking semantics. `CitySceneView` should continue consulting
the same gate at its existing candidate, primary, and secondary bridges.

Do not change `CityScene`, renderer camera policy, simulation validation,
public store commands, save state, or package topology.

## Acceptance

Acceptance requires:

- pointer catalog selection dispatches the requested tool once with no target,
  camera, treasury, fingerprint, or undo mutation;
- candidate, primary, and secondary map events stay blocked through popup
  dismissal and stationary or zero-delta events;
- real same-window movement beyond the existing threshold clears the gate;
- keyboard shortcut, keyboard menu, command guide, FKA, and AX activation
  preserve immediate parity;
- regular and exact 900 x 600 real-pointer proof for catalog open, select,
  cancel, movement release, and subsequent intentional map targeting; and
- the complete native suite and exact staged candidate proof.

CONTRACT-014 remains unchanged for Focus City. This contract adds only the
compact build-catalog pointer origin.
