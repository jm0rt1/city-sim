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
| North | `codex/citysim-world-art` / `PLAY-027` | v06 global coordinate bridge accepted from `3e01ca67`; corrected North zero-pixel architecture is released | independent appearance review releases North B/C and sibling A/B/C |
| East | `codex/citysim-world-art-east` / `PLAY-079` | runner integrated, but independent replay found a stale CONTRACT-020 hash; v06 adoption and narrow hash refresh dispatched | passing bridge replay plus appearance lock releases A/B/C |
| South | `codex/citysim-world-art-south` / `PLAY-080` | runner independently passes; v06 adoption and bridge replay released | passing bridge replay plus appearance lock releases A/B/C |
| West | `codex/citysim-world-art-west` / `PLAY-081` | runner and handoff independently pass; v06 adoption and bridge replay released | passing bridge replay plus appearance lock releases A/B/C |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | fail-closed packet schema and 0–4 quarantine matrix accepted; focused Integration replay passes 7/7 | quarantine each accepted direction; activate only after exact 4/4 |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | deterministic mature-city directional fixture and atomic L4 rubric are published on master at `184e6e5b`; live rehearsal remains deferred while the Mac is locked | one fresh independent final app gate after renderer assembly |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
