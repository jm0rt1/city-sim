# World Art Parallel Workstream Board

- **Parallel operating authority:** `69b62e78f6012115d5d1221cea3a34e26cae5683`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `12bcb1a2c740d30cebdc975c2f0882f63de6b6cf` | complete the read-only recovery-contract audit while Integration publishes retry authority |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `c14911ea13a92874e9910b69a8dd98a763db86d5` | build zero-pixel A/B/C orchestration preparation on the integrated merge checkpoint |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `29a102fff05e027a4379aab1b94db84351bb27e4` | build zero-pixel validation fan-out preparation on the integrated merge checkpoint |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `69b62e78f6012115d5d1221cea3a34e26cae5683` | build zero-pixel review-assembly preparation on exact integrated master |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `cc3112fee68948d8f723c00810077b6abafb53db` | finish the final exact-same-SHA noninteractive check and return the L3 candidate |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | start the one fresh gate only on an exact atomic 4/4 renderer candidate |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `01:26Z` refresh, West's exact merge-only successor and East/South's
narrow additive successors are integrated on master. North, East, South, and
West have each acknowledged a new contract-independent task: North audits the
recovery contract read-only; East prepares future A/B/C process orchestration;
South prepares post-raw validation fan-out; West prepares review assembly.
Renderer is concurrently finishing the exact Industrial L3 recovery gate and
has dirty task-owned evidence in progress. QA remains preregistered; its
candidate-neutral preparation is exhausted and final scoring waits for one
immutable renderer candidate. Five useful rows are active; QA is the only
stage-prohibited row.

The compute envelope currently permits zero DCC processes. A new authority
must explicitly reopen a single North diagnostic slot. North Process A/B/C and
all East/South/West DCC or pixel work remain closed. When North later earns an
appearance lock, a new release will schedule the four source cells and their
direction-local A/B/C process fan-outs.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
