# PLAY-051 next-wave HUD and command audit — 2026-07-21

## Disposition

**HUD/UI: REJECT for next-wave player readiness.** Core metrics, warnings, direct actions, inspector semantics, load feedback, and compact readability are materially useful. Readiness is blocked by a severe placement-truth contradiction, loss of map dominance when compact panels combine, and a command search that cannot find the policy required by an active warning.

Exact candidate and staged-app identity are frozen in `99ae3c7-next-wave-dual-audit/CANDIDATE_IDENTITY.md`. Product authority is `99ae3c7925825cfb8eccb47a678405c6e58d2a46`; the audited build HEAD is `e9e429ce26244bd6571c1d2920b1a4e30c3e79a9`.

## Player journey covered

The same fresh commercial journey was operated at default `1440x900` and exact `900x600` content size. Pointer and keyboard covered Welcome dismissal, metrics, Notices/Act, catalog selection, map movement/placement, undo, save/load, objectives, command-guide search, warning details, policy increments, selected-road inspection, panel dismissal, and continued recovery under live simulation updates.

See `99ae3c7-next-wave-dual-audit/SESSION_LEDGER.md` for timings and `99ae3c7-next-wave-dual-audit/visuals/` for the uncropped staged-app frames.

## Prioritized findings

### P1 — Placement feedback contradicts the governed command state

- **Owner:** Cross-lane world presentation / UI command-truth integration. This is a non-scored PLAY-022 dependency, not a renderer score.
- **Evidence:** On occupied block 14,9 and open blocks lacking road access, AX correctly reported Commercial unavailable with the precise reason while the in-world overlay displayed `VALID · COMMERCIAL`. Later, AX reported block 15,11 available while the overlay displayed `BLOCKED`; Return successfully built there.
- **Reproduction:** Load the retained Day 98 save in exact compact mode; select Commercial; focus occupied block 14,9, then an adjacent open block without road access; compare AX availability/reason to the visible overlay. Build a road at 16,11, select open block 15,11, and compare again before pressing Return.
- **Desired player outcome:** Pointer, keyboard, AX, and in-world feedback express one authoritative answer before commitment.
- **Acceptance test:** For occupied, no-road, unaffordable, valid, and newly connected tiles at both viewports, the visible overlay text/state exactly matches the command policy's availability and disabled reason; Return/click succeeds iff the displayed state is valid.

### P1 — Combined compact panels displace the playable map

- **Owner:** UI/input.
- **Evidence:** At exact 900x600 with Objectives and Command Center details open, the map was reduced to an approximately 130 px-high strip (about 22% of content height). Controls remained readable, but selection and spatial consequence ceased to be primary.
- **Reproduction:** Launch with `CITYSIM_COMPACT_WINDOW=1`; load Day 98; open Objectives, then open a metric's Command Center details. Observe the uncropped frame and attempt map selection without closing a panel.
- **Desired player outcome:** Compact mode preserves a usable, context-bearing map while showing the highest-priority decision surface.
- **Acceptance test:** At exact 900x600, opening Objectives plus Command Center preserves at least 40% of content height for the interactive map (or an integration-approved equivalent occupancy measure), keeps the selected tile visible, and exposes all critical actions without clipping or horizontal scrolling.

### P2 — Command search cannot find the active tax remedy

- **Owner:** UI/input command catalog.
- **Evidence:** Storefront Slump explicitly required tax <=9% or a second park. The command guide search field accepted `tax` but returned no result, although Tax Policy was reachable elsewhere.
- **Reproduction:** Open Command Guide with Cmd-/; enter `tax` while Storefront Slump is active.
- **Desired player outcome:** A player can translate warning language directly into the relevant command.
- **Acceptance test:** Searches for `tax`, `budget`, and `storefront` surface Tax Policy (or a direct warning action), including its current availability/disabled reason; Escape closes safely and no text leaks into map shortcuts.

## What already works

- The top HUD exposes treasury/net, residents/homes, happiness/approval, jobs/openings, utilities/spare, objective progress, and speed with live values.
- Critical notices distinguish severity, explain cause, give measurable remedies, and expose direct Act menus.
- The selected-road inspector connects identity, location, condition/upkeep, and Demolish action.
- Save/load feedback is explicit and load returns paused.
- No critical clipping or horizontal scroll appeared in default or compact catalog/inspector surfaces; live updates did not visibly destabilize layout.
- The AX tree provided meaningful labels, values, costs, availability, disabled reasons, coordinates, and focusable actions.

## Non-goals and contract implications

- No world-art or renderer-quality score was performed. The P1 concerns behavioral truth only.
- Spoken VoiceOver, global Full Keyboard Access, Reduce Motion, and physical `Shift-2` routing remain unverified; AX and ordinary keyboard evidence must not be promoted to those claims.
- The placement overlay should consume the same authoritative `allowsCommand` result and disabled reason as keyboard/AX. If that path crosses module ownership, its shared contract is integration-controlled.
- No simulation balance, save schema, or world asset changes belong in the UI slice.

## Recommended first coherent implementation slice

Restore compact map dominance with one deterministic surface-precedence rule: opening Command Center details at 900x600 collapses Objectives to its summary and caps the detail region so the selected map context remains usable. Add exact-size visual and AX regression coverage. Address the cross-lane placement-truth P1 before declaring the combined player route accepted.
