# PLAY-052 independent renderer gate — candidate 8433621

## Disposition

**REJECTED — 15/20.** The exact frozen renderer candidate improves the
accepted 13/20 predecessor evidence, but it does not meet the required 17/20
threshold and its believable-life / interaction-restraint category is below
3. The live default route also triggers automatic rejection: an unselected
building hover draws a large cyan ring and arrow over the facade, while the
City map AX value still reports no selected block. The corrected roads remain
visually unfinished where full-detail pavement fades into translucent green
segments and rounded endpoints.

This is a renderer-only disposition. It does not score or supersede the
separate PLAY-052 UI or integrated-wave gates.

## Frozen candidate identity

- Product:
  `8433621760ba169995aa1a5dc81cac27c380d746`
- Renderer evidence inspected read-only:
  `326def7dcf63f70b8dc6d54dab9a1f7e6bbbff7a`
- Renderer completion HEAD:
  `4e44c4ea08caad76c4eabb6e64035fe36a91aff0`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle:
  `/Users/James/.codex/worktrees/cac1/city-sim/dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Executable:
  `Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Bundle ID:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Candidate manifest SHA-256:
  `b96fb7d554aae80eadce5fdd65784844c48fe364a7469d24d3f144180afe6ad9`
- Executable SHA-256:
  `c2d248a290aea3ce164d3edd47131f771fc8eaf8bc00b9645d821e67fb385ff1`
- Packaged and source generated-resource manifest SHA-256:
  `eab12ce0838be9dca6ae00927accac60b15eb41617b39c0e33dd1e727e759692`
- Default live PID: `92966`, sole exact executable, terminated with SIGTERM.
- Explicit compact / Reduce Motion PID: `96793`, sole exact executable
  launched with `CITYSIM_COMPACT_WINDOW=1` and
  `CITYSIM_REDUCE_MOTION_PROOF=1`, terminated with SIGTERM.
- Post-gate process check: no
  `CitySimNative-w5f893ad1da1b` process remained.

The world worktree was clean at completion HEAD. The product is an ancestor of
the evidence commit, and the evidence commit is an ancestor of completion
HEAD. Quality independently verified every retained renderer evidence file
against the renderer-owned 74-entry `SHA256SUMS` from the world repository
root. The quality worktree began this gate clean at
`6e823fd426d14122398039b911cc6d21f5263089`.

## Independent live route

The exact staged app was operated with real pointer and keyboard input. Every
Computer Use capture was bound to the sole exact executable PID named above.

1. Captured the uncropped 1278 x 768 default app with the pointer off the map,
   then captured the unselected hover state. AX continued to report `No block
   selected` while the large cyan ring and arrow covered the commercial
   facade.
2. Paused simulation and traversed city, neighborhood, and block LOD stops
   with keyboard camera commands.
3. Selected City Hall by pointer and a road by keyboard. The semantic City map
   AX value agreed with the selected target and exposed the truthful primary
   action.
4. Enabled the Traffic data layer and retained the selected-road AX identity.
5. Entered Build > Zones > Residential, moved by keyboard to open block
   `14, 11`, verified the available action and exact cost in AX, committed
   with Return, observed the live 0% construction site, advanced simulation,
   and observed the completed building and consequence copy. Undo restored
   the isolated candidate state.
6. Relaunched the same exact executable with explicit compact and Reduce
   Motion proof environments. Captured the uncropped 900 x 652 window content,
   city LOD, keyboard road selection, pointer Power Plant selection, details,
   and AX identity.

## Frozen 20-point score

| Category | Score | Lost points |
|---|---:|---|
| Composition / map occupancy | **3/4** | Default and compact fill the world band more effectively than predecessor `2cf18b0`, and extended roads remove the tiny four-stub silhouette. The city stop still reads as one lightly populated crossroads with roughly eight principal structures rather than a convincing city/network view; large areas remain undifferentiated green. |
| Projection / material / light / road coherence | **3/4** | Road asphalt, lane markings, sidewalks, curbs, intersection contact, building projection, and lighting are materially more coherent than the predecessor. A point is lost because several full-detail roads visibly fade into translucent green opportunity segments with rounded endpoints; these remain ambiguous as physical roads versus placement preview. |
| Useful city / neighborhood / block LOD and depth | **3/4** | City, neighborhood, and block stops are stable and keyboard reachable, with a clearly useful close block treatment and reduced distant texture/detail. City and neighborhood remain visually similar and communicate little additional network or density information beyond scale. |
| Believable life / state / interaction restraint | **2/4** | Vehicle, pedestrian, overlay, construction, completion, pointer, keyboard, and AX states are present and truthful. The category is below gate because the unselected hover indicator is an oversized cyan ring/arrow that covers the facade and reads like a debug targeting glyph; it contradicts the required interaction restraint and obscures the hovered target. Life also remains sparse/static at city scale. |
| Systemic shipping credibility / performance | **4/4** | Exact manifest, executable, resource-manifest, PID, bundle, and all 74 retained evidence hashes matched. Renderer-owned disclosure reports 136/136, five cold totals of 3.913/3.766/3.658/3.800/3.743 ms, 13,521,048 decoded resident bytes, zero fallback, zero governed collisions, regular 252,944 KiB RSS and compact 242,752 KiB RSS below the ceiling. Per dispatch, quality preserved but did not rerun or self-credit the governed series. |
| **Total** | **15/20** | Required: at least 17/20, no category below 3, and no automatic reject. |

## Automatic-reject checklist

- **Visible unintended physical overlap:** not reproduced live. The exact
  retained deterministic collision report names zero ground, setback, or
  entrance/prop collisions.
- **Mixed art language:** not triggered at the predecessor's severity. Roads,
  curbs, sidewalks, and generated buildings now share materially closer
  texture, projection, and light. The translucent opportunity segments remain
  an unresolved coherence loss.
- **Mostly empty city frame:** **triggered at city LOD** — framing is improved,
  but the city stop is still a single sparse crossroads surrounded by a broad
  empty field rather than useful city-scale density.
- **Unexplained road end:** **triggered** — several asphalt roads fade to
  translucent green segments and end in rounded caps without a player-visible
  physical or state explanation.
- **Obscuring target, selection, or overlay:** **triggered** — the no-selection
  hover state draws a large cyan ring and arrow directly over the building
  facade. Pointer selection, keyboard selection, and Traffic overlay were
  otherwise truthful.
- **Duplicated rejection copy:** not observed.
- **Silent fallback:** not observed live; exact packaged resource identity
  matched and the frozen residency disclosure records zero fallback.
- **Over-budget memory / continuing high-water growth:** not reported by the
  frozen governed series. Quality did not replace that series, as directed.
- **Harness-only proof:** not used as the visual score. Default, compact,
  selection, LOD, overlay, construction, completion, keyboard, pointer, AX,
  and Reduce Motion states were operated live. The author-disclosed
  five-stage construction contact sheet and governed performance series remain
  supporting disclosures only.

## Direct comparison with predecessor 2cf18b0

The candidate improves the predecessor from **13/20 to 15/20**:

- composition gains one point because the roads continue beyond the central
  district and default/compact framing occupies the usable world band better;
- material/coherence gains one point because textured asphalt, sidewalks,
  curbs, and intersections replace the flat procedural road treatment;
- LOD remains 3-point quality only after the corrected distant treatment is
  counted as useful but still too subtle between city and neighborhood;
- interaction restraint drops below the gate floor because the independently
  reproduced hover glyph is target-obscuring.

The predecessor's working exact identity, pointer/keyboard/AX behavior,
construction truth, zero fallback/collision, and performance properties were
retained.

## Smallest correction list

1. Replace the oversized cyan hover ring/arrow with a restrained,
   non-obscuring hover treatment distinct from committed selection, and verify
   pointer, keyboard, compact, overlay, valid/invalid placement, and AX parity.
2. Give translucent road continuations an unmistakable player-visible meaning
   or render physically coherent connected/off-frame roads; remove ambiguous
   rounded endpoints.
3. Add enough connected developed context at the city stop to communicate a
   real network/district rather than one crossroads, while retaining compact
   occupancy, the three LODs, exact resource identity, and the disclosed
   engineering properties.

## Retained quality evidence

- `live/default-clean.jpeg` — uncropped default with the pointer off-map.
- `live/default-hover.jpeg` — blocking unselected hover glyph.
- `live/regular-city-lod.jpeg`,
  `live/regular-neighborhood-lod.jpeg`,
  `live/regular-block-lod.jpeg` — three independent live LOD stops.
- `live/regular-pointer-selection.jpeg` and
  `live/regular-keyboard-selection.jpeg` — pointer/keyboard/AX parity.
- `live/regular-traffic-overlay.jpeg` — live overlay state.
- `live/regular-valid-construction-preview.jpeg`,
  `live/regular-construction-0pct.jpeg`, and
  `live/regular-construction-complete.jpeg` — live construction route.
- `live/compact-reduce-motion-default.jpeg`,
  `live/compact-city-lod-reduce-motion.jpeg`,
  `live/compact-keyboard-selection.jpeg`, and
  `live/compact-pointer-selection.jpeg` — explicit compact and Reduce Motion
  route.

Limitations: quality did not rerun or replace the renderer-owned governed
timing/memory series. Full Keyboard Access and spoken VoiceOver narration were
not separately exercised; semantic AX identity/action parity was inspected
live. Continuous pan/zoom was already part of the retained exact-candidate
evidence and was hash-verified, but quality's independent capture retained the
three discrete live LOD stops rather than a new movie. These limitations do
not cause the rejection; the independently reproduced automatic-reject
conditions do.
