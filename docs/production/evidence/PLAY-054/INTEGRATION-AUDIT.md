# PLAY-054 Integration Audit

**Date:** July 25, 2026

**Published master:** `1d4d4f7eba1bb1cf3c8d64b1c221f33d3be91637`

**Staged app:** `dist/CitySim.app` / `com.jfmortensen.citysim`

**Method:** Direct Computer Use inspection of the real staged SwiftUI/SpriteKit
app at the restored compact window and the standard zoomed window, with a fresh
accessibility tree after every action.

## Session and restoration

The attached session began running at 1x with the City layer, Inspect mode, no
selected block, Objectives closed, and Details closed. The audit temporarily
paused, opened and closed Objectives, Catalog, Overview, Journal, and Details,
and toggled the standard zoomed window. It restored the compact window, closed
all opened surfaces, retained City/Inspect/no-selection, and restored 1x. No
build, demolition, save, overlay, setting, or durable state mutation occurred.

## Current strengths to preserve

- The map remains the dominant closed surface.
- Catalog commands expose kind, cost, and upkeep.
- AX names, values, selected state, map focus, and command-center section
  structure are substantially complete.
- Objectives, Details, notices, speed, and Escape routes remain reversible.

## P1 — Compact command-center content is visually collapsed

At the compact window, opening Overview or Journal produced a clear header but
the useful body appeared only as thin clipped rows at the bottom edge. The AX
tree simultaneously exposed the complete Overview fields or all seven journal
messages and their Related Data, Act, and Dismiss controls. A sighted player
therefore receives dramatically less usable content than the semantic tree.

The cause is directly correlated to
`Views/BuildToolbarView.swift:7-12` and `:36-54`: the compact details ScrollView
is hard-capped at 66 points and regular details at 96 points, despite the
Inspector and Journal containing multi-row actionable content.

**Required repair:** Responsive open-state composition must expose at least one
complete actionable inspector section and two complete notice summaries at
900 x 600, with an obvious, operable scroll region for the remainder. Closed
compact map aperture must remain at least 58%; open aperture must remain at
least 45%.

## P1 — Critical HUD information is typeset below practical reading size

In both compact and standard windows, status labels, objective progress,
priority state, priority explanation, and metric details were visibly
microscopic. The standard window amplified the problem: the HUD stretched
across the width while keeping tiny text rather than using the available space
for stronger hierarchy.

The source confirms this is structural:

- `Views/MetricCard.swift:32-57` uses 7-point metric titles and details.
- `Views/TopHUDView.swift:90-127` uses caption2 plus an 8-point objective count.
- `Views/StrategyCommandCenterView.swift:277-301` uses 7-point eyebrow/status
  and 9-point summary text.
- `Views/StrategyCommandCenterView.swift:331-367` uses 9-point direct actions.

**Required repair:** No critical metric, priority, warning, current-state, or
action text below 11 points at standard text size; no decision-supporting
secondary text below 10 points. Recompose instead of applying scale factors
that shrink content back below the floor.

## P2 — Wide and compact hierarchy adapts by compression, not composition

The standard zoomed window showed a long, thin top strip with large unused
horizontal spans around tiny metrics and priority text. The compact command
rail showed unused central space while its selected-context prompt remained
faint at the far edge. When Details opened, the command surface became taller
without turning into a strong, intentional diagnostic workspace.

`Views/TopHUDView.swift:15-26` assigns the same 126-point maximum to both
layouts; `Views/ContentView.swift:92-94` selects only two modes; and
`Views/ContentView.swift:197-258` overlays the same top/bottom architecture in
both. The accepted aperture improvement remains valuable, but the hierarchy
needs a third concern: readable, authored composition at each width.

**Required repair:** Use the available width to group identity, city health,
priority, and time into a deliberate hierarchy; give the selected action and
diagnostic surface enough visual presence to feel like game UI rather than a
debug strip. Preserve all existing semantic routes and world ownership.

## Independent acceptance direction

The implementing lane must retain same-state default and exact 900 x 600
before/after captures, a rendered typography inventory, measured open/closed
aperture, visible Journal/Overview proof, and pointer/keyboard/FKA/AX/Reduce
Motion results. A quality lane must independently prefer the result; green
tests or AX completeness cannot waive visually collapsed information.
