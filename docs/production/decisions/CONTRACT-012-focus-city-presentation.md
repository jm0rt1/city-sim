# CONTRACT-012: Focus City presentation mode

**Status:** Approved for ordered implementation

**Date:** July 25, 2026

**Proposer:** Integration after the published `4c0414b` real-app audit

## Player outcome

The player can give the city the screen without losing essential operating
truth, then return to the full command surface with the same target, focus,
mode, and panel state.

## Approved contract

1. `CityGameStore` may own one transient, non-persisted
   `isCityFocusModeEnabled` presentation intent.
2. One additive command toggles that intent through the existing command
   catalog and `CityGameStore.perform(_:)` route.
3. The action must appear in the visible command surface, command guide, and
   macOS menu with one conflict-free declared shortcut.
4. Focus City may collapse decorative labels, secondary metrics, objectives,
   priority explanation, and the expanded command deck.
5. It must retain city identity, paused/running state, simulation speed,
   treasury direction, highest active urgency, selected-target/action truth,
   and a visible route back to the full command surface.
6. Entry and exit must preserve the active map coordinate, mode/tool,
   availability presentation, camera, open panel choice, and deterministic
   focus restoration.
7. A blocking modal or text editor continues to quarantine the shortcut.
   Welcome, victory, save/load, command-guide, and existing topmost Escape
   ownership remain unchanged.
8. Full Keyboard Access and accessibility expose the mode, state, shortcut,
   retained critical information, and exit action.

## Compatibility

- The state is never encoded, fingerprinted, replayed, simulated, or included
  in immutable gameplay/spatial snapshots.
- No save, schema, gameplay, renderer, package, or simulation contract changes.
- Existing `CityCommandPolicy`, command availability, and active-map-target
  contracts remain authoritative.

## Rejected expansion

This contract does not authorize a second command system, renderer-owned HUD,
automatic hiding based on pointer motion, persistent per-save layout, hidden
critical warnings, a new camera model, or changing build/inspect/bulldoze
semantics.
