# World Art Parallel Workstream Board

- **Parallel operating authority:** `03f320554951ef79bb8e200c844b3ad168fb3d10`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `returned` | `56e4f484ac07ca3fcf11e72f69a7fb56170d9792` | v01 module-import failure retained; v02 one-start module bootstrap sent |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | zero-pixel A/B/C orchestration prep integrated; wait for post-lock release |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | zero-pixel validation fan-out prep integrated; wait for post-lock release |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | zero-pixel review assembly prep integrated; wait for post-lock release |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `cc3112fee68948d8f723c00810077b6abafb53db` | canonical admission schema published; synthetic intake-harness adoption sent |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `exact_candidate_active` | `8e68cf11c6a943ab44d83232659585134c17f260` | run one same-SHA `472ffa85…` gate when Computer Use lock check resolves |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `03:09Z` refresh, Industrial L3 is integrated at exact candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f`; its complete technical gate is
green and QA owns the sole same-SHA player-facing gate. East, South, and West
zero-pixel execution, validation, and review-assembly preparations are
independently approved and integrated. Renderer has completed the L4 intake
prerequisite audit.

North's first recovery consumed its only child and failed before geometry
because Blender did not put the frozen importer directory on `sys.path`. The
failure is integrated and independently accepted as diagnostic evidence. The
compute envelope now opens exactly one replacement North diagnostic slot for
`industrial-l04-north-v12-static-a-module-bootstrap-recovery-v02`,
process `static-a`, under authority commit
`03f320554951ef79bb8e200c844b3ad168fb3d10`. A child start consumes the
slot. A second child, `static-b`, North Process A/B/C, and every
East/South/West DCC or pixel process remain closed.

Integration has also published the canonical direction source-admission
schema and executable validator with zero live receipts. Renderer is released
in parallel to adopt that exact receipt shape in its synthetic intake harness;
it may not consume a real source or activate shipping. When North later earns
an appearance lock, a new release will schedule all four source cells and
their direction-local A/B/C process fan-outs.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
