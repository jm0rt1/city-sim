# PLAY-054 Completion — Readable, World-First Command Surface

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-independent-quality-review
- **Published authority:** `af34c6b051439f5a30c95729b1614f1a1e60b0e6`
- **Exact staged product candidate:**
  `35c5eba893b0515560b9a37a5fd92d83d02d3b19`
- **Evidence checkpoint:**
  `132d4819930a5bae0d0fd66c1b7cefe3fab9f1df`
- **Evidence root:**
  `docs/production/evidence/PLAY-054/candidate-35c5eba/`

## Player-visible outcome

The command surface now reads as an authored city HUD rather than two
microscopic control strips. Treasury and cashflow, people, happiness,
employment, utilities, paused/running state, urgency, selected context, and
the current legitimate action have a calm but unmistakable hierarchy. The
regular layout uses its width for coherent metric groups; compact preserves
the city as the dominant visual surface.

At exact 900 x 600 content, the closed HUD exposes 361 points of interactive
map, or 60.2%. Opening Overview or Journal exposes 271 points, or 45.2%.
Overview visibly fits the complete Operating Position and Current Objective
sections. Journal visibly fits two complete notice summaries and their
actions. These replace the accepted baseline's AX-visible but visually
clipped content while satisfying the 58% closed and 45% open floors.

The same-state typography inventory raises critical metric, priority, warning,
and action roles to at least 11 points; decision support to at least 10 points;
compact metric values to 14 points; and regular values to 16 points.

## Ordered PLAY-054 commits

1. `f1f5822f16318b7089c9bb7208d80ec5a3bdbb11` —
   `PLAY-054: Freeze command-surface baseline audit`
2. `c79bd1635bc216f8210494065675a2d6f4b9da72` —
   `PLAY-054: Recompose the city command surface`
3. `7b952803793f064acb912e3c8e2c77d8e6813b0c` —
   `PLAY-054: Keep wide HUD metrics fully legible`
4. `030d0fc29c345c841d1e4286cfa6efd413faed31` —
   `PLAY-054: Fill the compact decision viewport`
5. `450baca8b7e384cb476e228ade7827938ed01530` —
   `PLAY-054: Keep compact state labels explicit`
6. `35c5eba893b0515560b9a37a5fd92d83d02d3b19` —
   `PLAY-054: Protect the primary HUD action label`
7. `132d4819930a5bae0d0fd66c1b7cefe3fab9f1df` —
   `PLAY-054: Retain command-surface proof`

The following completion-record commit contains this file; its hash is
reported in the lane handoff because a commit cannot embed its own identity.

## Product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Support/GameTheme.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/MetricCard.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

Only narrowly named HUD-specific theme tokens were added. No existing shared
theme semantic or public contract changed.

No SpriteKit, world asset, camera, gameplay, simulation, persistence,
package/build script, command inventory, active-target truth, objective truth,
or task-authority file changed.

## Interaction and accessibility

- Pointer opened the complete compact Overview and Journal compositions.
- Escape closed the topmost details surface and restored map focus without
  cancelling tool or target state.
- Command-/ focused the command guide; `tax` exposed the available
  `Open Tax Policy and Finances` result; Return used the existing catalog/store
  route exactly once.
- Pointer and Return on occupied block 12, 12 produced the same durable
  store-owned rejection, retained Residential and the active coordinate, and
  did not change treasury.
- Keyboard `3` selected authoritative 3x speed while focus remained on the
  semantic City map. Space restored the authoritative paused state and map
  focus.
- The exact compact AX trees expose city status, urgency, command actions,
  complete Overview and Journal content, command-search availability,
  selected target, accepted rejection reason, and map keyboard guidance.
- Full Keyboard Access-critical traversal, Return/Space activation,
  pointer/AX command equivalence, topmost Escape, and text/modal quarantine
  remain covered by the full suite and staged journey.
- The candidate-only Reduce Motion run retains the same visible hierarchy and
  accessibility semantics. Its isolated preference was restored after proof.

## Automated validation

- Focused PLAY-054 layout, typography, compact content, catalog, focus, and
  store tests passed after every coherent correction.
- Final native suite at exact product candidate:
  **202 tests, 0 failures, 91.377 seconds**.
- Existing compact arbitration, keyboard/FKA focus, topmost Escape,
  exactly-once pointer/AX dispatch, durable rejection, tax search,
  modal/text quarantine, save/session, Reduce Motion, and complete command
  inventory tests remain green.
- `git diff --check`: passed.
- All repository shell scripts: `bash -n` passed.
- Exact default and `CITYSIM_COMPACT_WINDOW=1` staged builds:
  passed with candidate/process/manifest containment.

## Exact staged proof

- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Executable SHA-256:
  `e341ef1266d9b6449e512553ff1e3d2b5f122e6ed0779deea2a366a6921d2471`
- Compact frame: 900 x 652, representing exact 900 x 600 content plus the
  52-point titlebar
- Default frame: 1,278 x 768

The retained packet includes original color and grayscale before/after frames,
the typography inventory, measured closed/open aperture, compact closed,
Overview, Journal, Tax Policy search, durable pointer/Return rejection,
Reduce Motion, regular Overview, and fresh negative-cashflow proof. Complete
live AX trees and staging manifests accompany the affected journeys.

Integration's visual review of the exact `35c5eba` compact closed, Overview,
Journal, and regular frames found the composition repair materially met the
intended visual outcome. Independent quality owns acceptance and any score.

## Known limitations

- Aperture values are manual measurements on retained original pixels,
  corroborated by layout contract tests.
- AX and FKA-critical behavior were inspected live; spoken VoiceOver audio was
  not recorded or claimed.
- Grayscale images are review derivatives; the original color PNGs remain the
  geometry/state authority.
- The HUD-specific text floors target the critical and decision-support roles
  claimed by PLAY-054. This is not a global Dynamic Type or shared-theme
  redesign.

No push, integration, rebase, force, pin, self-score, or self-acceptance was
performed.
