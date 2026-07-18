# UX and Accessibility Specification

## 1. Experience objective

CitySim must let the player move fluidly between three states of mind:

- **Appreciate:** watch the city, follow motion, listen, and take photographs.
- **Understand:** select a place, inspect a system, compare history, and trace a cause.
- **Act:** plan, build, budget, prioritize, or respond with predictable controls.

The interface should disappear when the player is appreciating the city and become precise when the player needs to diagnose or act. It must never trade truth for visual simplicity: summary first, detail on demand, causal evidence always available.

## 2. Information architecture

### 2.1 Persistent game surface

The main game window contains:

1. A world viewport occupying the majority of the window.
2. A compact top status area for city identity, time, treasury, population, employment, happiness or sentiment, and simulation controls.
3. A contextual build and management dock.
4. A selection inspector that appears only when relevant and can be pinned.
5. An objective surface and event feed that collapse without losing unread state.
6. Overlay controls close to the viewport, not hidden in a settings hierarchy.

Panels must avoid covering the location currently being edited. The UI can shift its preferred side or recenter the camera when a pinned panel changes usable viewport space.

### 2.2 Management workspaces

Budget, policies, transit lines, utilities, population, economy, services, environment, city history, and region connections use focused workspaces. A workspace preserves viewport context where useful and provides a clear return to the city.

Opening a workspace pauses only if the player's pause-on-management preference is enabled or the action requires a paused planning state. The current simulation state is always visible.

### 2.3 Native application surfaces

The application provides native macOS menus and shortcuts for new city, open, save, save as, revert, settings, accessibility, window, help, bug report, and quit. Destructive menu actions follow the same confirmation and save-safety rules as in-world controls.

## 3. HUD specification

The default HUD shows only citywide indicators that frequently change and lead to action. Every indicator supports:

- A plain-language label and accessible value.
- Current value, direction, and relevant period.
- A click target that opens the detailed source.
- Warning state based on consequence, not arbitrary color thresholds.
- A tooltip that explains calculation and freshness.

Color, icon, shape, text, and motion must not be the sole channel for any critical state. Compact notation such as `2.2K` expands to the exact value on hover, focus, or VoiceOver.

The player can choose compact, standard, or large HUD density. User customization cannot hide mandatory disaster, save-failure, or data-corruption warnings.

## 4. Camera and navigation

### 4.1 Camera capabilities

The city camera supports smooth pan, zoom, rotation, pitch within safe readability bounds, focus selected, return home, district focus, bookmark, and cinematic orbit. It preserves a stable world point under the pointer while zooming.

Camera motion is frame-rate independent, interruptible, and tunable. It may not induce compulsory acceleration, shake, depth-of-field blur, chromatic aberration, or motion blur.

### 4.2 Pointer and gesture input

Default input supports one-button mouse, multi-button mouse, trackpad, Magic Mouse, and keyboard:

- Primary click selects or commits the active tool.
- Secondary click cancels one tool step or opens contextual actions when no tool is active.
- Middle drag, configurable secondary drag, or space-drag pans.
- Scroll or pinch zooms around the pointer.
- Configurable modifier plus drag rotates and pitches.
- Hover reveals a preview without changing state.

Trackpad gestures must coexist with macOS system gestures. No essential action requires a precision chord.

### 4.3 Keyboard and controller

All frequent game actions have discoverable keyboard commands. Bindings are remappable, searchable, conflict-checked, importable, and resettable by category. A complete keyboard-only path exists for menus, panels, lists, alerts, and simulation controls; world construction can use keyboard-assisted pointer movement.

Full game-controller support is a release decision. If approved, it must cover all core play rather than only camera movement.

## 5. Tool interaction model

Every construction or editing tool uses the same state machine:

1. Inactive.
2. Selected with a short instruction.
3. Valid or invalid preview.
4. Adjustable geometry or parameters.
5. Cost and consequence confirmation.
6. Committed construction project.
7. Completion, partial failure, or cancelation feedback.

The preview distinguishes legal, blocked, unaffordable, destructive, and uncertain states through more than color. It shows the exact blocking rule at the nearest relevant point.

Tool changes preserve uncommitted work only when the destination tool can safely represent it. Otherwise the game asks to discard or return. Escape cancels progressively: current handle, current segment, current plan, then active tool.

Undo and redo cover reversible planning and cosmetic actions. Simulation outcomes are not silently rewound. Branch-from-autosave is offered for irreversible strategic recovery.

## 6. Selection and inspectors

World selection uses visible highlighting and predictable priority among stacked terrain, network, vehicle, citizen, building, district, and effect entities. Repeated click or a context list resolves ambiguity.

Every gameplay entity inspector answers:

- What is it and what state is it in?
- What does it provide, consume, or need?
- What changed recently?
- Why is it succeeding or failing?
- What is connected to it?
- What can the player do next?

Inspector values include units, timestamps or periods, trend, comparison, and source. Diagnostic links can turn on the relevant overlay, select a dependency, or open the responsible management workspace.

Pinned inspectors continue updating and survive camera movement. Comparison mode supports two compatible entities or two time ranges without forcing manual transcription.

## 7. Overlays and data views

Overlay families include land use, development demand, land value, traffic flow, travel time, transit, utilities, service access, delivered outcomes, pollution, noise, heat, hazard, ecology, employment, housing, wealth or affordability, and district policy.

An overlay must define:

- Question answered.
- Source data and freshness.
- Legend, units, and no-data state.
- Aggregation level and camera-dependent behavior.
- Colorblind-safe default palette.
- Click-through path to underlying entities.

Only one full-world analytical overlay is active by default, but supporting network and boundary layers may be composed. The game prevents combinations that would be visually misleading.

Charts support exact hover or keyboard values, labeled axes, comparison periods, event annotations, zoomable history, table alternatives, and export to CSV where the data is owned by the player.

## 8. Notifications, objectives, and guidance

Notifications use four urgency levels:

- **Ambient:** recorded in history with optional world feedback.
- **Informational:** visible in the feed and grouped by cause.
- **Actionable:** persists until read or resolved and links to the affected place.
- **Critical:** interrupts only for imminent broad harm, scenario failure, save failure, or data integrity risk.

Every actionable or critical notice states what happened, where, why the game believes it happened, consequence if ignored, and one useful next step. Repeated notices aggregate by system and district.

Objectives show target, current value, trend, persistence window, deadline, reward, and diagnostic link. Completion celebrations are proportional, dismissible, and do not steal input during construction.

## 9. Save, load, and continuity UX

The game provides manual saves, quick save, rotating autosaves, named branches, and scenario checkpoints. Save cards show city, region, game date, real timestamp, playtime, population, treasury, version, content dependencies, thumbnail, and integrity state.

Save operations run without freezing interaction beyond a short snapshot handoff. Progress is shown when the operation is perceptible. The player receives an unmistakable error if persistence fails; the HUD may not show a false success.

Loading an older schema creates or preserves an original backup before migration. Incompatible saves remain visible with an explanation and support-export action. Cloud synchronization, if approved, must expose conflicts rather than silently choosing a winner.

## 10. Onboarding and help

The guided opening teaches one decision at a time in the live game. Prompts attach to the relevant control or place, explain the goal, and recognize alternate valid solutions. The player can ask for a hint before the game volunteers one.

Context help, tooltips, encyclopedia, formula explanations, keyboard reference, accessibility help, patch notes, and support export are available from the Help menu. The game remembers dismissed concepts but lets the player reset all guidance.

## 11. Accessibility floor

Accessibility is a release gate, not a post-launch category.

### 11.1 Vision

- Full VoiceOver coverage for application chrome, menus, HUD, panels, lists, charts, tool state, and critical notifications.
- Scalable text and UI density without clipping at the supported maximum.
- High-contrast mode, reduced-transparency mode, and color-vision presets.
- Patterns, labels, or shapes for critical overlays and build validity.
- Optional cursor locator, selection outline strength, and interface magnification.
- Text alternatives and table views for charted information.

The 3D world itself is not promised as fully playable without vision in Release 1, but no application state may trap a VoiceOver user and all non-spatial management information must be accessible.

### 11.2 Motor

- Remappable commands and support for macOS accessibility input services.
- No required rapid clicks, holds, double-clicks, or simultaneous multi-button chords.
- Adjustable pan, zoom, scroll, drag, edge-scroll, and hold timing.
- Sticky modifiers and click-to-anchor alternatives for drag construction.
- Generous target sizes with no destructive adjacent targets lacking confirmation.

### 11.3 Hearing

- Subtitles and visual equivalents for all meaningful speech and sonic alerts.
- Separate volume controls for master, music, ambience, effects, UI, and voice.
- Optional directional alert indicators and event history.
- No gameplay rule communicated only through pitch, rhythm, or stereo position.

### 11.4 Cognitive and motion

- Plain-language mode for key explanations and consistent icon labels.
- Pause at any time outside noninteractive loading or platform dialogs.
- Adjustable tutorial frequency, notification rate, and simulation auto-pause rules.
- Reduced motion, disabled camera shake, disabled flashes, and configurable transition duration.
- Photosensitivity-safe effects and a warning review for unavoidable intense sequences.

## 12. Display and window behavior

The game supports resizable windowed, borderless full-screen, and native full-screen modes across supported aspect ratios. The minimum window size retains a playable viewport and accessible navigation. UI layout responds to scale and available space rather than shrinking text below its floor.

Moving between displays, changing scale, waking from sleep, disconnecting a display, switching Spaces, and entering or leaving full screen must preserve input, camera, and save state. HDR is optional and must not degrade SDR correctness.

## 13. UX acceptance

The UX is release-ready when representative new and experienced players can complete defined construction, diagnosis, recovery, save, and settings journeys without coaching; every journey has keyboard and accessibility coverage appropriate to its spatial requirements; input remains predictable across supported devices and frame rates; and all critical states have consistent world, visual, text, and audio feedback.

