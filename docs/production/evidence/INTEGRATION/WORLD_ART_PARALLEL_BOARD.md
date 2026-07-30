# World Art Parallel Workstream Board

- **Parallel operating authority:** `508619b5ef64ef21fb7a2a6a032b4f16f4e1a2f7`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `12bcb1a2c740d30cebdc975c2f0882f63de6b6cf` | publish one narrow static-a diagnostic retry authority; static-b and pixels remain closed |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `a897f16e509e35c307c1260824b22c04a0c0e3d8` | complete independent portability review, then integrate or return East only |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `787d3f4d72bb71d9dd20773b417effcff9fa8382` | complete independent portability review, then integrate or return South only |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `2e4c682f60e48e503d097723f8b853b691a12503` | merge the independently approved exact tip after this control checkpoint |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `8c50496f07298b40adc1be213eb66af52aa62d46` | finish the active exact Industrial L3 technical gate and return one same-SHA QA candidate |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | start the one fresh gate only on an exact atomic 4/4 renderer candidate |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `01:18Z` refresh, all four direction cells have returned independent
clean checkpoints. North's pure lowering phase passed, but `static-a` failed
closed before producing any output; Integration is designing a diagnostic-only
retry authority while `static-b` and all pixels remain closed. East and South
returned additive current-baseline prelock successors and are undergoing
independent portability review in parallel. West's v4 successor passed
independent review and is queued for its exact merge-only integration after
this refreshed control checkpoint. Renderer has durably committed the exact
Industrial L3 recovery product and evidence layers and continues the full
technical gate. QA remains preregistered; its candidate-neutral preparation is
exhausted and final scoring waits for one immutable renderer candidate.

The compute envelope currently permits zero DCC processes. A new authority
must explicitly reopen a single North diagnostic slot. North Process A/B/C and
all East/South/West DCC or pixel work remain closed. When North later earns an
appearance lock, a new release will schedule the four source cells and their
direction-local A/B/C process fan-outs.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
