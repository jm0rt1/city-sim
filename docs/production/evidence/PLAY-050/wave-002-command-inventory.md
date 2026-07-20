# PLAY-050 Wave 002 Command and Keyboard Inventory

**Status:** Frozen before Wave 002 candidate execution

**Authority:** `CONTRACT-002` at `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`

**Purpose:** Define the independent inventory PLAY-050 will reconcile against the candidate's `CityCommandCatalog`. This document does not assign `CityCommandID` values, shortcuts, or store behavior; PLAY-030 owns those implementation choices. The evaluated manifest must record the candidate-supplied ID and descriptor for every row.

## Inventory rules

1. The candidate catalog must contain every required non-spatial action below exactly once: 32 logical actions before any candidate-authorized additions.
2. One descriptor supplies title, category, optional shortcut, discoverability copy, spatial classification, and contextual availability. A visible control, menu, guide/palette, and direct shortcut must dispatch the same catalog ID and store intent where those routes exist.
3. A candidate addition is acceptable only when it represents a real player action, is classified spatial/non-spatial, has one owner, and does not duplicate a row below. The run manifest records the reason for every count above 32.
4. System-owned Settings/window actions appear in the inventory with their actual system route even when they do not dispatch through `CityGameStore.perform(_:)`.
5. Spatial map actions and camera controls are recorded separately. They must not be disguised as `CityCommandID` simulation/replay commands.

## Required catalog reconciliation

At execution, replace each `candidate supplied` cell in the run-specific copy with the exact descriptor value observed in the integrated candidate. Do not edit this frozen source inventory to make a candidate pass.

| # | Expected logical action | Required class | Existing player route/shortcut to reconcile | Candidate catalog evidence |
| ---: | --- | --- | --- | --- |
| 1 | New region | Session | File/menu `New Region`; `⌘N`; terminal-status action | ID, descriptor, destructive/reset availability and reason |
| 2 | Save city | Session | Toolbar and File/menu `Save City`; `⌘S` | ID, descriptor, exact save intent and feedback |
| 3 | Load city | Session | File/menu `Load City`; `⌘O`; terminal-status action | ID, descriptor, disabled reason when no valid save |
| 4 | Undo construction | Session | Toolbar/HUD and Edit/menu; `⌘Z` | ID, descriptor, disabled reason and exact pre-command restoration |
| 5 | Pause | Simulation | HUD and Simulation menu; `Space` | ID, descriptor, selected state |
| 6 | 1× speed | Simulation | HUD and Simulation menu; `1` | ID, descriptor, selected state |
| 7 | 2× speed | Simulation | HUD and Simulation menu; `2` | ID, descriptor, selected state |
| 8 | 3× speed | Simulation | HUD and Simulation menu; `3` | ID, descriptor, selected state |
| 9 | Inspect mode | Tools | Command deck and Tools menu; `V` | ID, descriptor, mode state |
| 10 | Build mode | Tools | Command deck and Tools menu; no accepted shortcut yet | ID, descriptor, selected-tool preservation |
| 11 | Bulldoze mode | Tools | Command deck and Tools menu; `B` | ID, descriptor, activation/deactivation state |
| 12 | Cancel current tool / close top transient | Tools | Escape/on-exit route | ID, descriptor, ordered Escape behavior |
| 13 | Build Road | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep discovery |
| 14 | Build Residential | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/road requirement |
| 15 | Build Commercial | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/road requirement |
| 16 | Build Industrial | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/road requirement |
| 17 | Build Park | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep discovery |
| 18 | Build Power Plant | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/uniqueness rules if any |
| 19 | Build Water Tower | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep discovery |
| 20 | Build Fire Station | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/road requirement |
| 21 | Build Police Station | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/road requirement |
| 22 | Build School | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/road requirement |
| 23 | Build City Hall | Build | Palette/catalog and Tools menu | ID, descriptor, cost/upkeep/unique-building disabled reason |
| 24 | City layer / clear overlay | City data | Overlay picker and City Data menu | ID, descriptor, selected state |
| 25 | Land Value overlay | City data | Overlay picker and City Data menu | ID, descriptor, selected state |
| 26 | Traffic overlay | City data | Overlay picker and City Data menu | ID, descriptor, selected state |
| 27 | Utilities overlay | City data | Overlay picker and City Data menu | ID, descriptor, selected state |
| 28 | Happiness overlay | City data | Overlay picker and City Data menu | ID, descriptor, selected state |
| 29 | Pollution overlay | City data | Overlay picker and City Data menu | ID, descriptor, selected state |
| 30 | Toggle objectives | Workspace | HUD/toolbar and City Data menu; `⌘J` | ID, descriptor, open/closed state and focus |
| 31 | Toggle command center | Workspace | HUD/toolbar and City Data menu; `⌥⌘I` | ID, descriptor, open/closed state and focus |
| 32 | Open notices / journal | Workspace | HUD notices and related journal routes | ID, descriptor, journal section and focus |

Build-category selectors (`Roads`, `Zones`, `Utilities`, `Services`, `Civic`) are presentation navigation, not authoritative build intents. If the candidate catalogs them as executable commands, they must be declared as additions and must not replace any of the 11 build-tool actions.

## System-route inventory

The candidate command guide must disclose each app-owned setting and window-system action it exposes. At minimum reconcile the currently observable routes below; record whether each is a system command or a catalog command and never imply a store intent when none exists.

| Action | Expected system route | Required evidence |
| --- | --- | --- |
| Open Settings | Application menu / standard macOS Settings shortcut | Guide entry, keyboard route, correct settings window, focus return |
| Toggle Sound effects | Settings → Sound effects | Labeled switch, persisted lane-specific preference, no cross-candidate leak |
| Toggle Reduce ambient animation | Settings → Reduce ambient animation | Labeled switch, persisted lane-specific preference, critical information retained |
| Close window | File/Window system route and `⌘W` where supplied | Guide disclosure and safe app/session behavior |
| Minimize window | Window system route and `⌘M` | Guide disclosure and recoverable focus |
| Zoom or full screen | Window system route and system shortcut where supplied | Guide disclosure, default/compact return without lost controls |
| Quit CitySim | Application menu and `⌘Q` | Guide disclosure; save state is never implied unless it actually succeeded |

## Spatial and map-only routes outside CONTRACT-002 catalog

| Route | Current input | Wave 002 check |
| --- | --- | --- |
| Primary tile action | Pointer click | Uses the active inspect/build/bulldoze intent; preview and commit agree. |
| Secondary tile inspect | Secondary click | Opens truthful selection context without changing the active city unexpectedly. |
| Pan | Pointer drag | Does not dispatch a catalog action or change simulation state. |
| Zoom in/out | Scroll and `+`/`-` | Camera only; text entry/modal focus does not leak these keys. |
| Frame city | `0` | Camera only; no catalog collision or simulation mutation. |
| Keyboard grid navigation | Not authorized by CONTRACT-002 | Record as out of scope unless a later integration decision supplies authority. |

## Independent execution matrix

For every required catalog row, retain a machine-readable run table with:

- candidate `CityCommandID` and descriptor fields;
- catalog count and duplicate count;
- visible-control route, menu route, guide route, and shortcut route attempted;
- precondition, `canPerform(_:)`, disabled reason, and whether execution was prevented;
- store end-state fingerprint or UI-state observation appropriate to the action;
- pointer/keyboard equivalence disposition;
- default/900×600/Full Keyboard Access focus disposition;
- collision scope and any text-entry/modal leakage;
- proof path and `passed`, `failed`, `partial`, `blocked`, or `not-reproduced` result.

## Critical failures

Reject the candidate for a missing or duplicate required row, ambiguous shortcut owner, double invocation, route disagreement, executable disabled command, missing disabled reason, unmodified shortcut leakage into text/modal focus, Escape cancelling the tool before closing the top transient surface, inaccessible guide/action, focus trap, or required coaching.
