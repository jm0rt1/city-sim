# PLAY-115 composed-view evidence

- **Base:** `4fc2d1d10b41865d6f984360ba7d050f4bbd840a`.
- **Focused gate:**
  `HUDConsequenceFeedbackTests/testMapFirstComposedViewKeepsMapApertureAtCompactAndRegularSizes`
  — 1 executed, 0 failures.
- **Guidance composition:** Objectives take precedence over activity; activity
  appears only when objectives and command-center details are closed; open
  details suppress both, leaving the requested detail surface contextual.
- **Compact aperture:** the map-layer control reduces from 70 to 48 points.
  With the unchanged 104-point top HUD and 64-point closed command rail, the
  modeled 900 × 600 interactive aperture grows from 362 to 384 points (+22),
  with non-overlapping top and bottom chrome frames.
- **Rendered capture:** `compact-map-layers.png` is 900 × 48;
  `regular-map-layers.png` is 1240 × 74. The compact capture proves the
  collapsed Map layers control retains City and all diagnostic layer routes;
  regular retains the full palette.
- **Accessibility:** compact Map layers retains the existing layer names,
  active value, and command intent through its menu. Existing command/store,
  map selection, keyboard, Escape, and PLAY-114 recovery routes are unchanged.
