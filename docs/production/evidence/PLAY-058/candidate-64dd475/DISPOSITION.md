# PLAY-058 Independent Combined-Candidate Disposition

## Result

**PASS — 20/20**

Exact product candidate:
`64dd47500fe5e2d4a32a64f6298ded5789d3b773`

This is an independent quality disposition, not self-integration. No product
source was changed.

## Score

| Category | Score | Independent finding |
|---|---:|---|
| World and public realm | 4/4 | The authored fountain park, varied shrubs/groves, curbside detail, pedestrians, and service dressing materially replace the flat turquoise park and repeated isolated vegetation. City, neighborhood, and block frames remain useful and hash-distinct in regular and compact. No visible overlap, floating asset, seam, or false road/public-space state appeared. |
| HUD and Focus City | 4/4 | Closed HUD, Details, and Focus City preserve treasury direction, Day/paused state, decision urgency, notice severity/count, speed, exit, and the announced selected action. Focus materially increases aperture in regular and compact without clipping. Power Plant block 14,14 and its action remained exact across pointer and keyboard enter/exit. |
| Playability and control | 4/4 | Pointer selection, keyboard coordinate navigation, shortcut, command-guide, menu, FKA, AX semantics, and topmost Focus Escape worked. Occupied Park placement retained tool/target and exposed the exact reason; keyboard placement at open block 16,16 charged $900 once; Command-Z restored treasury and disabled Undo. No pointer leak, stale target, double action, or inaccessible critical action reproduced. |
| Overlays and legibility | 4/4 | Land Value, Traffic, Utilities, Happiness, and Pollution each produced localized, selection-safe marks in both layouts. Land Value/Happiness lot marks and Traffic road-shoulder ticks are deliberately sparse; compact Traffic is clearest at block LOD but is not legend-only. Utilities and Pollution remain immediately distinct. |
| Cohesion and polish | 4/4 | Public-realm forms, generated-v4 architecture, roads, lighting, HUD materials, selected outline, construction truth, Reduce Motion, and LOD transitions read as one shipping presentation. The candidate is materially preferred over frozen `4c0414b` in regular and compact views. |

Threshold result: `20/20`, both preregistered mandatory categories pass at
4/4, no category is below 3, and no P0/P1 or automatic reject was found.

## Hands-on routes

### Regular

1. Launched PID 42589 from the exact isolated executable and loaded the
   byte-identical Day 33/tick 128/seed 42 fixture.
2. Cleared transient load feedback, reset camera/layer, and retained the
   uncropped settled window.
3. Selected Water Tower 16,14 and Power Plant 14,14 by real pointer.
4. Entered/exited Focus City by pointer and `Shift-Command-F`; Details and
   Power Plant target/action were preserved.
5. Traversed all five overlays and city/neighborhood/block LODs.
6. Ran a 20-second 1x ambient observation; state advanced visibly without
   false traffic-agent claims.

### Compact

1. Launched PID 44096 with exact 900x600 content and the same fixture bytes.
2. Selected Water Tower by pointer and navigated to Power Plant 14,14 with two
   Left keys.
3. Entered Focus City from Details and from the closed deck; target,
   treasury, urgency, notices, speed, and exit remained visible.
4. Tab/Shift-Tab moved between semantic Focus controls and map; FKA Space
   activated the exact Exit button.
5. Command-guide search `focus` exposed and activated the route; City Data
   menu exposed and activated the same route; Escape exited Focus first.
6. Traversed all five overlays and the three LODs; retained a separate compact
   Traffic block frame because its sparse shoulder ticks are most readable at
   that scale.
7. Ran a 20-second 1x ambient observation from Day 33 to Day 44 and paused.

### Construction and recovery

1. A fresh exact regular route selected Power Plant 14,14 and Park.
2. Return was rejected with: `Demolish the existing structure before building
   here. Park remains selected — choose another block.`
3. Keyboard navigation moved to open block 16,16; Park availability announced
   `$900` plus `$18` upkeep.
4. Return committed exactly once, treasury changed `$34,037` to `$33,137`,
   construction displayed at 0%, and Undo became available.
5. Command-Z restored `$34,037` and disabled Undo.

### Accessibility and motion

- Full AX trees accompany every binding frame.
- Focus rail exposes one semantic entry/exit route, exact urgency, selected
  target/action, notices, treasury, identity, and speed.
- FKA traversal and activation passed.
- Reduce Motion retained Land Value truth and the complete compact HUD at the
  exact paused state.
- Spoken VoiceOver audio was not recorded; semantic AX hierarchy and live FKA
  activation are the asserted evidence.

## Automated and resource validation

- Independent full native suite: **219/219**, zero failures, 104.836 seconds.
- Rendering group inside the suite: **48/48**, zero failures, 22.172 seconds.
- Asset-pack validator: pass, four pages, staged/source parity, 132 payload
  and extrusion checks, 2,403 packed-overlap checks, zero failures.
- Active-plus-next decoded bytes: 12,582,912 City and 41,943,040
  Neighborhood/Block.
- Production geometry: 2,500 reciprocal-ground checks, 100 building/road
  checks, 372 entrance/prop checks, zero collisions/failures.
- Renderer diagnostic: 842 nodes, 376 drawables, zero actions, 3.805 ms world
  update, 5.504 ms total, zero decode loads.
- Cold profile: 3.806 ms world update, 5.643 ms total, zero decode loads.
- Repeated LOD residency: three textures, 41,943,040-byte high-water, zero
  fallbacks.
- Thirty-minute-equivalent soak: 4,286 pulses, 1,407 nodes, 594 drawables,
  two bounded actions, 0.0007 ms average diagnostic pulse.
- Live settled RSS: regular 191,136 KiB; compact 152,224 KiB; Reduce Motion
  declined from 272,576 to 237,968 KiB after the bounded settle. All remain
  below the frozen 333.8 MiB comparison ceiling with no observed continuing
  growth.

## Automatic-reject audit

- Overlap/collision/ground-contact/seam failure: not observed; validators pass.
- Decorative flat park or repeated vegetation rows: not observed.
- Ambient false simulation truth: not observed.
- Legend-only required overlay: not observed.
- HUD occlusion/clipping or missing critical truth: not observed.
- Stale/moved target across Focus: not observed.
- Pointer pass-through/leak or double action: not observed.
- Inaccessible critical action: not observed.
- Fallback, page-budget breach, or continuing RSS growth: not observed.
- Candidate/bundle/PID ambiguity: not observed; exact product-tree identity is
  documented in `identity/IDENTITY.md`.

## Evidence map

- `identity/`: immutable product/tree, staged hashes, bundle, process, roots.
- `live/regular/`: closed, ambient, invalid/valid construction, and undo.
- `live/compact/`: exact 900x600 closed, Details, ambient, Reduce Motion.
- `live/focus-city/`: selected-target regular and compact Focus transitions.
- `live/overlays/`: all five regular and compact layers plus compact Traffic
  block detail.
- `live/public-realm/`: regular and compact city/neighborhood/block frames.
- `validation/`: full suite, asset-pack, and production-geometry records.

## Limitations

- Spoken VoiceOver audio was not captured.
- The lane-isolated manifest names the evidence-branch merge commit because it
  preserves preregistration history; the exact `Native/CitySimNative` and
  build-script trees are byte-identical to immutable candidate `64dd475`.

No repair, waiver, push, integration, or thread pinning was performed.
