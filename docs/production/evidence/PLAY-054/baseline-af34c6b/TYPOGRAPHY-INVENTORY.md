# PLAY-054 Baseline Typography Inventory

Inventory authority:
`af34c6b051439f5a30c95729b1614f1a1e60b0e6`.

This source-bound inventory records the typography actually selected by the
integrated HUD composition. SwiftUI semantic styles resolve through the
system, so the table distinguishes explicit point sizes from semantic styles.

## Critical command-surface typography

| Surface | Current declaration | Baseline result |
|---|---|---|
| Compact city title | 14 pt rounded bold | Above floor |
| City day / running state | `caption2` | Too visually subordinate |
| Objective label | `caption2` | Too visually subordinate |
| Objective count | 8 pt monospaced semibold | Below 11 pt critical floor |
| Dense metric icon | 9 pt | Below 11 pt critical floor |
| Dense metric title | 7 pt rounded bold | Below 11 pt critical floor |
| Dense metric value | 12 pt rounded semibold | Above floor |
| Dense metric detail | 7 pt rounded medium | Below 10 pt support floor |
| Regular metric title | 8 pt rounded bold | Below 11 pt critical floor |
| Regular metric detail | 9 pt rounded medium | Below 10 pt support floor |
| Priority eyebrow | 7 pt rounded heavy | Below 11 pt critical floor |
| Priority urgency | 7 pt rounded heavy | Below 11 pt critical floor |
| Priority title | `caption` bold | Semantically adequate, visually weak in stretched row |
| Priority summary | 9 pt | Below 10 pt support floor |
| Priority/action controls | 9 pt | Below 11 pt action floor |
| Deck section eyebrow | 9 pt rounded heavy | Below 11 pt critical floor |
| Inspector notice severity | 9 pt rounded heavy | Below 11 pt warning floor |
| Inspector support text | `caption2` | At the lowest semantic tier throughout decision cards |

## Source locations

- `Views/TopHUDView.swift`: explicit 8 pt objective count; extensive
  `caption2` status/label use.
- `Views/MetricCard.swift`: compact 7/7/9/12 pt and regular 8/9/13/14 pt
  hierarchy.
- `Views/StrategyCommandCenterView.swift`: 7 pt eyebrow/urgency, 9 pt summary,
  and 9 pt action treatment.
- `Views/BuildToolbarView.swift`: 9 pt deck eyebrow plus `caption2` supporting
  text.
- `Views/InspectorView.swift`: widespread `caption2` decision-support text and
  a 9 pt notice severity label.

## Required correction

PLAY-054 must not simply scale every declaration. The compact and wide
compositions need different grouping and line budgets so that:

- critical metrics, priority, warning, current state, and action labels render
  at 11 pt or larger;
- decision-support text renders at 10 pt or larger;
- the regular surface uses its width for meaningful grouping rather than a
  long microscopic ribbon;
- exact compact Overview and Journal allocate enough visual height for
  complete actionable content while the closed/open map floors remain 58% and
  45%.
