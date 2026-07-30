# World Art Parallel Workstream Board

- **Parallel operating authority:** `a2c9bde77233a167d60ae7afa6ea77021d39c92b`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-30
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `c62fb18f8d4fc447e33c68c75a990e4c0687904d` | working on North-A zero-child schedule adapter |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `75fc0aac1f37dafc798c49f23bc8f8e8b1117b2d` | working on East A/B/C zero-child schedule adapter |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `0011a17478b495163df4ca80b0921144de8d694b` | working on South A/B/C zero-child schedule adapter |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `67d915ed3f3818680292546de9e8c656b6b3f15d` | working on West A/B/C zero-child schedule adapter |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `9cc307aca522ada00e291fe254c46cff7de6d81b` | L4 intake remains ready with zero admitted sources |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | L4 preregistration complete; unrelated L3 gate remains externally blocked |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `06:08Z` refresh, North static-B v03 is independently accepted and
integrated. The executable schedule schema, semantic validator, adversarial
tests, and operating authority are published. North, East, South, and West
have all acknowledged direction-local zero-child schedule-adapter work
concurrently. West correctly stopped on a newer published master, received an
adjusted exact authority, and then merged it cleanly before starting.

This wave makes each high-level orchestrator consume an exact signed process
grant and proves blocked grants start zero children. It creates no pixels.
North Process A remains closed until its adapter returns and Integration
publishes a validator-passing `prelock_north_a` schedule. Sibling A/B/C remain
closed until North A passes independent appearance review and Integration
publishes the appearance lock, source profile, and `postlock_abc` schedule.

Renderer's canonical direction source-admission harness remains ready with
zero live L4 receipts. Its separate R4-A candidate is clean at `aed682f6…` and
under independent review; that work does not count as active Industrial L4
assembly. QA's L4 family preregistration is complete, while the exclusive QA
lane remains occupied by a separate L3 lock-state gate; that L3 work likewise
does not count as active L4 QA.

No unrelated Renderer or QA work is counted as an active L4 source. The art
lane now has four independently owned workstreams preparing their exact launch
boundary in parallel; a failed direction adapter returns only that direction.
Outside this family ledger, published PLAY-084 UI and PLAY-085 Gameplay work
remain independently active.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
