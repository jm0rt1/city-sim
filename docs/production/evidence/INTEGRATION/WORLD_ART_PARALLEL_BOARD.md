# World Art Parallel Workstream Board

- **Parallel operating authority:** `346a27240668d97f0e89b7a9d4be00f9ed6e8239`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-29
- **Machine-readable ledger:**
  `WORLD_ART_PARALLEL_BATCH_LEDGER.json`
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Next release boundary |
|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | v07 A preserved as technical-pass / `RETURNED_APPEARANCE_GATE`; v08 zero-pixel/material redesign released | return stronger v08 pre-pixel packet; no source render |
| East | `codex/citysim-world-art-east` / `PLAY-079` | v06 zero-pixel runner passes; shared source-schema/non-alias binding released | fail-closed launch-bound packet, no pixels |
| South | `codex/citysim-world-art-south` / `PLAY-080` | v06 proof accepted; fingerprint and literal-192 runner repairs released | corrected zero-pixel runner and launch-bound packet |
| West | `codex/citysim-world-art-west` / `PLAY-081` | v06 proof accepted; ancestry and stdlib PNG validation repairs released | corrected zero-pixel runner and launch-bound packet |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | file-backed preparation returned because JSONDecoder accepted unknown schema fields; strict shape repair acknowledged | reject unknown top-level/nested fields, rerun focused gates |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | materializer preparation returned because a synthetic mode flip could declare eligibility; admission-manifest repair acknowledged | reject unverified candidate/packet identities, rerun receipt gates |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
