# World Art Parallel Workstream Board

- **Parallel operating authority:** `af6b661b79e0802386123537aaeddce5c9d385f2`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Next release boundary |
|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | exact one-process v08 Process A is rendering | freeze immutable review packet; no B/C |
| East | `codex/citysim-world-art-east` / `PLAY-079` | zero-pixel candidate passed; launch CLI plumbing active | emit fail-closed `launch_bound` packet only with future exact authority |
| South | `codex/citysim-world-art-south` / `PLAY-080` | zero-pixel candidate passed; immutable A/B/C root plumbing active | complete dry launch/assembly path without pixels |
| West | `codex/citysim-world-art-west` / `PLAY-081` | zero-pixel candidate returned clean | independent review plus launch-readiness audit |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | self-contained v2 intake harness accepted and published | sync `af6b661b`; add admission-receipt consumption wrappers |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | 24-cell gate returned for one hash-binding repair | bind materializer, validator, and validation receipt exactly |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

All six rows were active and acknowledged at the `06:40Z` refresh. North owns
the only pixel-producing DCC slot until its exact Process A is reviewed. East,
South, and West remain zero-pixel; Renderer and QA continue candidate-neutral
preparation. After an accepted North appearance lock, the source release will
cap DCC execution at two simultaneous processes unless Integration publishes a
measured exception.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
