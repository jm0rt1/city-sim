# CONTRACT-002: One command catalog for every non-spatial action

**Status:** Approved

**Date:** July 19, 2026

**Owner:** Integration for PLAY-030

## Player outcome

Every non-spatial action is available through one consistent, discoverable route: visible control, menu command, keyboard shortcut where appropriate, accessible label, contextual availability, and a searchable in-game command guide. A pointer and a shortcut must invoke the same store intent.

## Approved contract

1. Add a UI-owned `CityCommandID` stable identifier and immutable `CityCommandDescriptor` metadata containing title, category, optional shortcut, discoverability copy, and whether the action is spatial.
2. Add one `CityCommandCatalog` as the authoritative inventory for non-spatial actions. SwiftUI menus, shortcut help/palette, accessibility shortcut descriptions, and coverage tests consume this catalog rather than maintaining independent inventories.
3. Add the smallest `CityGameStore.perform(_ command: CityCommandID)` intent router and `canPerform(_:)` availability query. These must call existing store intents or update existing UI/input state; they may not duplicate simulation rules or authoritative city state.
4. The catalog must cover new, save, load, undo, pause and all speeds, inspect/build/bulldoze/cancel, every build palette item, every data overlay, objectives, command center and notices/journal. Settings/window-system actions may remain system commands but must appear in the inventory with their system route.
5. Existing unmodified map controls (`Space`, `1`-`3`, `B`, `V`, `Escape`, camera `+`/`-`/`0`) may continue to enter through SpriteKit, but their callbacks must dispatch the same catalog/store intent where they overlap. There must be one declared owner for each shortcut and no double invocation.
6. The command guide may search and group descriptors, show shortcuts and disabled reasons, and execute available non-spatial commands. It is presentation only; it does not retain a second selected tool, overlay, speed, or availability model.
7. Spatial coordinate selection, keyboard grid navigation, remappable key bindings, macros, replay commands, and simulation-domain command logging are not authorized by this contract.

## Required behavior and tests

- A coverage test proves every declared non-spatial player action is present exactly once.
- A collision test proves no two active commands claim the same shortcut in the same focus scope.
- Menu, visible-control, catalog/palette, and direct-shortcut routes reach the same store intent and end state.
- Disabled commands expose a concise reason and cannot execute.
- Text entry and modal focus do not leak unmodified game shortcuts; Escape closes the topmost transient surface before cancelling the active tool.
- Full Keyboard Access reaches the guide and every critical command without a focus trap.
- Default and 900 x 600 layouts retain operable command access.

## Lane effects and adoption order

- **PLAY-030** owns implementation in `App/`, `Views/`, and UI/input portions of `CityGameStore` plus focused tests and proof.
- **PLAY-040** must not reuse `CityCommandID` as a simulation/replay command. Any deterministic domain-command type is separate and requires only state-changing simulation payloads.
- **PLAY-050** consumes the catalog as the authoritative keyboard inventory and independently verifies pointer/keyboard equivalence.
- **PLAY-020** keeps camera and spatial hit-testing behavior; overlapping shortcut callbacks adopt the UI catalog/store route without moving renderer ownership.

## Rollback

The catalog and router are additive. Reverting PLAY-030 restores the existing direct SwiftUI/SpriteKit routes without changing save data or simulation state.
