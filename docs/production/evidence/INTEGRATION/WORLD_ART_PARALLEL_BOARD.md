# World Art Parallel Workstream Board

- **Parallel operating authority:** `836ae23e8f9e10bd35b75ddd208c13d72c9fa5e9`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-30
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `c9d3e754447d4c87ea4d8123c54baad5259d549f` | static-B v03 clean success returned; independent disposition active |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | zero-pixel A/B/C orchestration prep integrated; wait for post-lock release |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | zero-pixel validation fan-out prep integrated; wait for post-lock release |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | zero-pixel review assembly prep integrated; wait for post-lock release |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `aed682f61d2593209740da0a1fd14577bd445e6c` | L4 intake ready; unrelated R4-A candidate returned for independent review |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | L4 preregistration complete; unrelated L3 gate remains externally blocked |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `05:16Z` refresh, North has returned the single-child static-B v03
result cleanly and Integration is independently reviewing it. East, South,
and West have exhausted every claim-authorized zero-pixel preparation and
remain blocked from pixels until North process A is independently accepted and
Integration publishes the appearance lock, source-production profile, strict
parallel schedule, and per-process launch grants.

North v03 consumed exactly one static-B child and reported exact A/B static
comparison plus bounded wait4/resource evidence at `c9d3e754…`. Process A/B/C
and every East/South/West DCC or pixel process remain closed until that result
is independently disposed and the missing post-lock authorities are published.

Renderer's canonical direction source-admission harness remains ready with
zero live L4 receipts. Its separate R4-A candidate is clean at `aed682f6…` and
under independent review; that work does not count as active Industrial L4
assembly. QA's L4 family preregistration is complete, while the exclusive QA
lane remains occupied by a separate L3 lock-state gate; that L3 work likewise
does not count as active L4 QA.

No row is mislabeled active. The current L4 art stage has exhausted safe
sibling prelock work; its next legal transition is North result disposition
and then one Process-A calibration. Outside this family ledger, published
PLAY-084 UI and PLAY-085 Gameplay work are independently dispatched so overall
delivery remains parallel without weakening the art gate.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
