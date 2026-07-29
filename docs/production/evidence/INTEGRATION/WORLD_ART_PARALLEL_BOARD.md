# World Art Parallel Workstream Board

- **Parallel operating authority:** `e9e9ed38bd2abbd720cce9e337b77547494f6ea8`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Next release boundary |
|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | v09 zero-pixel design passed independent technical and visual review | run exactly one North Process A, re-prove literal appearance, then stop |
| East | `codex/citysim-world-art-east` / `PLAY-079` | clean 59-record locator inventory candidate under review | freeze candidate; compare read-only with proposal-only Renderer assembly fields |
| South | `codex/citysim-world-art-south` / `PLAY-080` | fail-closed repair accepted and exact six-file launch delta published | synchronize published baseline and author South-owned locator inventory |
| West | `codex/citysim-world-art-west` / `PLAY-081` | launch candidate returned: arbitrary report target and in-repo symlink escape | bind exact task output and reject all symlinked A/B/C root components |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | assembler candidate returned: string-prefix root checks permit symlink escape | resolve all input/output paths canonically and prove locator/output symlink rejection |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | clean serialized-acquisition/parallel-analysis execution-plan candidate under review | freeze candidate; inventory post-capture evidence ownership and join dependencies |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `07:10Z` refresh, all six rows had useful bounded work: North, East,
South, West, and QA were active in their visible threads; Renderer had returned
an exact clean candidate, entered independent review, and received read-only
candidate-preserving inventory work. South then failed an independent
fail-closed review and was returned locally without stopping East or West.
Renderer independently failed a symlink-containment edge case and was likewise
returned as one local repair; its useful harness work remains preserved.

The compute envelope now permits exactly one DCC process: North v09 Process A.
North B/C and all East/South/West pixels remain closed. If the real lit North
source earns an appearance lock, the next release will cap DCC execution at two
simultaneous processes unless Integration publishes a measured exception.
Direction-local A/B/C validation jobs may still fan out inside that compute
envelope; a failed direction returns alone.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
