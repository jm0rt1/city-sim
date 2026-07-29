# World Art Parallel Workstream Board

- **Parallel operating authority:** `346a27240668d97f0e89b7a9d4be00f9ed6e8239`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-28
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Next release boundary |
|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | v04 zero-pixel proof `84be90eb` correctly stopped an impossible `+X` portal to `X = -28` socket path; v05 socket-facing portal relocation authorized | zero-pixel proof, then one A-only review publishes the appearance lock or returns North only |
| East | `codex/citysim-world-art-east` / `PLAY-079` | zero-pixel predesign integrated at `3575d6ac`; source pixels remain blocked | A/B/C begins immediately after the appearance lock |
| South | `codex/citysim-world-art-south` / `PLAY-080` | zero-pixel predesign integrated at `d9842279`; source pixels remain blocked | A/B/C begins immediately after the appearance lock |
| West | `codex/citysim-world-art-west` / `PLAY-081` | zero-pixel predesign integrated at `8a889f2a`; source pixels remain blocked | A/B/C begins immediately after the appearance lock |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | fail-closed L4 intake is ready; external fixture intake `cdcd1e92` passes on the R2 candidate but is explicitly candidate-bound and not master-adoptable alone | quarantine each accepted direction; activate only after exact 4/4 |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | deterministic mature-city directional fixture and atomic L4 rubric are published on master at `184e6e5b`; live rehearsal remains deferred while the Mac is locked | one fresh independent final app gate after renderer assembly |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
