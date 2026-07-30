# World Art Parallel Workstream Board

- **Parallel operating authority:** `148b01af73d7a3eab0bc9ebe06e68c3f09f4c62f`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `predesign` | `12bcb1a2c740d30cebdc975c2f0882f63de6b6cf` | returned; Integration must publish an additive launcher/recovery authority |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | finish final audit of zero-pixel A/B/C orchestration preparation |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | finish final audit of zero-pixel validation fan-out preparation |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | integrate the independently approved review-assembly preparation |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `cc3112fee68948d8f723c00810077b6abafb53db` | return the read-only L4 intake-prerequisite audit while L3 stays frozen |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `preregistered` | `8e68cf11c6a943ab44d83232659585134c17f260` | complete only the lock check, then wait for the post-integration candidate SHA |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `01:35Z` refresh, the frozen Industrial L3 candidate has independent
technical approval for narrow replay onto master. Renderer is auditing the
next L4 intake boundary read-only, and QA is performing only the lock-state
check before waiting for the post-integration SHA. East is finishing its
zero-pixel orchestration audit, South has dirty task-owned validation-fan-out
work in progress, and West's clean review-assembly return is independently
approved. North is the only idle row: both audit and independent review agree
that no legal work remains until Integration publishes an additive
launcher/static-a recovery authority.

The compute envelope currently permits zero DCC processes. A new authority
must explicitly reopen a single North diagnostic slot. North Process A/B/C and
all East/South/West DCC or pixel work remain closed. When North later earns an
appearance lock, a new release will schedule the four source cells and their
direction-local A/B/C process fan-outs.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
