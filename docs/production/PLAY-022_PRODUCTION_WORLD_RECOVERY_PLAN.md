# PLAY-022 Production World Recovery Plan

**Status:** Binding integration dispatch

**Date:** July 21, 2026

**Owning lane:** World rendering

**Branch:** `codex/citysim-world-rendering`

**Defect source:** `WORLD_RENDERING_ISSUE_REPORT_2026-07-21.md`

**Rejected candidate retained at:** `8cb45b5848f070c25803213ee48b2523e8057d09`

## Decision

The renderer lane will stop treating art generation, isolated screenshots, and
renderer test counts as the unit of progress. It will deliver one overlap-safe,
visually unified, playable street corridor in the exact staged app, then extend
that production system across consequences, life, and the full catalog.

The current generated-v4 candidate is preserved as evidence and source
material, not accepted product. Its strongest civic, park, water, and
industrial art remains a provisional style reference. Its 216 x 144 per-tile
envelopes, repeated grass plates, mixed fallback art, visual stacking, camera
composition, and memory behavior are rejected.

This plan supersedes `PLAY-022_GATE_A_SYSTEMIC_REPAIR.md` and
`PLAY-022_WORLD_PLAYABILITY_DIRECTIVE.md` wherever their next-slice wording
conflicts. Their quality scorecard, factual-state boundaries, and retained
evidence requirements remain binding.

## Production-quality definition

The world is production quality only when all of the following are true in the
same staged candidate:

1. **Physical coherence:** no unintended opaque overlap; buildings sit on
   declared parcels, face supported streets, and preserve roads, entrances,
   shadows, and neighboring structures.
2. **One visual language:** terrain, roads, construction, architecture,
   vegetation, props, and state treatment share projection, scale, light,
   material, palette, and LOD hierarchy. No visible legacy or programmer-art
   fallback remains in the accepted journey.
3. **World dominance:** developed content and a truthful expansion corridor
   fill 55--70 percent of the unobstructed world band at default and exact
   900 x 600. The HUD does not hide the active place.
4. **Playable clarity:** a new player discovers useful frontage, distinguishes
   valid and blocked sites, watches construction, diagnoses local trouble, and
   recognizes recovery primarily from the place rather than from labels.
5. **Interaction restraint:** selection, hover, build preview, rejection,
   overlays, and consequence cues never obscure the target or duplicate the
   same message.
6. **Operational quality:** hit testing, keyboard routes, accessibility,
   Reduce Motion, save/load, undo, deterministic identity, LOD transitions,
   node/action stability, and texture residency remain within approved bounds.
7. **Independent acceptance:** integration and playtest each score the exact
   candidate at least 17/20 with no category below 3/4 and no automatic reject.

Asset count, generated-source count, commit count, and test count do not
substitute for these outcomes.

## Ownership boundary

The renderer lane owns `Rendering/`, world resources, renderer-local asset
descriptors and tools, focused tests, telemetry, and staged visual evidence.

The lane may implement the calibration subset of CONTRACT-006 required to make
the current nine semantic assets safe: footprint, ground contact, opaque and
shadow bounds, anchor, frontage, LOD registration, validation, descriptor-driven
loading, and bounded residency. Deterministic page packing, the complete atlas
pipeline, and catalog breadth remain PLAY-023 work.

The lane must not edit SwiftUI HUD composition, public store/snapshot contracts,
commands, save schemas, package topology, build scripts, gameplay balance, or
legacy Python. If the existing viewport-inset or truth contract prevents the
player outcome, stop and submit the smallest contract proposal to integration.

## Round 1 — overlap-safe playable corridor

Round 1 is the authorized implementation round. It must produce a visibly
better real app, not only new infrastructure. Commit each milestone separately
and keep the branch clean between milestones.

### Milestone 1 — enforce physical asset geometry

**Targets:** WR-001, WR-002, WR-004, WR-005, WR-010, WR-028.

- Extend the calibration descriptor with:
  - `footprintTiles` and supported orientation;
  - original canvas, trim rectangle, and per-LOD texture identity;
  - ground pivot and normalized SpriteKit anchor;
  - ground-contact polygon;
  - opaque silhouette bounds;
  - baked shadow bounds and light direction;
  - allowed vertical/roof overhang and forbidden lateral intrusion;
  - frontage/entrance edge, road setback, and prop exclusion zones;
  - decoded-byte estimate and residency identity.
- Correct the current manifest so grass is not a 216 x 144 plate attached to
  every 72 x 36 cell. Ground material must be map- or tile-scale by contract.
- Make `WorldAssetCatalog`, `TerrainRenderer`, and `LotRenderer` consume the
  descriptor rather than infer hard-coded size and anchor behavior.
- Split ground, structure, shadow, canopy/foreground, and systemic props into
  controlled depth roles. Preserve legitimate vertical height while preventing
  sideways intrusion over roads and neighboring lots.
- Add deterministic validation for:
  - footprint and ground-pivot registration at every LOD;
  - ground/shadow containment and allowed overhang;
  - reciprocal neighbor collision across the golden corridor;
  - roads and entrances remaining unobscured;
  - no missing/orphan calibration entry;
  - stable residency after repeated LOD cycles.
- Do not generate new art during this milestone. Scale, trim, or reject the
  retained calibration sources against the contract first.

**Milestone exit:** the exact golden-corridor fixture has zero unintended
building/building, building/road, and ground/road collisions; no LOD pivot jump
exceeds 0.5 world point; the staged app visibly removes the audited overlaps;
regular and compact memory remain within baseline +128 MiB after LOD cycling.

### Milestone 2 — build one coherent street and terrain system

**Targets:** WR-006, WR-011, WR-012, WR-014, WR-016, WR-017, WR-022, WR-026.

- Replace the repeated gold-green tile plate with a quiet macro terrain bed and
  restrained deterministic parcel variation.
- Complete the deterministic road grammar for every mask used by the corridor:
  pavement, curb, sidewalk, crossing, frontage join, and an intentional
  terminus or continuation socket. ImageGen never decides connectivity.
- Make building orientation and entrance agree with the authoritative frontage
  edge. Do not rotate only the ground treatment below fixed architecture.
- Publish and validate a scale sheet for door, floor, road, curb, tree, vehicle,
  one-tile building, and landmark exceptions.
- Compose the default camera from developed visual bounds plus at least three
  truthful frontage opportunities using the current measured viewport insets.
- Art-direct city, neighborhood, and block stops to reveal district massing,
  street/frontage structure, and parcel/material detail respectively.

Built-in ImageGen may replace a retained source only after Milestone 1 passes
and only with the approved Gate A style anchor plus an exact deterministic
geometry template. One call produces one source; retain prompt, reference and
source hashes, cleanup command, provenance, and rejection reason. Stop a family
after two repeated geometry or style failures.

**Milestone exit:** no visible seam, unexplained road end, frontage mismatch,
or terrain placemat in the corridor; developed content occupies 55--70 percent
of the unobstructed default and compact world band; each LOD adds useful
information without contact-point drift.

### Milestone 3 — unify the complete visible set

**Targets:** WR-003, WR-013, WR-014, WR-015, WR-024, WR-025, WR-027.

- Inventory every asset path visible during the staged opening, one committed
  construction, utility diagnosis, remedy, and recovery.
- Replace or withdraw every visible legacy/procedural fallback in that journey.
  A coherent visible set is the gate; asset breadth outside the journey is not.
- Rebuild prepared-site, foundation/frame, and finishing construction inside
  the declared parcel footprint and in the same material/light language as the
  completed lot.
- Separate baked architecture from renderer-owned ground, shadow, vegetation,
  and props so content is not double-counted.
- Add a coherent vegetation cluster, one pedestrian pair, one parked service
  object, and bounded truth-safe activity at useful LODs. Reduce Motion retains
  equivalent static meaning.
- Verify palette and value hierarchy in color, grayscale, and common color-
  vision simulations.

**Milestone exit:** no player-visible high/low-fidelity discontinuity in the
entire corridor journey; construction is recognizable at each authoritative
stage; normal play reads as a place rather than a collection of sprites.

### Milestone 4 — make interaction reveal instead of obscure

**Targets:** WR-007, WR-008, WR-018, WR-019, WR-020, WR-021, WR-023.

- Introduce a renderer-local visual-priority policy for Normal, Hover,
  Selected, Build-valid, Build-invalid, Overlay-focus, and Consequence-focus.
- Selection uses one grounded non-color parcel boundary and one compact anchor.
  Remove the floating `SELECTED` label, beam forest, and redundant marks.
- Suppress the large hover billboard during selection, build, active feedback,
  and keyboard navigation. Keep any tooltip small, delayed, edge-aware, and
  outside the target footprint.
- Present an invalid footprint through material and shape, then show the reason
  once. Do not repeat it in a billboard, toast, and label.
- Replace map-wide diagnostic washes with sparse contours, networks, edge
  treatments, and affected-place emphasis that preserve local material and
  building identity.
- Distinguish keyboard selection, pointer hover, and pending placement in both
  visual and accessibility descriptions.
- Refit or reveal the active coordinate against existing viewport insets when
  compact chrome, Details, objectives, or overlay legends change.

**Milestone exit:** the target building, road, and parcel remain readable in
every interaction state; persistent status glyphs occupy less than 3 percent of
the world viewport; the active coordinate is not hidden at default or exact
900 x 600; rejection copy appears once.

## Round 1 acceptance packet

The lane returns one clean exact candidate only after all four milestones pass.
Its completion record must contain:

- ordered focused commits and full changed-surface inventory;
- the exact baseline, candidate, bundle, executable, resource-manifest, data-
  root, save, PID, tick, window, camera, and display identities;
- uncropped live default and exact 900 x 600 captures for city, neighborhood,
  and block stops;
- normal, selected, valid, invalid, construction stages, overlay, and Reduce
  Motion frames in color and grayscale;
- an automated opaque-bounds/collision report and road/terrain seam mosaics;
- one continuous pan/zoom recording of at least 20 seconds;
- pointer and keyboard journeys through discovery, valid/invalid preview,
  commit, construction visibility, and undo;
- focused renderer tests, full native suite, `git diff --check`, staged
  verification, candidate isolation, hit testing, accessibility, save/load,
  undo, and Reduce Motion results;
- before/after changed and unchanged renderer timing, node/draw/action counts,
  named decoded texture bytes, compact and regular RSS/footprint, and repeated
  LOD high-water.

Round 1 is returned, not accepted, if any visible overlap remains; if the world
still mixes art languages; if the default/city frame is mostly empty; if roads
have unexplained ends; if selection/overlays obscure the place; if any fallback
is silent; or if memory exceeds the approved ceiling.

## Round 2 — embodied consequence and recovery

Round 2 begins only after integration and playtest accept Round 1's physical
world. It maps the accepted PLAY-041 truth into asset-specific place changes:

- power through windows, signs, fixtures, equipment, and bounded repair work;
- water through fountain operation, planting, soil/surface state, and service
  objects;
- pollution through localized material/air treatment near authoritative
  sources;
- vitality through maintenance, frontage use, canopy, planting, and bounded
  activity;
- recovery by removing the physical symptom at the same coordinate, followed
  by one short secondary confirmation.

Players must classify normal, strained, and recovered unlabeled grayscale
pairs correctly in at least four of five trials. The full uncoached build ->
diagnose -> remedy -> recover -> undo journey must complete in at most three
minutes by pointer and keyboard.

## Round 3 — breadth and legacy retirement

After Round 2 acceptance, PLAY-023 through PLAY-026 generalize the validated
system:

1. deterministic atlas packing, complete manifest/provenance, staging digests,
   bounded LOD page cache, and rollback;
2. complete terrain, roads, frontages, vegetation, and environmental props;
3. every building identity, density, construction, condition, and recovery
   family;
4. zero visible legacy loads or special-case district plates in production.

The final production candidate must pass the complete journey, the full native
gate, exact staged operation, zero fallback, stable memory/actions, and the
independent 17/20 score from both integration and playtest.

## Stop conditions

Stop and return to integration for:

- a required public store, snapshot, command, theme, package, build-script, or
  save change;
- a solution that generates gameplay geometry or duplicates simulation truth;
- unrelated dirty work or a claim/path ownership conflict;
- two repeated ImageGen failures for one family;
- a candidate that can pass only by hiding city acreage, cropping proof, or
  disabling an interaction/state;
- unbounded texture, node, action, or LOD residency;
- inability to complete Round 1 as one player-visible corridor slice.

Workers commit locally and never push, merge to `master`, or self-accept.
