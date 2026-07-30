# World Art Parallel Workstream Board

- **Parallel operating authority:** `71d19a9259bb0b7c63f76854bd18556056353683`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Head | Next release boundary |
|---|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | `returned` | `507c88b8cf1cdf49c8f5893fe2a6e8a5a92c152e` | static-a bootstrap succeeded; approved integration and next pixel authority pending |
| East | `codex/citysim-world-art-east` / `PLAY-079` | `predesign` | `bcb5cba1495aade19009f4e4407cd55b7bf03c39` | zero-pixel A/B/C orchestration prep integrated; wait for post-lock release |
| South | `codex/citysim-world-art-south` / `PLAY-080` | `predesign` | `d8332051c8665410f90684ba8f034fd2a1846a53` | zero-pixel validation fan-out prep integrated; wait for post-lock release |
| West | `codex/citysim-world-art-west` / `PLAY-081` | `predesign` | `76386c7dba4c3f9b86c6662361cc670ef1e6ed1f` | zero-pixel review assembly prep integrated; wait for post-lock release |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | `intake_ready` | `4a8c118ed11f6ab026a19c5582f390ce6007ff3e` | canonical admission harness returned clean and approved for integration |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | `exact_candidate_active` | `8e68cf11c6a943ab44d83232659585134c17f260` | run one same-SHA `472ffa85…` gate when Computer Use lock check resolves |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

At the `03:50Z` return refresh, Industrial L3 remains integrated at exact candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f`; its complete technical gate is
green and QA owns the sole same-SHA player-facing gate. East, South, and West
zero-pixel execution, validation, and review-assembly preparations are
independently approved and integrated. Renderer has completed the L4 intake
prerequisite audit.

North's replacement module-bootstrap recovery consumed exactly one child and
succeeded at static geometry without a render, pixel, or `.blend` file.
Independent review approved commits `f9230e39…` and `507c88b8…` only as
zero-pixel recovery evidence. A second child, `static-b`, North Process A/B/C,
and every East/South/West DCC or pixel process remain closed until Integration
publishes the next authority.

Renderer returned the canonical direction source-admission harness at
`4a8c118e…`; independent review approved that single nonshipping commit. It
contains zero live receipts and may not consume a real source or activate
shipping. When North later earns an appearance lock, a new release will
schedule all four source cells and their direction-local A/B/C process
fan-outs.

North and Renderer are clean returned candidates awaiting immediate
Integration cherry-picks. QA remains active, externally waiting only on the
Computer Use lock-state approval for the unchanged exact L3 candidate. The
current compute envelope assigns zero DCC slots while Integration performs
these serialized admissions.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
