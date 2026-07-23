# PLAY-052 independent renderer gate — candidate 2cf18b0

## Disposition

**REJECTED — 13/20.** The exact frozen renderer candidate does not meet the
required 17/20 threshold and has three categories below 3. The live player
view also triggers automatic rejection for a mostly empty toy-island city
composition, unexplained short road endings, and a mixed visual language
between painterly generated buildings and flat procedural ground/road work.

This is a renderer-only disposition. It does not alter or supersede the
separate UI candidate disposition, the historical `94f68ac` false-negative
record, or any integrated-wave disposition.

## Frozen candidate identity

- Product: `2cf18b0f0d9a0aee9f3708e72593eb6e7cd99ae0`
- Renderer evidence HEAD inspected read-only:
  `f35d6ef2d17376f02fdcee6410cf7ef11f29735a`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle:
  `/Users/James/.codex/worktrees/cac1/city-sim/dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Executable:
  `Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Bundle ID: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Candidate manifest SHA-256:
  `87cb7839f1ab6e6def47b37fa55b87a73c1f588980e40161001bd705014a3cd1`
- Executable SHA-256:
  `af7808aab403b04ffb219842da81f7b9eb1fb69796809b174e35702402e949a7`
- Packaged `generated-v4-manifest.json` SHA-256:
  `900287027256d7f5ea960b7b17c9208f3ff990de532feb87448eb01328076e78`
- Default live PID: `43386`, sole exact executable, terminated with SIGTERM.
- Exact 900 x 600 content / Reduce Motion proof PID: `47798`, sole exact
  executable launched with `CITYSIM_COMPACT_WINDOW=1` and
  `CITYSIM_REDUCE_MOTION_PROOF=1`, terminated with SIGTERM.
- Post-gate process check: no `CitySimNative-w5f893ad1da1b` process remained.

The quality worktree was at `94f68ac99b660b69aaba0d9880088f7c53cfdae4`
before this evidence was authored. The renderer worktree was clean; the
product commit is an ancestor of its evidence HEAD.

## Independent live route

The exact staged app was operated by real pointer and keyboard input. Each
Computer Use capture was taken while a single process resolved to the exact
candidate executable above.

1. Inspected the uncropped default app and AX tree.
2. Paused simulation and exercised developed-city framing, keyboard zoom,
   pointer drag pan, and the close/neighborhood/city LOD range.
3. Selected a commercial block by pointer and a road by keyboard; verified the
   City map AX value announced the semantic target, condition, cause,
   consequence, and primary action.
4. Enabled Utilities, retained the selected target, and inspected live overlay
   legibility.
5. Entered Build > Zones > Residential, moved to a road-adjacent valid parcel
   by keyboard, verified the available primary action in AX, committed with
   Return, and observed the 0% construction foundation followed by the
   completed building after simulation advanced.
6. Relaunched the same exact bundle with explicit compact and Reduce Motion
   proof environments, checked the 900 x 600 content presentation, keyboard
   selection, pointer hit-testing, selected details, and AX identity.

## Frozen 20-point score

| Category | Score | Lost points |
|---|---:|---|
| Composition / map occupancy | **2/4** | The default city is a small crossroads cluster floating in a large undifferentiated green field. `0` reframes the developed bounds and compact fills its shallow aperture better, but neither changes the authored city into a credible district or city composition. |
| Projection / material / light / road coherence | **2/4** | Building projection and lighting are internally consistent, but painterly high-detail structures sit on flat procedural road/ground surfaces. The close intersection produces conspicuous ladder-like white markings, and four short rounded road stubs make the world read as an isolated diorama. |
| Useful city / neighborhood / block LOD and depth | **2/4** | Keyboard zoom is continuous and asset residency changes without visible fallback, but only the close block treatment is materially distinct. Neighborhood and city stops remain nearly the same sparse cluster and do not provide three independently useful reading scales. |
| Believable life / state / interaction restraint | **3/4** | Vehicle/pedestrian accents, selection, Utilities, valid placement, the 0% construction foundation, completion, and consequence AX copy were all live and truthful. The point is lost because life remains sparse/static and compact selected-details mode compresses the visible world enough that the selected target becomes difficult to track visually. |
| Systemic shipping credibility / performance | **4/4** | The exact hashes and resource manifest matched. Frozen engineering evidence reports 135/135, five cold totals of 4.431/4.196/4.476/4.527/4.341 ms, zero fallback, zero governed geometry collisions, and settled regular/compact memory below the ceiling. Per dispatch, quality did not rerun or replace the governed timing series. |
| **Total** | **13/20** | Required: at least 17/20 and no category below 3. |

## Automatic-reject checklist

- **Visible unintended physical overlap:** not reproduced in the live route;
  frozen deterministic geometry evidence reports zero governed collisions.
- **Mixed art language:** **triggered** — painterly generated structures and
  vegetation do not visually integrate with the flat procedural roads/field.
- **Mostly empty city frame:** **triggered** — the authored city is an eight-ish
  structure crossroad island surrounded by empty green space.
- **Unexplained road end:** **triggered** — four short rounded stubs terminate
  around the tiny developed cluster and reinforce the diorama reading.
- **Obscuring selection or overlay:** not an automatic reject in the tested
  states; the cyan target and Utilities overlay remain present, though compact
  details substantially reduce their visual prominence.
- **Duplicated rejection copy:** not observed.
- **Silent fallback:** not observed live; the frozen resource report records
  zero fallback and the packaged generated manifest digest matched.
- **Over-budget memory / continuing high-water growth:** not reported by the
  frozen governed series; regular 198 MB physical footprint and compact 148 MB
  are below the 333.8 MiB ceiling. The series was not rerun by quality, as
  directed.

## Smallest correction list before resubmission

1. Replace the isolated four-stub crossroads composition with a visibly
   connected district/city context that fills the governed developed frame at
   both default and compact without relying on player reframing.
2. Resolve the live road/ground art mismatch and intersection marking clutter;
   road surfaces, shoulders, junction markings, and end conditions must read as
   one coherent physical system with the generated structures.
3. Make city, neighborhood, and block stops visibly and functionally distinct:
   city must communicate network/density, neighborhood must communicate blocks
   and frontage, and block must communicate construction/material detail.

Do not change the working pointer, keyboard, AX, construction truth, packaged
identity, or governed performance properties while addressing the visual
rejection.

## Retained live evidence

- `live/default-city.jpeg` — default uncropped sparse city frame.
- `live/frame-developed.jpeg` — keyboard `0` developed frame.
- `live/block-close.jpeg`, `live/neighborhood-lod.jpeg`, `live/city-lod.jpeg`
  — live LOD comparisons.
- `live/utilities-overlay-selected.jpeg` — selected commercial plus Utilities.
- `live/valid-placement-preview.jpeg` — valid residential placement target.
- `live/construction-stage-0.jpeg` — committed 0% foundation.
- `live/compact-900x600-reduce-motion.jpeg` — exact compact content with Reduce
  Motion proof environment.
- `live/compact-selected-details.jpeg` — compact pointer selection/details.

Limitation: the completed construction state was observed live and confirmed by
the AX value, but its temporary Computer Use image was not retained before the
candidate process was terminated. The 0% construction frame is retained. The
quality lane did not rerun the renderer-owned governed timing series or treat
author conclusions as the visual score.
