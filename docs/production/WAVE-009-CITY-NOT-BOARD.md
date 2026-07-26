# Wave 009 — Make It Read as a City, Not a Board

## Why this wave exists

The published Wave 008 product candidate at
`87e1e682566b68d20deb1a9e2028e2b885e0423a` has a substantially stronger HUD,
a real post-Charter second act, and a richer public realm. It is still not the
visual or usability end state.

Independent inspection of the exact regular and compact staged app shows five
systemic weaknesses:

1. the developed district occupies too little of the visible world and still
   reads as a sparse board inside a broad green field;
2. detailed civic and utility landmarks sit beside flatter, lower-fidelity
   shops, industry, props, terrain, and road edges;
3. buildings, parks, and utilities do not consistently read as authored
   parcels connected by one continuous public realm;
4. repeated silhouettes, shadows, materials, and lot treatments remain
   obvious at neighborhood and block distance; and
5. the HUD is now stronger than the construction and recovery experience
   underneath it.

Wave 009 must solve those problems systemically. A hero screenshot, more
props, or a looser visual gate is not sufficient.

## Work order

### PLAY-071 — Make growth visibly transform the city

Gameplay must make a successful 20-minute city visibly evolve rather than only
changing counters. Both strategy routes must produce a denser, more varied
district with multiple building levels and a legible recovery scar, without
trivializing the warned pressure or creating one dominant build order.

This task owns gameplay rules and tuning only. It may use existing building
level, construction, condition, strategy, objective, and message contracts. It
may not invent renderer state, redesign commands, or weaken Regional Capital.

### PLAY-072 — Prove the visible-city state matrix

Simulation platform must freeze deterministic current-state fixtures for
vacant, construction, active, pressured, recovering, upgraded, and terminal
districts across both strategies. Existing save, fingerprint, replay, undo,
snapshot, activity, and performance truth must remain exact.

This task is a truth and reproducibility task. It does not invent a second
visual model or add persisted presentation state.

### PLAY-073 — Replace the board with an authored district

World rendering must rebuild the complete composition, not decorate isolated
tiles. The developed district must dominate the intended camera; roads,
sidewalks, curbs, parcels, parks, service yards, terrain, vegetation, props,
and buildings must read as one continuous authored place at city,
neighborhood, and block LOD.

The renderer must harmonize lighting, shadow softness/direction, outline
weight, saturation/value range, ground contact, and material response across
every shipped family. Repetition must be controlled without mirroring,
rotation, aliasing, fallback, invented simulation truth, or obscured
interaction. Accepted PLAY-027 art may enter only through a separate source
and shipping gate.

### PLAY-074 — Make building and recovery obvious on the map

UI/input must turn construction, diagnosis, and recovery into a direct,
map-first flow. Before commitment the player must see target, footprint, cost,
availability, likely consequence, and one cancellation route. After failure,
the visible priority and selected place must expose an honest next action
without requiring panel archaeology.

The improved HUD must remain compact and subordinate to the city. Every action
continues through the typed command catalog with pointer, keyboard, menu,
command guide, Escape, focus, FKA, AX, VoiceOver, and Reduce Motion parity.

### PLAY-075 — Independent city-not-board gate

Quality must preregister before receiving product candidates, then judge one
exact integrated build through fresh regular and exact 900 x 600 sessions.
Acceptance requires 20/20, not merely technical admissibility.

## Non-negotiable proof

- the same authoritative early, pressured, recovered, upgraded, and terminal
  states at regular and compact widths and city/neighborhood/block LOD;
- a measured developed-district occupancy and map composition improvement
  without cropping away useful buildable context;
- continuous road/curb/sidewalk/parcel/entrance geometry with zero floating,
  detached, clipped, or overlapping places;
- color and grayscale family comparisons proving coherent light, shadow,
  material, value, and outline language across civic, R/C/I, utility, service,
  terrain, road, vegetation, and prop art;
- deterministic repetition/variant ledgers and explicit adjacent-duplicate
  audits;
- pointer and keyboard construction, invalid placement, diagnosis, recovery,
  undo, save/relaunch/load, and exact selected-target continuity;
- compact, FKA, VoiceOver/AX, Reduce Motion, overlays, Focus City, Details,
  command guide, menus, and topmost-first Escape;
- exact source/staged resource identity, two-build parity, zero fallback,
  collision/registration validation, full native suite, renderer diagnostics,
  repeated LOD/RSS high-water, and frame budgets; and
- an independent no-coaching 20-minute journey in which the city visibly
  becomes denser, more coherent, and more legible while the player makes and
  recovers from a consequential decision.

## Acceptance bar

The exact combined candidate must score **20/20**, with every category 4/4,
zero P0/P1 defects, and zero automatic rejects. It must be materially preferred
to `87e1e68` at both widths and all three LODs.

Automatic rejection includes:

- a sparse-board composition, broad undifferentiated green void, or developed
  district that does not dominate the intended camera;
- mixed-fidelity, mixed-light, mixed-shadow, or mixed-material art;
- detached buildings, arbitrary park orientation, broken frontage, floating
  props, road/public-realm seams, overlaps, or clipped interaction targets;
- obvious adjacent repetition or aliasing disguised by color alone;
- a richer frame achieved by hiding buildable context, critical HUD truth, or
  active-target continuity;
- cosmetic density that contradicts authoritative state or changes gameplay;
- a construction/recovery action that requires hidden coordinates, source
  knowledge, or panel archaeology;
- visual quality that disappears at compact size, city LOD, grayscale, or
  Reduce Motion; or
- candidate substitution, coaching, fixture-only proof, author scoring,
  post-result rubric changes, or one attractive frame masking another failed
  state.
