# World Art Parallel Workstream Board

- **Parallel operating authority:** `dae73ec40d48376aa74a1041e86fc1047ecac539`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `3e5d418b6c805f3a68410be93c77afb7e3d26194` | static-b confirmation acknowledged; prelaunch is the first bounded deliverable |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | zero-pixel A/B/C orchestration prep integrated; wait for post-lock release |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | zero-pixel validation fan-out prep integrated; wait for post-lock release |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | zero-pixel review assembly prep integrated; wait for post-lock release |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `b69a9b7c83156ebdd9d0d126198942becdacafc3` | R4-A acknowledged; authentic-opening measurement freeze active |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `exact_candidate_active` | `8e68cf11c6a943ab44d83232659585134c17f260` | run one same-SHA `472ffa85…` gate when Computer Use lock check resolves |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `04:03Z` acknowledgement refresh, Industrial L3 remains integrated at exact candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f`; its complete technical gate is
green and QA owns the sole same-SHA player-facing gate. East, South, and West
zero-pixel execution, validation, and review-assembly preparations are
independently approved and integrated. Renderer has completed the L4 intake
prerequisite audit.

North's replacement module-bootstrap recovery is integrated. Authority
`dae73ec4…` now leases exactly one `static-b` child after a committed prelaunch
checkpoint. The six run-neutral A/B files must be byte-identical. Process A/B/C
and every East/South/West DCC or pixel process remain closed.

Renderer's canonical direction source-admission harness is integrated.
Renderer has acknowledged the parallel R4-A authored-opening slice and is
freezing exact regular/compact rendered-pixel baseline masks before product
mutation. It may use only worktree-local artifacts while the L3 same-SHA QA
gate remains open and may not consume a live L4 source or activate shipping.

North, Renderer, and QA are three acknowledged disjoint workstreams. QA remains
externally waiting only on the Computer Use lock-state approval for the
unchanged exact L3 candidate. The compute envelope assigns one exclusive
North `static-b` DCC slot; Renderer is CPU/worktree-local and QA may continue
without DCC overlap.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
