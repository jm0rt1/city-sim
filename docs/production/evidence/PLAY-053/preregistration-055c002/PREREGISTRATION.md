# PLAY-053 World Excellence Preregistration

- **Disposition:** preregistered; no candidate has been received or scored
- **Published authority:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Authority product baseline:** `7943b9031f2ad00759dc5aa7ce234b8b152e5fc2`
- **Prior authority:** `055c002fef5f1b6eb0bd6d35e21f75923c67aa48`
- **Lane:** playtest quality
- **Claim:** `PLAY-053`
- **Binding contract:** `docs/production/WAVE-006-WORLD-EXCELLENCE.md`
- **Preregistration date:** July 24, 2026

This record freezes the independent gate before the final integrated
PLAY-024/PLAY-039 candidate is supplied. It does not approve the baseline,
pre-score either product lane, or authorize a product repair.

## Frozen staged baseline identity

The published authority is a management/document authority over the exact
Wave 005 product baseline below. The staged app was not rebuilt or substituted.

| Identity surface | Frozen value |
|---|---|
| Staged product commit | `7943b9031f2ad00759dc5aa7ce234b8b152e5fc2` |
| Bundle | `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/CitySim.app` |
| Executable | `CitySim.app/Contents/MacOS/CitySimNative` |
| Bundle identifier / preferences domain | `com.jfmortensen.citysim` |
| Candidate / worktree token | `master` / `production` |
| Staging manifest | `dist/manifests/master.manifest` |
| Staging-manifest SHA-256 | `078fa1da6324cef550c89377a0d5953fdff9d64731fdae3b20f489d71764300b` |
| Executable SHA-256 | `e08eae4398ae88d1257c776eba11ff0f4485148130bd208e9b8890203dc0c160` |
| Pack | `generated-v4-calibration`, schema 4 |
| Staged generated-v4 manifest SHA-256 | `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72` |
| Staged atlas manifest SHA-256 | `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d` |
| Default decorated frame | 1,278 x 768 pixels |
| Compact decorated frame | 900 x 652 pixels, exact 900 x 600 content |

Each route used a fresh `CITYSIM_DATA_ROOT` below
`/private/tmp/citysim-play053-baseline.Kv7Bct`. The exact production
executable was the sole process at that path for each capture:

| Route | Exact PID |
|---|---:|
| Same-state default | `96017` |
| Same-state compact | `98232` |
| Authored fresh-start default | `9396` |
| Authored fresh-start compact | `15299` |

Each PID was terminated after its capture. Separately owned world-rendering
and UI/input processes were left untouched. The final process check found no
process using the production executable path.

## Two comparisons, never one

### Comparison A — same-state presentation

Purpose: isolate world/HUD presentation from gameplay topology.

The frozen state is the immutable PLAY-047 industrial-complication fixture:

| State surface | Frozen value |
|---|---|
| Source object | `7943b9031f2ad00759dc5aa7ce234b8b152e5fc2:Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-industrial-complication-v1.json` |
| Fixture SHA-256 | `660ed6a93c54b7e853e4fc6e9388e29d048b5bdbaefdd5cde066ca5be0dc05f1` |
| Fixture bytes | 132,912 |
| Fixture-manifest SHA-256 | `aa62273943debe4b841a324584468a1953039f1a399e570321cbca46f4dcb000` |
| Fixture id / seed | `industrial-complication-v1` / `42` |
| Tick / day / status | `128` / `33` / `playing` |
| State digest | `37c1cf4e620c8af5741fd9f4b4acfa9b7976d49f6149ec88475ac2b260f1529e` |
| Spatial digest | `de611c63c11a2c2004e329b5dccc9d60193ceb547895f79c4bcf9992bef1bd90` |

The baseline and candidate must load byte-identical fixture data into fresh
roots, remain paused, close transient surfaces, clear selection, use the City
layer, and invoke deterministic developed-bounds framing with `0`. Default
and compact captures must be uncropped, include the full decorated window,
and retain a full AX tree.

The candidate earns the required explicit preference only if the new
world/HUD is materially preferred in both default and compact while every
authoritative tile, road, occupied parcel, state digest, spatial digest, tick,
selection, and consequence remains equal. A tie, an ambiguous preference, a
camera change that hides a defect, or any state mismatch fails Comparison A.

### Comparison B — authored fresh-start composition and choice

Purpose: judge the richer PLAY-016/PLAY-048 starter city as a gameplay
composition, including credible growth choices.

The old authored baseline was reset with Command-N, immediately paused with
Space at Day 1, framed with `0`, left unselected on the City layer, and
captured after transient feedback expired. The retained AX state records:

- treasury `$26,000`, cashflow `-$61 / cycle`;
- residents `300`, jobs filled `190`;
- spare power `54` default / `55` compact and spare water `48`;
- the `Choose a growth engine` decision with two available routes; and
- no selected block, with the City map focused.

The candidate comparison must begin from its own authentic authored Day 1
state after integrated PLAY-016/PLAY-048. It must use the same input sequence,
window sizes, camera command, paused state, City layer, no selection, and
transient-free capture conditions. Quality will record its exact seed,
topology inventory, state/spatial digests, road-access growth choices, and
player-facing starting metrics before comparing:

1. whether the opening reads as a connected district rather than a crossroads
   diorama;
2. whether at least two legitimate, visually legible growth directions exist;
3. whether the deficit, utility headroom, strategy decision, recovery, and
   Charter horizon remain truthful; and
4. whether default and compact both make the city—not HUD chrome—the hero.

Comparison B is not a same-state art comparison. A new road, occupied lot, or
changed topology may earn composition/player-choice credit only when it is
authoritative PLAY-016 state adopted by PLAY-048. It may never be described as
renderer-only improvement. Decorative density, non-authoritative streets, or
a beauty-only camera automatically rejects the candidate.

## Frozen 20-point rubric

Each category is scored from zero through four. Every lost point must name a
visible or operational cause and retained evidence. Acceptance requires:

- at least **19/20** independently;
- **4/4** in category 1;
- **4/4** in category 2;
- no category below **3/4**;
- zero automatic rejects; and
- an explicit material preference in Comparison A plus an explicit
  composition/player-choice preference in Comparison B.

The prior 17/20 result is historical context only and cannot satisfy this
gate.

### 1. Composition and map occupancy — must score 4/4

Four requires all of the following:

- both comparisons pass at default and exact compact;
- the city reads as a connected, inhabited civic fabric at city,
  neighborhood, and block stops;
- developed mass and legitimate growth directions—not empty board space—lead
  the eye;
- no accidental interior road stub, toy-island framing, or dominant
  featureless green field exists;
- the unobscured map aperture is materially larger than the frozen baseline;
  measured at the vertical center line, compact must exceed the retained
  `246/600` points (41%) by at least 9 percentage points, and default must
  increase by at least 5 percentage points under the identical mask method;
  and
- the priority, command deck, selection explanation, and transient feedback
  never obscure the active target.

Three indicates a usable but non-excellent composition and therefore rejects
the wave. Two indicates obvious empty/diorama framing or weak hierarchy. One
indicates severe obstruction or disconnected composition. Zero indicates
unusable or false presentation.

### 2. Projection, material, light, and street coherence — must score 4/4

Four requires shared projection, scale, light direction, material response,
ground contact, and edge treatment across terrain, roads, buildings,
vegetation, water, utilities, and props. The visible road network must have
continuous lane/curb/sidewalk/crossing/frontage grammar at all 16 masks and
all three LODs. Every visible ending must be an authoritative edge
continuation, intentional entrance, turning head, or physically legible
terminus. Reciprocal seams, pivots, opaque bounds, foundations, and contact
shadows must be clean under continuous pan/zoom and retained contact sheets.

Three means coherent shipping work with one explainable minor visual defect
and rejects the wave because this category must be four. Two exposes mixed
fidelity/projection/light or repeated seams. One exposes broad floating,
overlap, or broken-road defects. Zero is systemically incoherent.

### 3. LOD usefulness, depth, variety, and district life — minimum 3/4

Four requires three meaningfully different stops:

- city reveals connected districts, developed mass, terrain composition, and
  strategic context;
- neighborhood reveals streets, frontages, crossings, public realm,
  utilities, vegetation, and district identity; and
- block reveals construction stage, entrances, condition, ground contact,
  selected target, and valid/invalid placement truth.

Zooming must add meaning rather than merely resize textures. Repetition may
support systemic identity but may not make every district read as a clone.
Deterministic ambient life must make the city inhabited without covering
targets or inventing agents/facts. Three allows one minor variety/depth
shortfall. Two or below fails.

### 4. State, consequence, and interaction clarity — minimum 3/4

Four requires restrained, non-obscuring, non-color-only presentation of:

- no selection, selected target, valid preview, invalid preview, and committed
  construction;
- construction stages, operating state, strain/decline, and recovery;
- City plus utility/pollution overlays;
- normal and Reduce Motion event meaning; and
- pointer, keyboard Return/Space, Full Keyboard Access, and AX activation of
  exactly the same announced coordinate and action.

The active target must remain the strongest local interaction cue. Preview,
AX value/help/action, click, Return/Space, and post-action feedback must agree
on coordinate, availability, and reason. Three allows one non-blocking clarity
shortfall. False truth, obscuration, duplicated feedback, target
contradiction, or a primary color-only/debug-glyph encoding fails.

### 5. Shipping credibility, HUD integration, accessibility, and performance — minimum 3/4

Four requires:

- a calm world-first hierarchy in default and compact;
- layout stability while simulation state changes;
- pointer/keyboard/FKA/AX focus and Escape restoration without leakage;
- semantic city-map identity and actionable selected-target descriptions;
- no normal-versus-Reduce-Motion information loss;
- deterministic source/staged resource identity with zero silent fallback;
- full native and focused renderer/UI suites green;
- exact staged verification green;
- no continuing RSS high-water after three complete city/neighborhood/block
  cycles, with default and compact settled RSS each no greater than the
  accepted `333.8 MiB` ceiling;
- generated-page residency no greater than the accepted bounded active-plus-
  adjacent set (`10,485,760` bytes at city and `33,554,432` at neighborhood
  or block), unless integration publishes a stricter replacement; and
- declared cold/update/total-render/unchanged-pulse measurements compared by
  the same method, with any regression explained and accepted by integration
  before quality scoring.

Three means every shipping contract passes with a disclosed minor polish
limitation. Two or below fails.

## Automatic-reject checklist

Any checked item rejects the exact candidate regardless of total:

- [ ] substitute commit, bundle, resources, state, camera, window, or PID;
- [ ] cropped, scaled, composited, harness-only, author-only, or default-only
      proof;
- [ ] starter-topology change represented as same-state presentation proof;
- [ ] decorative road or occupied parcel not present in authoritative state;
- [ ] toy island, demo diorama, mostly empty city frame, or beauty-only camera;
- [ ] accidental/disconnected non-edge road ending;
- [ ] one connected featureless-green region is the largest visual mass or
      occupies more than 25% of the unobscured map aperture;
- [ ] visible sprite overlap, floating foundation, broken ground contact,
      reciprocal seam, pivot drift, or prop/entrance collision;
- [ ] mixed projection, scale, light direction, material response, or
      high-resolution buildings pasted onto lower-fidelity terrain;
- [ ] debug label, glyph, color wash, or animation carries primary world truth;
- [ ] HUD chrome or feedback obscures the active target or reads more strongly
      than the city;
- [ ] selection, preview, consequence, construction, strain, or recovery is
      false, lost, or visually ambiguous;
- [ ] city/neighborhood/block stops do not provide three useful meanings;
- [ ] pointer/keyboard/FKA/AX disagree, focus is lost, hit testing moves, or a
      modal/text field leaks gameplay commands;
- [ ] Reduce Motion removes required meaning or changes authoritative state;
- [ ] silent fallback, mismatched pack/hash/manifest, ambiguous process
      identity, or non-deterministic replay;
- [ ] memory/residency/frame budget regression, continuing high-water growth,
      or unexplained performance degradation; or
- [ ] full native suite, exact staged verification, overlap/seam diagnostics,
      or required real-app route fails.

## Candidate identity and evidence protocol

Integration must supply exact integrated product and evidence commits. Before
interaction, quality will record and verify:

1. product commit ancestry and clean candidate worktree;
2. bundle path, bundle identifier, display name, preferences domain, data
   root, staging-manifest path and hash, executable path and hash, resource
   pack/schema, generated manifest/page hashes, and build timestamp;
3. exactly one live PID for that executable and proof the AX window belongs to
   it, without terminating another owner's process;
4. default decorated-window pixels and exact 900 x 600 compact content on the
   same display/scale;
5. fixture bytes, seed, tick/day/status, state digest, spatial digest,
   selection, layer, camera command/scale/center, and Reduce Motion setting;
   and
6. full source/staged validation, test counts/timing, memory/RSS method,
   residency, fallback diagnostics, and frame-timing method.

The retained candidate packet must include uncropped JPEG/PNG frames and full
AX trees for both comparisons; city/neighborhood/block; normal/selection/
valid/invalid/construction; strain/recovery; overlay; Reduce Motion; pointer,
keyboard, FKA, and AX routes. It must also include command/focus logs,
overlap/seam/road-contact diagnostics, exact hashes/PIDs, timing/RSS records,
and a quality-authored scorecard. Author evidence may corroborate identity and
engineering properties but never supplies the independent score.

## Frozen baseline evidence

| Artifact | Purpose | SHA-256 |
|---|---|---|
| `baseline/wave005-default-industrial-complication-055c002.jpeg` | Comparison A, default | `abe4a86eda5c212e9b94bf3998f9671866cf7a33e5a74be930c1128f2ab457ab` |
| `baseline/wave005-default-industrial-complication-055c002-ax.txt` | Comparison A default AX | `1b41c73974a8974b7993a8e8bdb6fa83141ce6ae9f7293bcd876a3aa28df4386` |
| `baseline/wave005-compact-industrial-complication-055c002.jpeg` | Comparison A, exact compact | `b24709d237f8a9014511ec3b894fecf241058442490d632523540295fe96c084` |
| `baseline/wave005-compact-industrial-complication-055c002-ax.txt` | Comparison A compact AX | `60e9188cf40b1c71d826dd39f6ca2a0205ff8b889b4bf40a2f6f3a3c81785827` |
| `baseline/wave005-default-authored-fresh-start-055c002.jpeg` | Comparison B, old default Day 1 | `f932fcfe6ffe780e7ea350c3687731010e1b586ab4ad73e650100d7660664303` |
| `baseline/wave005-default-authored-fresh-start-055c002-ax.txt` | Comparison B default AX | `b73f20851dffdde16abf4ff20d0037e3c2a82106826f00620c28b2bbdf4c7aad` |
| `baseline/wave005-compact-authored-fresh-start-055c002.jpeg` | Comparison B, old exact-compact Day 1 | `8e8062c6ba7251e7796732888e90332d24304a3560c641a47bda5c185747a594` |
| `baseline/wave005-compact-authored-fresh-start-055c002-ax.txt` | Comparison B compact AX | `b2e88e7e2195f058e67d00a33240848107ca0a60822f02ccca9444a3216d0f76` |

The four frames are uncropped decorated-window captures. No score is assigned
here. Final scoring remains blocked until integration supplies the exact
integrated PLAY-024/PLAY-039 candidate.
