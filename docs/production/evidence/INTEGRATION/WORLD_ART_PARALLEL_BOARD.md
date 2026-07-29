# World Art Parallel Workstream Board

- **Parallel operating authority:** `346a27240668d97f0e89b7a9d4be00f9ed6e8239`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Next release boundary |
|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | self-contained v07 pre-pixel architecture accepted from `ea0fe600`; one process-A appearance candidate released | independent A review releases North B/C and sibling A/B/C |
| East | `codex/citysim-world-art-east` / `PLAY-079` | v06 adopted; stale CONTRACT-020 hash repaired; zero-pixel runner/handoff passes with no pixel processes | North appearance lock releases A/B/C |
| South | `codex/citysim-world-art-south` / `PLAY-080` | v06 adopted; static 6/6 and actual-camera 5/5 pass at `0.000183105469` px maximum delta | North appearance lock releases A/B/C |
| West | `codex/citysim-world-art-west` / `PLAY-081` | v06 adopted; two fresh actual-camera proofs are byte-identical with no pixel processes | North appearance lock releases A/B/C |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | accepted bridge identities bound into fail-closed packet schema; stale/mismatched packets reject; focused Integration replay passes 7/7 | quarantine each accepted direction; activate only after exact 4/4 |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | canonical runtime directions and exact 4/4 gate bound to the unchanged mature-city fixture | one fresh independent final app gate after renderer assembly |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
