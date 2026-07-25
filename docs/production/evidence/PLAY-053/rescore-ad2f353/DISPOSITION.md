# PLAY-053 Final World-Excellence Rescore — APPROVED

- Exact published candidate:
  `ad2f35314bb471a07923c41653374b05ace51ee3`
- Preserved prior rejection:
  `6803f6146febd2c011ed1e8a1abd346a9825837b`
- Prior score: 14/20, rejected
- Independent rescore: **19/20, approved**
- Product changes: none
- Quality disposition: **ACCEPT `ad2f353` for PLAY-053**

This is an independent quality disposition for the exact published product.
The renderer author's conclusions were not reused as the score.

## Comparison A — city composition and readability

**Materially preferred at regular and exact compact.**

Visible deltas from the retained 14/20 frame:

- deterministic `0` now frames the eight-lot pressured district rather than
  the entire opportunity loop;
- developed width occupancy is frozen at `0.7473417931726477` regular and
  `0.5796985019395197` compact;
- connected streets, occupied frontage, civic center, utility landmark, and
  two growth directions lead the eye before empty board space;
- the prior aperture-spanning dark terrain-cell boundaries are absent;
- ordinary City view no longer shows the facade rectangles, thin poles,
  circles, or floating residential status bar visible in the rejection;
- roads remain authoritative, continuous, and physically legible beyond the
  focused frame rather than being deleted for the camera; and
- regular and compact retain a calm world-first hierarchy without clipping
  the active district.

The green public realm remains broad, but it is materially varied with bounded
terrain contours, vegetation, public-realm details, streets, and occupied
frontage. It is not one featureless connected mass and does not trigger the
green-board automatic reject.

## Comparison B — pollution and consequence presentation

**Materially preferred at regular and exact compact.**

The prior large X/bolt/check marks that covered building silhouettes have been
replaced by sparse, grounded condition marks. Pollution remains visible near
the affected foundations without hiding entrances, massing, selection, or
roads. The persistent legend provides Clean, Watch, and Polluted shapes and
labels, so color is not the sole carrier of truth. AX exposes
`Pollution layer legend` and the selected layer. Reduce Motion retains the
same state and legend without informational loss.

## Independent 20-point score

| Category | Score | Independent finding |
|---|---:|---|
| 1. Composition and map occupancy | **4/4** | Both comparisons pass at regular and compact. Developed mass dominates the deterministic frame, road topology is connected, growth directions remain visible, and neither HUD nor feedback obscures the target. |
| 2. Projection, material, light, and street coherence | **4/4** | Terrain, roads, buildings, vegetation, props, foundations, shadows, and curbs share a coherent isometric projection and light direction. Continuous inspection found no visible reciprocal seam, floating contact, accidental terminus, overlap, or mixed-fidelity break. |
| 3. LOD usefulness, depth, variety, and district life | **3/4** | City, neighborhood, and block stops remain stable and useful, and zoom exposes frontage, pedestrians, vegetation, construction, and contact detail. One point remains lost because the authored building-family breadth is still narrow and district silhouettes repeat; the published PLAY-024 completion explicitly defers directional family expansion. |
| 4. State, consequence, and interaction clarity | **4/4** | Normal, selection, occupied rejection, valid preview, committed construction, pollution, and Reduce Motion remain distinct. Pointer, Return, and AX each constructed exactly `15,11` once; Undo restored the state. |
| 5. Shipping credibility, HUD, accessibility, and performance | **4/4** | Exact identity, explicit regular/compact sizing, focus/FKA/AX, full tests, staged resources, geometry, fallback, RSS, residency, cold-render, and unchanged-pulse contracts pass. |
| **Total** | **19/20** | Meets the binding threshold. |

Composition and coherence are both 4/4, no category is below 3, and no
automatic reject is present.

## Automatic-reject audit

None triggered:

- no substitute commit, bundle, resource pack, fixture, PID, camera contract,
  or scored window;
- no cropped, scaled, composited, author-only, harness-only, or default-only
  visual proof;
- no topology change mislabeled as same-state art;
- no decorative road or occupied parcel outside authoritative state;
- no toy island, demo diorama, mostly empty priority frame, beauty-only
  camera, or dominant featureless-green region;
- no accidental road end, disconnected road, reciprocal seam, pivot drift,
  sprite overlap, floating foundation, broken contact, or entrance/prop
  collision;
- no mixed projection, scale, light direction, or pasted high-resolution
  building language;
- no debug glyph, label, color wash, or animation carrying primary truth;
- no HUD or feedback obscuring the active target;
- no false selection, preview, construction, strain, recovery, or overlay
  truth;
- no loss of useful city/neighborhood/block meaning;
- no pointer/keyboard/FKA/AX contradiction, focus loss, or modal/text leakage;
- no Reduce Motion state or information loss;
- no fallback, hash mismatch, ambiguous scored PID, or deterministic-state
  mismatch; and
- no memory, residency, cold-render, unchanged-pulse, geometry, staged-build,
  or native-suite failure.

The initial inherited compact window was identified before scoring, excluded,
and removed after explicit regular and compact replacement routes were
retained. It is not used to satisfy the regular-window gate.

## Hands-on interaction

On the explicit compact interaction process:

1. Command-O loaded the frozen fixture paused; `0` reset the camera.
2. `H` selected Residential and keyboard navigation announced occupied block
   `10,12`.
3. A pointer map activation targeted occupied City Hall block `12,12`.
   Rejection remained visible beyond four seconds, retained Residential, and
   announced the exact reason.
4. Keyboard navigation selected valid block `15,11`; the AX map value and
   help agreed on availability, cost, coordinate, and primary action.
5. A physical pointer click at the visible selected diamond constructed
   Residential at `15,11` exactly once.
6. Undo restored `$34,037` and removed the construction.
7. A keyboard-only route selected `15,11`, Return constructed it exactly once,
   and Command-Z restored the state.
8. The exposed AX action `Build Residential at block 15, 11` constructed the
   same coordinate exactly once, and Undo restored it.
9. Tab handed focus out to Full Keyboard Access; Shift-Tab restored semantic
   map focus without changing state.

The AX tree announces construction at zero percent and retains coordinate,
availability, cost, upkeep, road requirement, utility/pollution/vitality
truth, and the non-color pollution legend.

## Automated and engineering validation

- Exact stage-only governed build: passed in 1.93 seconds.
- Full native suite: **201/201 passed**, zero failures, 84.678 seconds.
- Focused returned-camera test: **1/1 passed**, zero failures, 1.769 seconds.
- `WorldRenderingTests`: **43/43 passed**, zero failures, 14.757 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `git diff --check`: passed.
- World-pack validator: 84 payload checks, 84 extrusion checks, 974 packed
  overlap checks, four pages, 133 inventory entries, exact source/staged
  parity, zero failures.
- Production-geometry validator: 324 reciprocal ground contacts, 36
  building/road setbacks, 256 entrance/prop exclusions, zero collisions and
  zero failures.
- Active-plus-adjacent residency: 10,485,760 bytes city and 33,554,432 bytes
  neighborhood/block.
- Independent cold renderer: 3.749 ms world update, 4.973 ms total render,
  zero decode loads.
- Thirty-minute-equivalent unchanged-pulse soak: 0.0006 ms average, stable
  node identity, two bounded actions.
- Settled regular RSS: 126,320 KiB after 76 seconds.
- Settled explicit compact interaction RSS: 213,984 KiB after 84 seconds.
- Reduce Motion observed RSS: 229,808 KiB after 29 seconds.

All observed RSS values remain below the 333.8 MiB ceiling. No continuing
high-water growth was observed.

## Evidence limitations

- The first default attempt inherited compact sizing. It was detected before
  scoring, excluded and removed, and replaced by explicit regular and compact
  routes.
- The real-app regular proof contract requests 1,278 by 768 NSWindow content,
  while the deterministic renderer camera fixture is 1,280 by 800. These are
  recorded separately rather than conflated.
- Category 3 remains 3/4 because building-family and directional-view variety
  are visibly limited and deferred to the next world-art claim. This is a
  disclosed excellence limitation, not an automatic reject for this exact
  compatible candidate.

## Disposition

**APPROVED.** Exact published candidate `ad2f353` reaches 19/20 with mandatory
4/4 composition, mandatory 4/4 coherence, no category below 3, zero automatic
rejects, and explicit material preference in both governed comparisons.
