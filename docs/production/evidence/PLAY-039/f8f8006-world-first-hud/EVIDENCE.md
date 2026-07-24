# PLAY-039 World-First HUD Evidence

## Candidate identity

- Product commit: `f8f800656cf1cefb87aa5cdca231fa31bef6d860`
- Published authority: `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- Baseline comparison commit: `0f30ccbe40bec4b462569f48926f863660e3da27`
- Branch: `codex/citysim-ui-input`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Default staged PID: `23679`
- Exact-compact staged PID: `28363`
- Executable SHA-256:
  `b9c51ffcc8131b81c3a9c0d7560eb17937182b8abb997f37c425d7847d483679`
- Manifest SHA-256:
  `6783f2e45ae71aa4a5a71fc4cdfe59e11803536a2d0ce98901d641ccf8f8cd82`
- Frozen story state: `story-commercial-complication-v1.json`
- Story-state SHA-256:
  `c69b0695510f9b7ecde695e70fae281a165f70cc81f6962842019ba461994776`

The before and after frames use the same Day 33 commercial-complication
fixture. The comparison does not depend on the separately authorized starter
topology.

## Measured world aperture

| Surface | Before | After |
|---|---:|---:|
| Exact compact, panels closed | 246 / 600 pt interactive map, 41% | 350 / 600 pt, 58% |
| Exact compact, Objectives + Command Center | 246 / 600 pt before panel arbitration | 311 / 600 pt live, 52% |
| Exact compact, conservative details contract | 40% minimum | 47% tested minimum |
| Default captured-window world band | 64%, with the priority card obscuring another 11% | 65%, with priority integrated into chrome and no map overlap |

The compact before frame left only about 22% of content height vertically
unobstructed after the floating priority card. The after frame makes the
authoritative priority part of the bounded top ribbon and removes the duplicate
City Pulse wall from the bottom rail. The same city state, selected context,
warning, action, and command routes remain present.

## Retained frames

- `before-default-0f30ccb.png` — same-state default baseline, 1229 x 768.
- `after-default-f8f8006.png` — same-state default product, 1229 x 768.
- `before-compact-0f30ccb.png` — same-state exact compact baseline,
  900 x 652 including title bar and 900 x 600 content.
- `after-compact-f8f8006.png` — same-state exact compact product,
  900 x 652 including title bar and 900 x 600 content.
- `after-compact-panels-f8f8006.png` — exact compact with Objectives and
  Command Center simultaneously open.
- `after-default-rejection-f8f8006.png` — durable occupied-target rejection
  with the Residential tool and target retained.

Each primary frame has a retained full accessibility-tree text capture.

## Hands-on interaction proof

### Fresh launch and modal containment

The isolated candidate preference domain was cleared before the default launch.
The fresh AX tree contained only `welcome.blocking-modal` and
`welcome.start-building` from the game surface. Dismissing the CTA restored the
complete HUD and focused the semantic City map at authored 1x speed.

### Warning to diagnosis to legitimate action

1. Loaded the frozen commercial-complication fixture with Command-O.
2. Confirmed `Day 33`, `Paused`, `DECISION · 16 DAYS`, and
   `Protect local storefronts` in the top ribbon.
3. Activated the visible `Tax policy & cashflow` button by pointer.
4. Confirmed the existing Command Center opened to Finances with Treasury,
   next-cycle cashflow, Tax Policy slider, and decision support.
5. Escape closed details and restored focus to the City map.

### Command discovery and activation

- Command-Slash opened the command guide in default and exact compact.
- `storefront` and `budget` each returned the single available
  `Open Tax Policy and Finances` catalog command.
- Return from the search field dismissed the guide and opened the existing
  Finances surface exactly once.

### Rejection recovery

1. From map focus, `H` selected Residential through the catalog route.
2. Left Arrow selected occupied Road block 12, 13.
3. Return attempted the focused target once.
4. The accepted reason was:
   `Demolish the existing structure before building here.`
5. The HUD added:
   `Residential remains selected — choose another block.`
6. After 4.5 seconds, the reason, selected Residential tool, selected
   coordinate, and map focus were still exposed.

### Compact focus, Escape, FKA, and AX

- With Objectives and Command Center open, first Escape closed Command Center,
  retained Objectives, and focused the City map.
- Second Escape closed Objectives and kept City map focus.
- Tab moved from City map to `hud.city.identity`; Shift-Tab returned to City
  map.
- The live City map exposed
  `Inspect Road at block 12, 13` as an AX action. Invoking that exact action
  opened the same selected-target Command Center route.
- The exact-compact tree retained all speed controls, notices, priority
  diagnosis/action, command guide, details, catalog, overlay, selected context,
  toolbar actions, and semantic map help.

### Reduce Motion

Command-Comma opened the isolated candidate Settings window. The
`Reduce ambient animation` switch was keyboard/accessibility reachable and
changed from off to on. The focused layout test also proves
`GameTheme.animation(reduceMotion: true)` is nil, and the full renderer suite
retains its static reduced-motion semantics.

## Automated validation

- `git diff --check` — passed.
- `bash -n script/build_and_run.sh` — passed.
- Focused layout, strategy ribbon, command deck, catalog, focus, rejection,
  and AX tests — passed.
- `swift test --package-path Native/CitySimNative` — 194 tests passed,
  0 failures.
- `./script/build_and_run.sh --verify` — exact product commit verified and
  launched in default layout.
- `CITYSIM_COMPACT_WINDOW=1 ./script/build_and_run.sh --verify` — exact product
  commit verified and launched with 900 x 600 content.

Independent visual scoring remains owned by PLAY-053.
