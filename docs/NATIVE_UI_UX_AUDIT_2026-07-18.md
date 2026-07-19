# CitySim Native UI/UX Audit

**Audit date:** July 18, 2026
**Audited product:** `Native/CitySimNative` (`dist/CitySim.app`)
**Method:** hands-on play at the live default desktop layout, accessibility-tree inspection, and source review. The simulation was paused only after the continuously changing UI made stable element targeting unreliable. No product code was changed.

## Executive summary

CitySim has an attractive visual shell and a recognizable city-builder vocabulary, but the current interface is clunky because almost every system is presented at once and almost every presentation competes with the map. The player can build, inspect, change overlays, control time, and follow objectives, but the UI does not establish a clear primary loop or mode hierarchy. It behaves like a collection of individually polished widgets layered over a simulation rather than one coherent workspace.

The three highest-impact problems are:

1. **The playfield is crowded by persistent chrome.** The top HUD, objectives, overlay picker and legend, three-event stack, build dock, feedback toast, and inspector can all be visible simultaneously. At the tested layout, the usable map was reduced on all four sides.
2. **The running simulation destabilizes accessibility interaction.** Values update every 0.42 seconds, churning the accessibility hierarchy enough that element references became invalid before they could be activated. Pausing made the same controls stable. The SpriteKit map is largely exposed as unnamed `unknown` elements containing only glyphs.
3. **The build loop lacks strong spatial and state feedback.** A tool selection is clear in the dock, but there is no persistent cursor-attached preview, footprint, validity explanation, cost delta, or obvious cancel state on the map. Inspection and construction share the same primary click, and selecting an occupied tile silently changes the interaction from building to inspecting.

This should be treated as an information-architecture and interaction redesign, not a spacing-only cleanup.

## Severity scale

- **P0 — Blocking:** prevents a major class of users from operating the game or risks irreversible mistakes.
- **P1 — High:** repeatedly obstructs the core build/diagnose/adjust loop.
- **P2 — Medium:** causes confusion, excess effort, or weak feedback but has a workaround.
- **P3 — Low:** polish, consistency, or discoverability issue.

## Findings

### P1-01 — Persistent panels leave too little room for the city

**Observed:** At the default tested layout, the top HUD occupies the full width; the mandate panel covers the upper-left; overlay controls, legend, and three events cover the upper-right; the build dock covers the bottom; and the inspector removes a large right column. The map is the primary product surface but receives the residual space.

**Source evidence:** `ContentView.swift:13-38` composes all of these surfaces in one permanent overlay stack; `ContentView.swift:50-53` adds the inspector on top of that composition. Both `showInspector` and `showObjectives` default to `true` in `CityGameStore.swift:13-14`.

**Impact:** The player spends more time looking around UI panels than reading the city. Buildings and roads are partially obscured, especially around the upper-right event stack and lower build dock.

**Recommendation:** Establish one primary context panel at a time. Start with the map unobstructed, make objectives collapsible into a compact status, show events in a single expandable inbox/toast, and open the inspector contextually rather than by default.

### P1-02 — Live simulation updates destabilize assistive interaction

**Observed:** While the simulation was running, multiple attempts to activate a top metric by its current accessibility element failed because the element ID had already become invalid. After pausing, the same hierarchy became stable and the Treasury metric opened correctly.

**Source evidence:** `ContentView.swift:7` publishes every 0.42 seconds and `ContentView.swift:63` sends every pulse through the observed store. The top HUD and most panels observe the entire `CityGameStore`, so changing simulation state causes broad view updates.

**Impact:** Voice Control, Switch Control, automated accessibility clients, and potentially keyboard focus can lose their target while the game runs. This is a functional accessibility defect, not merely test-tool friction.

**Recommendation:** Isolate frequently changing values into narrow observable models, preserve stable accessibility identities, avoid rebuilding unrelated controls on every pulse, and run a VoiceOver/keyboard focus retention test at every simulation speed.

### P1-03 — The map is not meaningfully accessible

**Observed:** The SpriteKit map was exposed as an `SKView` containing a series of `unknown` elements whose only accessible content was glyphs such as `⌂`, `$`, `⚙`, `●`, and `ϟ`. Coordinates, building type, occupancy, condition, selection state, land value, and available action were absent.

**Impact:** A user cannot navigate or understand the city without vision and a pointing device. The map is the core game, so accessible surrounding SwiftUI does not compensate for this gap.

**Recommendation:** Provide a structured accessibility representation of the grid with stable tile IDs and labels such as “Residential, row 8 column 12, 34 residents, good condition.” Add accessible actions for inspect, build, and demolish, plus a keyboard grid-navigation mode.

### P1-04 — Construction has no spatial preview or explicit validity state

**Observed:** Selecting a building changes the tool button and briefly shows a textual confirmation, but the map does not show a cursor-attached building ghost, footprint, road requirement, affordability, or reason a hovered tile is invalid. The player must click to discover whether the action succeeds.

**Source evidence:** `BuildToolbarView.swift:36-51` only changes button styling. `CityGameStore.swift:69-88` resolves success or rejection only after the primary action.

**Impact:** Building is the central repeated action, yet placement feels trial-and-error and detached from the object being placed.

**Recommendation:** Add a live footprint preview with valid/invalid color, projected cost and upkeep, road/utility warnings, and Escape/right-click cancellation. Keep the selected tool visible near the pointer and in a compact mode bar.

### P1-05 — Primary click changes meaning based on hidden tile state

**Observed:** With a build tool active, clicking open land builds, while clicking an occupied tile inspects it. The interface does not announce that occupied cells override the active construction mode.

**Source evidence:** `CityGameStore.swift:69-77` branches from bulldozing to inspection to construction based on state under the pointer.

**Impact:** The user cannot form a consistent mouse model. A construction click can unexpectedly open the inspector, and the visible selected tool remains active, creating mode ambiguity.

**Recommendation:** Separate inspect/select from build intent, or make the hover preview state unmistakable. At minimum, show “Occupied — click to inspect” at the cursor and preserve a clear route back to placement.

### P1-06 — Event notifications are repetitive, obstructive, and weakly prioritized

**Observed:** Three large event cards were simultaneously visible, including repeated “Severe Storm” and “State Growth Grant” messages. Each card occupies 280 points and two click targets, over the map. Old and new events have no timestamp or novelty marker.

**Source evidence:** `EventFeedView.swift:8` always takes the first three messages and `EventFeedView.swift:25-29` renders each as a fixed-width persistent card. The feed does not group, age, or deduplicate messages.

**Impact:** Frequent simulation events become visual spam and hide the portion of the map where players are likely to work. Repetition reduces the perceived importance of genuine warnings.

**Recommendation:** Show one transient toast, group repeats (“Severe Storm ×2”), add time/day and severity ordering, and keep history in the journal. Critical events can persist; informational grants should self-dismiss.

### P1-07 — The economy shown in the audited save has lost decision pressure

**Observed:** The city had roughly $294 million in treasury, approximately $20.9K positive balance per cycle, and basic build costs from $120 to $18K. Costs were visually and strategically negligible relative to funds. The “keep treasury above $0” objective was permanently complete.

**Impact:** The HUD dedicates its most prominent metric and an inspector panel to finances, but the numbers do not support meaningful tradeoffs. This makes the interface feel busier while the decisions feel thinner.

**Recommendation:** Rebalance or scale the economy, introduce budget periods and consequential operating commitments, and replace completed objectives with progressive goals. Format extreme values consistently so the HUD communicates scale without false precision.

### P2-01 — Objectives consume prime space after they are complete

**Observed:** Two of three mandate objectives were complete but remained fully expanded with progress bars. The third objective showed 57% happiness against a 65% target with an 87% progress bar, requiring mental translation.

**Source evidence:** Objectives are a fixed three-item computed array in `CityGameStore.swift:33-38`; `ObjectivesView.swift:15-29` renders all of them equally and `CityGameStore.swift:13-14` opens the panel by default.

**Impact:** The panel becomes static wallpaper rather than a source of next actions.

**Recommendation:** Collapse completed goals, rotate in new objectives, show direct delta (“8 points to goal”), and let the objective system occupy a single compact row until expanded.

### P2-02 — Overlay controls are glyph-only and lack a clear off/reset affordance

**Observed:** The overlay picker presents six icons with no visible labels. Several accessibility descriptions fall back to raw SF Symbol concepts such as “dollarsign.circle,” “face.smiling,” and “aqi.medium.” The first icon visually represents the normal city view but is not labeled on screen as “None” or “City.”

**Source evidence:** `OverlayPickerView.swift:7-18` renders only `Image(systemName:)`; meaning is delegated to hover help.

**Impact:** New users must trial every icon or hover individually. The currently selected overlay changes the entire terrain palette, so being unable to identify the off state is costly.

**Recommendation:** Use a labeled menu/segmented control, explicitly name the reset state “City,” and provide a keyboard-visible shortcut hint.

### P2-03 — Data overlays compete with building identity

**Observed:** Land Value recolored almost the entire map into bright yellow/orange/red cells. Building colors remained categorical, but the saturated terrain dominated the scene and made roads, highlights, and small map markers harder to read. The legend explained only “Strong / Watch / Weak,” not what causes or changes the value.

**Impact:** The diagnostic layer tells the user where a condition exists but not what action to take. It also weakens the visual hierarchy needed for placement.

**Recommendation:** Desaturate nonessential geometry, use an adjustable heatmap opacity, preserve road/selection contrast, and add actionable legend text or inspector linkage.

### P2-04 — Inspector navigation is broad but shallow and disconnected

**Observed:** Clicking a metric changes the inspector’s picker selection. The selected section is shown in a pop-up menu at the top, while contextual actions are scattered within each section. There is no persistent hierarchy, history, or clear distinction between city-wide data and selected-tile data.

**Impact:** The inspector works as a collection of reports, but it does not support a fluent diagnose → locate → act loop. Users must repeatedly return to the map or HUD to establish context.

**Recommendation:** Split city analytics from selection details, preserve selection while browsing related metrics, and add direct “show on map” / “build remedy” actions with back navigation.

### P2-05 — Inspector is open by default and difficult to resize intentionally

**Observed:** The inspector begins open at 270–380 points wide. The accessibility hierarchy exposes the split-view divider as disabled, even though a numeric value is present.

**Source evidence:** `CityGameStore.swift:13` defaults `showInspector` to `true`; `ContentView.swift:50-53` constrains its width.

**Impact:** The map loses a large column before the player asks for detail, and users relying on keyboard or assistive controls cannot clearly manipulate the divider.

**Recommendation:** Default the inspector closed for established users, open it on selection, restore the last explicit width, and verify divider keyboard/accessibility behavior.

### P2-06 — Top metrics contain conflicting or poorly framed values

**Observed:** “Happiness 57%” was paired with “100% approval.” “Employment 2.4K” was paired with “100% filled,” while the inspector showed 2,419 jobs filled and 4,270 job capacity—making “filled” sound like capacity utilization when it actually referred to coverage of target employment.

**Source evidence:** `TopHUDView.swift:36-45` combines these values without explaining their differing denominators.

**Impact:** Players cannot reliably infer which lever is failing. Prominent summaries appear contradictory.

**Recommendation:** Rename secondary values to their actual semantics (“Mayor approval,” “Resident employment coverage”), use warning copy for divergence, and expose denominators in tooltips and detail views.

### P2-07 — Time controls rely on ambiguous transport icons

**Observed:** Four small buttons use pause, play, forward, and go-to-start-shaped icons for Pause, Speed 1, Speed 2, and Speed 3. “Go To Start” is semantically wrong for the maximum speed control.

**Source evidence:** `TopHUDView.swift:50-62` uses each speed’s SF Symbol and tooltip.

**Impact:** The controls borrow media-player semantics but perform simulation-rate selection. The fastest icon implies navigation rather than speed.

**Recommendation:** Use labeled `Pause`, `1×`, `2×`, `3×` controls or a compact segmented control; expose the keyboard shortcuts visibly.

### P2-08 — Build palette is too flat for eleven tools

**Observed:** Eleven equally weighted tools appear in one horizontal strip. At narrower widths the strip scrolls without a visible scrollbar, so tools can disappear with no category or overflow indicator.

**Source evidence:** `BuildToolbarView.swift:13-19` uses a horizontal `ScrollView` with indicators disabled; every item is a fixed 68-point tile (`BuildToolbarView.swift:45`).

**Impact:** Frequent zones, infrastructure, and civic services have no grouping. Players scan the full strip repeatedly and may not realize more tools are offscreen.

**Recommendation:** Group tools into Roads, Zones, Utilities, Services, and Civic; keep recent/favorite tools visible; provide an explicit overflow affordance and number-key shortcuts.

### P2-09 — Bulldoze is visually adjacent to routine construction without enough safety framing

**Observed:** Bulldoze is a prominent button at the end of the build dock and right-click demolishes directly according to the instruction text. The game provides undo, but the destructive mode’s scope and persistence are not visible on the map.

**Impact:** Misclicks are likely, especially because build, inspect, and demolish all act on the same dense isometric grid.

**Recommendation:** Use a distinct mode banner/cursor, never hide its active state below overlays, show the refund/cost before action, and make right-click behavior configurable or confirm high-value/civic demolition.

### P2-10 — Instructions are tiny, persistent, and pointer-only

**Observed:** “Click open land to build · Right-click to demolish · Drag to pan · Scroll to zoom” remains in tiny low-contrast text along the bottom dock. It documents mouse actions only.

**Source evidence:** `BuildToolbarView.swift:61-62` renders the entire instruction string as `caption2` secondary text.

**Impact:** The text is hard to read, consumes width, and excludes keyboard/trackpad/accessibility alternatives.

**Recommendation:** Move input guidance to contextual onboarding and a shortcut/help overlay. Show only the next relevant hint during play.

### P2-11 — Selection visibility is weak in a visually busy isometric scene

**Observed:** Buildings use bright category colors, icons, smoke, road markings, particles, overlay colors, and event chrome simultaneously. The selected/hovered tile does not dominate those signals.

**Impact:** It is difficult to know which grid cell will receive an action, especially around tall buildings whose art overlaps neighboring diamonds.

**Recommendation:** Add a high-contrast ground outline, vertical selection beam or footprint, dim noninteractive layers during placement, and ensure selection is visible under every overlay.

### P2-12 — The window minimum is too large to support a genuinely compact layout

**Observed:** The root view enforces a minimum of 1100×720 before accounting for the inspector. The design therefore avoids solving responsive prioritization and can still be cramped at the minimum.

**Source evidence:** `ContentView.swift:49` hard-codes `.frame(minWidth: 1_100, minHeight: 720)`.

**Impact:** The app is awkward on smaller displays, split-screen, remote sessions, and increased display scaling.

**Recommendation:** Define explicit regular and compact compositions. In compact mode, collapse metrics, replace the build strip with categorized popovers, limit notifications to one, and use an overlay inspector rather than a persistent column.

### P3-01 — Save and Undo live in window chrome while related actions live elsewhere

**Observed:** Save and Undo are toolbar actions in the title bar; build and bulldoze are in the bottom dock; simulation speed is in the HUD; related commands also exist in menus.

**Impact:** Controls are distributed by implementation surface rather than player task. Undo is particularly far from construction feedback.

**Recommendation:** Put contextual undo near the result toast and keep persistent file operations in the File menu/title toolbar. Make command placement predictable.

### P3-02 — Close buttons are unlabeled and duplicated

**Observed:** The objectives panel and each event card use identical `xmark` controls. In the accessibility hierarchy, the objective button is simply “Close,” while event dismiss buttons also appear as “Close” with unrelated help text inherited from the card.

**Impact:** Assistive users cannot distinguish “close objectives” from “dismiss Severe Storm.” Pointer users also have several small adjacent close targets.

**Recommendation:** Supply context-specific accessibility labels and larger hit targets: “Hide objectives,” “Dismiss Severe Storm notification.”

### P3-03 — Terminology is inconsistent

**Observed:** The UI mixes “cycle,” “tick,” “day,” and “pulse.” Upkeep tooltips use `/tick`; finances use `/cycle`; the city clock uses days.

**Impact:** Players cannot tell when income, upkeep, events, and growth are applied.

**Recommendation:** Choose one player-facing time unit and document how simulation speed advances it. Keep internal pulse/tick terminology out of UI strings.

### P3-04 — Completion and status color meanings are overloaded

**Observed:** Cyan, green, purple, orange, yellow, and red encode building type, metric family, selection, demand, objective completion, event severity, and overlay values depending on context.

**Impact:** Color is decorative more often than semantic, and meanings collide across panels. Several critical distinctions are color-only.

**Recommendation:** Define a semantic color system, pair status with text/icon/shape, and test color-blind palettes and Increased Contrast.

## Recommended target interaction model

The interface should center one loop:

1. **Read the city:** mostly unobstructed map, compact top status, one important notification.
2. **Choose an intent:** Build, Inspect, or Data—not several implicit modes at once.
3. **Preview the action:** footprint, validity, cost, and expected effect before clicking.
4. **Act:** clear map animation and concise result near the action.
5. **Understand the consequence:** a contextual inspector or data layer explains what changed and offers the next remedy.

Suggested desktop composition:

- **Top:** city name, treasury/balance, population, happiness, and labeled time speed in one compact bar.
- **Left:** nothing by default; expandable objectives and event history.
- **Right:** contextual inspector only when a tile, metric, objective, or warning is selected.
- **Bottom:** compact mode selector plus the current mode’s tools, not all tools at all times.
- **Map:** hover/selection/placement feedback always has the highest visual priority.

## Delivery sequence

### Phase 1 — Remove obstruction and ambiguity

- Default objectives and inspector closed.
- Replace the three-card event stack with one toast plus journal badge.
- Label speed and overlay controls.
- Add explicit Build / Inspect / Data modes and Escape cancellation.
- Add placement footprint, validity, and cost preview.

### Phase 2 — Repair accessibility and responsive behavior

- Stabilize accessibility identities during simulation ticks.
- Add a navigable accessible grid representation.
- Add keyboard navigation and actions for tiles and build tools.
- Implement regular and compact layouts below 1100×720.
- Verify VoiceOver, Full Keyboard Access, Increased Contrast, and reduced motion.

### Phase 3 — Deepen information design

- Rework metrics so labels match denominators.
- Turn objectives into a progressive system.
- Group the build catalog and surface recent tools.
- Make overlays explanatory and action-oriented.
- Rebalance economy and notification frequency so the UI reflects meaningful decisions.

## Acceptance criteria for the redesign

- At least 75% of the main content area remains an unobstructed, actionable map in the default state.
- A new player can place a valid residential building, understand its cost/upkeep, and cancel placement without trial clicks.
- Build, inspect, and demolish modes are visually and behaviorally unambiguous.
- No more than one transient notification covers the map; repeated events group automatically.
- Keyboard focus and accessibility element identity remain stable for at least 30 seconds at maximum simulation speed.
- Every visible map tile/building can be identified and acted on through VoiceOver and keyboard navigation.
- The layout remains operable at 900×600 and with the inspector open at 1100×720.
- Every city metric names its denominator or opens a detail view that explains it.
- Overlay legends explain both meaning and at least one relevant player action.
- Visible proof is captured for default, compact, inspector-open, build-preview, overlay, keyboard-focus, and VoiceOver flows; passing unit tests alone is not sufficient.

## Audit limitations

This was a focused desktop audit of the currently running native app and its present saved city. It did not attempt destructive save replacement, new-city reset, long-session progression, or a complete gameplay balance study. The economy and event observations are therefore representative of the audited save, while the layout, interaction, and accessibility findings are structural and directly supported by the current implementation.
