# PLAY-054 Candidate Validation

Date: 2026-07-25

This packet retains candidate-bound evidence for independent quality review.
It is not a self-acceptance or integration decision.

## Exact candidate identity

- Branch: `codex/citysim-ui-input`
- Product candidate:
  `35c5eba893b0515560b9a37a5fd92d83d02d3b19`
- Accepted authority ancestor:
  `af34c6b051439f5a30c95729b1614f1a1e60b0e6`
- Candidate ID: `ui-input-wdbeadac6e0bd`
- Bundle identifier:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged executable SHA-256:
  `e341ef1266d9b6449e512553ff1e3d2b5f122e6ed0779deea2a366a6921d2471`
- Default staging manifest SHA-256:
  `71f37aa0fa58bef43a72ca2b61aa633622acbc1254bb7da78e3dc2f74b8ce4b4`
- Compact staging manifest SHA-256:
  `1be0fafd8b8f73131aa61c946d6315eac7d2a0c852d3d0e3c1c90c9edac3415c`
- Reduce Motion staging manifest SHA-256:
  `bb5b330ee3a10d353373e70e2a79d60399b33e48a69b48f0d3840b4709a8ae10`

The retained manifests bind the branch, commit, worktree, bundle, isolated
preference domain, data root, executable, and live PID used for each journey.
Compact runs used `CITYSIM_COMPACT_WINDOW=1`; the Reduce Motion run also used
the candidate-only `reduceGameMotion` preference and
`CITYSIM_REDUCE_MOTION_PROOF=1`. That preference was restored to false after
capture.

## Same-state composition proof

The baseline and final comparison use the exact committed
`story-industrial-complication-v1.json` bytes (SHA-256
`7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`)
as `quicksave.json`: Day 33 / tick 128, Industrial complication, `$34,037`,
`+$93 / cycle`, power reserve 9, water reserve 14, and the
`DECISION · 16 DAYS` priority. Loading retains the existing authoritative
paused state.

| Frame | Captured size | Result |
|---|---:|---|
| Compact closed | 900 × 652 | Exact 900 × 600 content plus 52-point titlebar; world-first deck |
| Compact Overview | 900 × 652 | Complete Operating Position and Current Objective sections visible |
| Compact Journal | 900 × 652 | Two complete notice summaries and their actions visible |
| Compact Reduce Motion | 900 × 652 | Same hierarchy with reduced game motion enabled |
| Default closed | 1,278 × 768 | Regular composition uses width for readable metric groups |
| Default Overview | 1,278 × 768 | Wide command center remains map-subordinate |
| Default negative cashflow | 1,278 × 768 | Fresh Day 1 state exposes `$32,000` and `-$90 / cycle` at a glance |

Every retained PNG has a ColorSync-generated `-grayscale.jpg` partner for
hierarchy and contrast review. The baseline packet at
`../baseline-af34c6b/` retains the same routes before the product changes.

## Measured map aperture

Measurements use original screenshot pixels and the opaque HUD/deck edges.
Compact content begins below the 52-point titlebar.

| Route | Baseline map | Final map | Baseline share | Final share | Required |
|---|---:|---:|---:|---:|---:|
| Compact closed | 348 / 600 | 361 / 600 | 58.0% | 60.2% | at least 58% |
| Compact Overview | 310 / 600 | 271 / 600 | 51.7% | 45.2% | at least 45% |
| Compact Journal | 310 / 600 | 271 / 600 | 51.7% | 45.2% | at least 45% |

The open surface intentionally uses more of its allowed budget than the
baseline: the former 66-point viewport exposed full AX content while visually
showing only clipped card rims. The final 132-point viewport meets the open
map floor and makes its content genuinely operable. The closed composition
increases the world aperture.

## Typography inventory

The baseline source inventory is retained in
`../baseline-af34c6b/TYPOGRAPHY-INVENTORY.md`. The resulting HUD-specific
inventory is:

| Role | Baseline | Candidate |
|---|---:|---:|
| Metric and command labels | 7–9 pt | 11 pt |
| Priority eyebrow and urgency | 7 pt | 11 pt |
| Priority title | semantic caption | 13 pt rounded bold |
| Priority and notice support | 7–9 pt / lowest caption tier | 10 pt |
| Compact metric values | 12 pt | 14 pt |
| Regular metric values | 13–14 pt | 16 pt |
| City identity | 14 pt compact | 14 pt compact / 15 pt regular |
| Deck section eyebrow | 9 pt | 11 pt |
| Journal severity / card title | 9 pt | 11 pt |

The narrow additions are HUD-specific:
`hudCriticalTextSize = 11`, `hudSupportTextSize = 10`, and
`hudMetricValueTextSize = 14`. They do not redefine an existing shared theme
semantic. Wide and compact layouts recompose grouping and line budgets rather
than globally scaling every label.

## Hands-on routes

### Pointer, keyboard, command search, and recovery

- Pointer opened compact Overview and Journal. Overview visibly presents the
  complete Operating Position section, its `Open journal` action, and the
  complete Current Objective section.
- Journal visibly presents the complete `Regional Freight Contract` and
  `Neighborhood Upgraded` summaries with Related Data and Dismiss actions.
- Escape closes the topmost Journal/details surface and restores focus to the
  map without cancelling the selected target or tool.
- Command-/ opens the searchable command guide and moves focus to its search
  field. Typing `tax` yields the available `Open Tax Policy and Finances`
  catalog result. Return executes the existing catalog/store route once and
  opens the Finances / Tax Policy surface.
- Pointer selected Residential through the existing command route and clicked
  the occupied City Hall visual at block 12, 12. The store-owned durable
  rejection remained visible beyond 4.2 seconds:
  `Demolish the existing structure before building here. Residential remains
  selected — choose another block.`
- Return on that same active target repeated the same accepted reason without
  changing treasury, selection, or tool. The AX map value and selected-context
  action both name block 12, 12 and the identical rejection.
- The exact negative-cashflow fresh launch displays Day 1, Running 1x,
  `$32,000`, and `-$90 / cycle` without opening another surface.

### Focus, FKA, and accessibility

- Complete AX snapshots accompany closed, Overview, Journal, search, rejected
  pointer/Return, Reduce Motion, and default routes.
- Compact city status exposes authoritative treasury/net, residents,
  happiness/approval, employment, utility reserve, pause/speed state, notice
  severity, priority, urgency, diagnosis, and action semantics.
- Overview exposes Operating Position, `Open journal`, Current Objective,
  progress, city identity, and health as complete actions/values.
- Journal exposes complete grouped notice text plus Related Data, Act, and
  Dismiss controls.
- The map remains a semantic `City map` container. Following Escape, it is the
  focused element with Arrow, Shift-Arrow, Return, and Shift-Return guidance.
- Command search exposes the Tax Policy result as an available button with its
  shortcut and help. Pointer, Return/Space, catalog, and AX dispatch continue
  to share the existing store intent path.
- The tested controls keep their existing focus IDs, accessibility labels,
  hints, values, and minimum hit targets. Full Keyboard Access-critical focus
  traversal remained operable in the staged app.

## Automated validation

- Focused PLAY-054 layout, typography, compact content, command catalog, and
  store/focus tests: passed after each coherent product checkpoint.
- Full native suite at exact `35c5eba893b0515560b9a37a5fd92d83d02d3b19`:
  **202 tests, 0 failures, 91.377 seconds**.
- The full run includes existing compact arbitration, keyboard/FKA focus,
  topmost Escape, exactly-once pointer/AX dispatch, durable rejection, tax
  search, modal/text quarantine, save/session, renderer Reduce Motion, and
  command-inventory coverage.
- `git diff --check`: pass.
- Every repository shell script: `bash -n` pass.

## Boundaries and known limitations

- This candidate does not edit SpriteKit, world assets, camera geometry,
  gameplay, simulation, save format/behavior, package/build scripts, command
  inventory, active-target truth, objective truth, or task authority.
- The world aperture measurements are manual edge measurements on retained
  original pixels, corroborated by focused layout contract tests; they are
  not inferred from a resized derivative.
- Accessibility evidence is the live macOS AX tree plus hands-on FKA-critical
  routes. It does not claim a recorded spoken VoiceOver narration session.
- Grayscale files are review derivatives. The original color PNGs remain the
  geometry and state authority.
- Quality acceptance, visual score, and integration remain independent-lane
  decisions.
