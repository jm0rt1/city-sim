# World Art Parallel Workstream Board

- **Parallel operating authority:** `73300af6f2ae6e31c4f818c078f82cc73ce4c70b`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `e49e52f6a899fcdd1d12a85426cac5343cf82bb6` | corrected static-b v02 acknowledged; two-pointer prelaunch is the first bounded deliverable |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | zero-pixel A/B/C orchestration prep integrated; wait for post-lock release |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | zero-pixel validation fan-out prep integrated; wait for post-lock release |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | zero-pixel review assembly prep integrated; wait for post-lock release |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `0ad167ae3b9c709ac17165d7bdce8a5388467523` | R4-A pixel baseline frozen; renderer-only authored-opening iteration active |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `exact_candidate_active` | `8e68cf11c6a943ab44d83232659585134c17f260` | run one same-SHA `472ffa85…` gate when Computer Use lock check resolves |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `04:16Z` acknowledgement refresh, Industrial L3 remains integrated at exact candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f`; its complete technical gate is
green and QA owns the sole same-SHA player-facing gate. East, South, and West
zero-pixel execution, validation, and review-assembly preparations are
independently approved and integrated. Renderer has completed the L4 intake
prerequisite audit.

North correctly returned v01 before mutation because its INPUT-BINDINGS
byte-identity rule conflicted with the required new claim and contract hashes.
Corrected authority `73300af6…` now leases exactly one `static-b` child after
a committed v02 prelaunch. Five run-neutral files must be byte-identical;
INPUT-BINDINGS permits exactly the claim and contract hash pointers to differ.
Process A/B/C and every East/South/West DCC or pixel process remain closed.

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
