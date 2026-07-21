# PLAY-022 world-playability directive

## Decision

Integration rejects the systemic Gate A-R candidate at product commit
`4887ebad9519fccb08844e2746f9bfbbc93aaa4d` and evidence commit
`8cb45b5848f070c25803213ee48b2523e8057d09` as a completed visual or
playability gate. The nine generated sources, deterministic road masks,
incremental rendering, and proof discipline are meaningful engineering progress,
but they do not yet produce a city that guides or rewards play.

Integration score: **10/20**.

| Category | Score | Binding finding |
|---|---:|---|
| Composition and hierarchy | 2/4 | Default centers the settlement, but city scale becomes a tiny cluster in a mostly empty board and compact leaves little decision space. |
| Projection and physical coherence | 2/4 | The central crossing is legible, but ordinary roads terminate repeatedly, several assets read as isolated pieces, and frontage does not describe where the city should grow. |
| Material, light, and depth | 3/4 | The authored civic, park, water, and industrial art is a substantial improvement; flat terrain, primitive trees, and geometric/placeholder-looking structures break the shared finish. |
| Density, variety, and life | 1/4 | Six isolated structures and repeated lollipop trees do not read as an inhabited district; city and neighborhood views expose acreage rather than useful city structure. |
| State and interaction clarity | 2/4 | Valid/invalid placement is explicit, but selection and diagnostic overlays become annotation-heavy, while construction, strain, recovery, and lived activity are not proven as an understandable journey. |

Automatic rejection is triggered by the mostly empty city-scale frame,
unexplained road ends, indicator-heavy selected/utility presentation, and the
unapproved regular-window memory regression. A clean tree, 121 passing tests,
and nine generated assets cannot average away those failures.

The candidate stays preserved on the renderer branch and remains unmerged. The
active PLAY-022 claim continues with the following single authorized slice.

## Gate A-P — playable street corridor

Build one real staged-app journey in which the world itself helps the player:

1. identify an intentional expansion corridor and at least three truthful
   street-frontage opportunities;
2. distinguish a valid build site from a blocked one without opening Details;
3. commit a road or zone project and watch a believable construction sequence;
4. recognize a localized power or water problem from the affected place;
5. build or restore the authoritative remedy and see the same place recover;
6. zoom between city, neighborhood, and block views and gain different useful
   information at every level.

The HUD may confirm cost and state. It may not be the only place the player can
understand opportunity, trouble, construction, or recovery.

## Required renderer work

### 1. Content-aware camera and city composition

- Frame developed bounds plus one intentional expansion corridor rather than
  fitting the entire empty 24 x 24 board at normal city zoom.
- Developed content and truthful opportunity frontage must occupy 55--70
  percent of the available world band at default and exact 900 x 600 compact.
- Keep manual pan and zoom, but make the normal city/neighborhood/block stops
  expose district structure, frontage/state, and parcel detail respectively.
- Prevent HUD occlusion from hiding the selected parcel, placement ghost, or
  active localized consequence at any supported stop.

### 2. Streets that explain expansion

- Replace unexplained rounded road stubs with an intentional terminus,
  continuation socket, or connected extension.
- Give every visible road consistent pavement, curb, sidewalk, crossing, and
  frontage joins. No seam or dead strip may pass as an opportunity cue.
- In build mode only, derive restrained frontage-ready parcel cues from actual
  empty tiles, road adjacency, and the existing placement authority. Never
  label land buildable when the store would reject it.
- Make valid and invalid previews legible through shape and material as well as
  color, while keeping the underlying city visible.

### 3. Consequences embodied in the world

- Use the accepted spatial consequence map and tile fields only.
- Power trouble should first read through windows, service fixtures, and
  localized electrical treatment; water trouble through planting, fountain,
  and surface treatment; pollution and low vitality through maintained versus
  worn materials and landscaping.
- Recovery must remove the physical problem and restore activity/materials at
  the same coordinate. A ring, bolt, label, hatch, or tint may confirm the
  change but cannot be the primary signal.
- No persistent status glyph may exceed 12 percent of its lot bounds, and all
  persistent status glyphs together may not occupy more than 3 percent of the
  world viewport.

### 4. Construction and bounded life

- Replace the abstract central construction shape with grounded prepared-site,
  foundation, frame, and finishing stages that preserve the parcel footprint.
- Construction progress must visibly advance with authoritative
  `constructionProgress` and remain exact across save/load and undo.
- Add deterministic, truth-safe life at neighborhood/block scale: occupied
  residential/commercial pedestrian activity, a parked service object at an
  applicable utility, subtle vegetation, and one bounded repair/recovery cue.
- Reduce Motion removes decorative movement while retaining equivalent static
  meaning.

### 5. Narrow generated-source extension

The renderer may use built-in ImageGen, one distinct call per source, for only:

- `power_plant_l01`;
- prepared-site, structural-frame, and finishing construction assets;
- one deciduous vegetation cluster;
- one pedestrian pair;
- one parked utility/service vehicle;
- one repair/recovery prop set.

These eight sources use the accepted calibration templates, prompt graph,
provenance, chroma cleanup, and ingestion authority. Deterministic code owns
placement, paths, timing, topology, consequence intensity, and state mapping.
No CLI/API transparency fallback, further building breadth, density variants,
or service/civic catalog expansion is authorized in this slice.

### 6. Interaction restraint

- Selected state uses one grounded parcel boundary and one compact anchor; do
  not place a large floating `SELECTED` label, tether forest, or diagnostic
  hatching over unrelated lots.
- Overlay legends remain readable, but the map must retain local structure and
  affected buildings under utilities, pollution, happiness, and traffic.
- Placement rejection copy may appear once. Do not duplicate the same reason in
  a world billboard, toast, and inspector simultaneously.

## Required playability proof

The completion packet must retain one exact staged candidate and prove:

- an uncoached pointer journey and keyboard journey from launch through
  frontage discovery, valid/invalid preview, commit, visible construction,
  utility diagnosis, remedy, visible recovery, and exact undo;
- default and exact 900 x 600 compact at city, neighborhood, and block stops;
- same-coordinate normal, strained, and recovered sequences in color and
  grayscale, with HUD values visible for truth checking;
- a real continuous pan/zoom recording of at least 20 seconds; start/end stills
  do not substitute;
- accessibility descriptions for selected coordinate, kind, level,
  construction stage, authoritative condition, and active consequence;
- full native tests, focused renderer tests, exact staged verification,
  save/load, undo, hit testing, Reduce Motion, and candidate isolation;
- changed and unchanged renderer timing, node/draw/action stability, decoded
  texture bytes, compact and regular RSS, and repeated LOD-cycle high-water.

Fresh-player review targets:

- identify one useful frontage opportunity within 5 seconds;
- classify valid versus blocked placement correctly in at least 4 of 5 trials
  without opening Details;
- classify localized utility trouble and recovery correctly in at least 4 of 5
  unlabeled grayscale pairs;
- complete the rendered build -> diagnose -> remedy -> recover journey without
  developer coaching in at most 3 minutes;
- integration and playtest each score at least 17/20 with no category below 3.

## Performance and stop conditions

The current regular-window result of 609,168 KiB RSS and 475 MiB physical
footprint is not accepted. The next candidate must remain within the recorded
baseline plus 128 MiB in both regular and compact windows, stay stable through
repeated LOD traversal, and keep renderer timing within the approved ceiling.

Stop and return to integration for any new store/snapshot/package contract,
false buildability inference, generated gameplay geometry, duplicated state,
unbounded actions or memory, two repeated generation failures for one source,
or an inability to complete this vertical journey inside one production slice.

Workers commit focused checkpoints locally, never push, never self-accept, and
do not claim PLAY-023 until this playability gate passes.
