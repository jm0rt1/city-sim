# World Art Parallel Workstream Board

- **Parallel operating authority:** `9d8e3e776eecbfb518d08d18085180ae084a6929`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `94ae73a99abe64f59bb052582fcaba1d9725319d` | sync to published authority and execute the pure lowering plus static-a/static-b no-render proofs |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `aa5f885dd579bf79b8a84855a23311ee888e7001` | repair receipt replay, immutable capture, and truthful master/East branch provenance |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d12b5f1c8383044d5f1ab67ccd2b9be2bce92b75` | bind exact authorities, confine outputs, refuse overwrite, and add path-substitution adversaries |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `9d8e3e776eecbfb518d08d18085180ae084a6929` | author a non-rewriting current-master successor zero-pixel handoff |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `94ae73a99abe64f59bb052582fcaba1d9725319d` | resume when Integration publishes canonical admission-receipt and assembly-manifest schemas |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | start the one fresh gate only on an exact atomic 4/4 renderer candidate |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `00:49Z` refresh, Integration has published North's independently
approved lowering authority and West's independently approved isolation
checkpoint. East and South were returned independently for replay-safety
defects and have acknowledged direction-local repairs; neither return blocks
the accepted West checkpoint. West has been preserved and re-provisioned on
the published master and has acknowledged its versioned successor handoff.
North is planned for
the one legal static-DCC slot. Renderer is truthfully blocked only on two
Integration-owned canonical schemas; QA remains preregistered and waits for an
exact atomic 4/4 candidate. No row may edit sibling art or shared shipping
files. None of these tasks authorizes source pixels, admission, runtime
activation, or candidate scoring.

The compute envelope permits exactly one North static Blender process at a
time: `static-a` must finish and be committed before `static-b`. Both are
no-render, zero-pixel imports. North Process A/B/C and all East/South/West DCC
or pixel work remain closed. When North later earns an appearance lock, a new
release will explicitly schedule the four source cells.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
