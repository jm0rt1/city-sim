# World Art Parallel Workstream Board

- **Parallel operating authority:** `7e21babafb5aa491894136c7f1c1d4c58444ef31`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-30
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `cc51161cc7b21540025730bc77645f48c794539d` | schedule adapter accepted; working on zero-child Process-A orchestrator prelaunch |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `6524934f764862768bce7d27eccffb279604b55f` | zero-child A/B/C schedule adapter accepted and integrated |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `092d7b5938125f66c24bf0a759825da195baea04` | real post-lock CLI adapter repaired, accepted, and integrated |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `0d18aae990d5691d89e02426dc50e36262d4efb1` | zero-child A/B/C schedule adapter accepted and integrated |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `9cc307aca522ada00e291fe254c46cff7de6d81b` | L4 intake remains ready with zero admitted sources |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | L4 preregistration complete; unrelated L3 gate remains externally blocked |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `06:43Z` refresh, all four direction-local schedule adapters are
independently accepted and integrated. East and West passed on their first
independent reviews. North repaired fresh-root evidence determinism; South
repaired a real-CLI post-lock contradiction that synthetic tests had hidden.

Every blocked grant starts zero children and no adapter exposes a low-level
DCC bypass. North has been refilled immediately with the next zero-child slice:
author the real high-level Process-A orchestrator and Blender entrypoint for
independent prelaunch review. North Process A remains closed until that review,
a validator-passing `prelock_north_a` schedule, and a separate one-process
authority. Sibling A/B/C remain closed until North A passes appearance review
and Integration publishes the lock, source profile, and `postlock_abc`
schedule.

Renderer's canonical direction source-admission harness remains ready with
zero live L4 receipts. Its separate R4-A candidate is clean at `aed682f6…` and
under independent review; that work does not count as active Industrial L4
assembly. QA's L4 family preregistration is complete, while the exclusive QA
lane remains occupied by a separate L3 lock-state gate; that L3 work likewise
does not count as active L4 QA.

No unrelated Renderer or QA work is counted as an active L4 source. The three
completed sibling cells retain accepted independent launch boundaries while
North advances the design-calibration path. A returned cell was repaired
without canceling or invalidating successful siblings. Outside this family
ledger, published PLAY-084 UI and PLAY-085 Gameplay work remain independently
active.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
