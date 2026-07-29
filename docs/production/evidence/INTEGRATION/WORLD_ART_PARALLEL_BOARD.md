# World Art Parallel Workstream Board

- **Parallel operating authority:** `1b0d1a0b760ee1a7e9a76123d0c011d638ac993d`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `returned` | `4255b021f743281b60cfdf8cff896235d405be23` | read-only v07/v08/v09 causal comparison and smallest v10 zero-pixel repair authority proposal |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `08817608f59e02a1b7bde9e67cd6486c46a91635` | read-only portability disposition and exact import sequence |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `779cf5141a4735d6b7c84a0372f08c9ab111d358` | read-only proof that the repair is Integration-portable |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `returned` | `0bc3bda9527e8cf53174e96d369c0ae013168093` | read-only path-safety disposition and portable commit sequence |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `270eb7515c1cc950f3bfe4b6687fd3ee788122c3` | smallest remaining prelock intake-ahead claim proposal |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `00ed0a68965199e3eb82129f1a16b41e95d7ba08` | read-only portability and baseline-rehearsal completeness disposition |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `08:35Z` refresh, all six clean exact worktrees acknowledged useful
bounded work. North is producing the read-only causal record needed for a
narrow v10 authority. East, South, and West are independently proving their
frozen candidates portable or returning a precise local defect. Renderer is
identifying the next nonshipping intake-ahead gap after its accepted harness
landed on `master`. QA is independently proving that its candidate-neutral
preflight is portable and complete. None of these reviews authorizes pixels,
source admission, runtime activation, or scoring.

The compute envelope currently permits zero DCC processes because North v09
Process A is rejected and no v10 or appearance-lock authority exists. North
B/C and all East/South/West pixels remain closed. When a repaired North source
earns an appearance lock, the next release will cap DCC execution at two
simultaneous processes unless Integration publishes a measured exception.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
