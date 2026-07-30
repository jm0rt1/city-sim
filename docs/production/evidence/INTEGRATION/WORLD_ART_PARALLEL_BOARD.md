# World Art Parallel Workstream Board

- **Parallel operating authority:** `270c5ad30c001dbaa9ebc9beceacf19744a2f409`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `68c98430536850aa0319884a914589075fabf5e2` | authority acknowledged and merged; recovery prelaunch implementation active |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | zero-pixel A/B/C orchestration prep integrated; wait for post-lock release |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | zero-pixel validation fan-out prep integrated; wait for post-lock release |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | zero-pixel review assembly prep integrated; wait for post-lock release |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `cc3112fee68948d8f723c00810077b6abafb53db` | L4 intake audit complete; wait for L3 QA and Integration admission schema |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `exact_candidate_active` | `8e68cf11c6a943ab44d83232659585134c17f260` | run one same-SHA `472ffa85…` gate when Computer Use lock check resolves |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `02:33Z` refresh, Industrial L3 is integrated at exact candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f`; its complete technical gate is
green and QA owns the sole same-SHA player-facing gate. East, South, and West
zero-pixel execution, validation, and review-assembly preparations are
independently approved and integrated. Renderer has completed the L4 intake
prerequisite audit.

North has acknowledged and merged the published authority without conflict.
The compute envelope opens exactly one North diagnostic slot for attempt
`industrial-l04-north-v12-static-a-recovery-v01`, process `static-a`, under
authority commit `10b0dacf1440b1c7a351e99cca29ac95e62e40c4`. A child start
consumes the slot. A second recovery child, `static-b`, North Process A/B/C,
and every East/South/West DCC or pixel process remain closed. When North later
earns an appearance lock, a new release will schedule all four source cells
and their direction-local A/B/C process fan-outs.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
