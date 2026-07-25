# CONTRACT-014: Pointer transition quarantine

**Status:** Approved for PLAY-057 repair

**Date:** July 25, 2026

**Proposer:** Integration after exact staged pointer tracing

## Problem

The staged Focus City control receives and consumes its exact window-local
pointer down/up sequence, but the disappearing/reappearing SwiftUI chrome
changes what lies beneath the stationary cursor. SpriteKit can then observe
hover or action input during the same presentation transition and replace the
authoritative map target. Button deferral, AppKit hit testing, and a local
down/drag/up monitor do not close that cross-surface boundary.

Restoring a prior coordinate after the map mutates is rejected. It cannot undo
a build or bulldoze action and would conceal transient target churn.

## Approved contract

1. UI/input may own one transient `CityMapPointerTransitionGate`. It is not
   gameplay state and must not be encoded, fingerprinted, replayed, simulated,
   or included in immutable presentation snapshots.
2. Only a pointer-originated Focus City enter/exit control may begin the gate.
   Shortcut, menu, command-guide, Full Keyboard Access, and accessibility
   activation continue through the existing immediate typed-command route.
3. The gate captures the originating window and pointer location before the
   Focus City command changes chrome.
4. While active, the `CitySceneView` input bridge must reject pointer hover
   target candidates and pointer primary/secondary map actions. Rendering,
   camera, keyboard map commands, and accessibility map commands remain
   unchanged.
5. The gate stays active while the pointer remains stationary over the
   originating control location. It may clear only after a real pointer move
   exceeds a small fixed distance from that location in the same window, or
   after safe lifecycle cancellation such as window departure/removal.
6. The gate must not clear merely because SwiftUI removed the originating
   control, installed the opposite Focus control, recomposed layout, or
   delivered a synthetic/zero-delta hover event.
7. Window-local monitoring must be lifecycle safe, consume no unrelated
   events, and preserve the SwiftUI Button as the sole semantic/FKA/focus-ring/
   accessibility control.
8. Inspect, build, and bulldoze modes must retain exact state, state
   fingerprint, treasury, undo depth, coordinate, selected target/action,
   camera position/scale, tool, panel state, and focus generation except for
   the single intended Focus City toggle.

## Implementation boundary

The gate belongs to UI/input composition. `ContentView` may own it and pass it
to `CitySceneView`; `CitySceneView` may consult it at the existing pointer
candidate and primary/secondary bridges. Do not add a second command system,
put AppKit geometry into `CityGameState`, change `CityScene` rendering, or
special-case a fixture, seed, coordinate, or window size.

## Acceptance

Acceptance requires:

- component tests for window identity, stationary/synthetic events, movement
  threshold, lifecycle cancellation, and unrelated-event pass-through;
- exact regular and 900 x 600 compact real-pointer enter and exit;
- inspect, build, and bulldoze state/fingerprint/undo/treasury invariance;
- unchanged pointer coordinate, target/action, and camera;
- keyboard, menu, command-guide, FKA, and accessibility parity;
- the complete native suite and exact staged candidate proof.

The retained PLAY-057 rejected attempts remain evidence and must not be
rewritten or presented as candidate-bound proof.
