# World Art Parallel Workstream Board

- **Parallel operating authority:** `346a27240668d97f0e89b7a9d4be00f9ed6e8239`
- **Batch:** Industrial L4 directional family
- **Updated:** 2026-07-28
- **Production rule:** direction work is independent; production selection and
  shipping activation require four accepted exact sources.

| Cell | Branch / claim | Current state | Next release boundary |
|---|---|---|---|
| North | `codex/citysim-world-art` / `PLAY-027` | Integration review found v04/v05 relied on a permuted Blender bridge and wrong North world edge; v06 zero-pixel coordinate repair authorized at `a9647422` | accepted four-direction bridge releases a corrected North architecture authority; no A yet |
| East | `codex/citysim-world-art-east` / `PLAY-079` | predesign geometry retained; hard-guarded runner active, but its projection must adopt the accepted v06 bridge before A/B/C | bridge revalidation plus appearance lock releases A/B/C |
| South | `codex/citysim-world-art-south` / `PLAY-080` | predesign geometry retained; hard-guarded runner active, but its projection must adopt the accepted v06 bridge before A/B/C | bridge revalidation plus appearance lock releases A/B/C |
| West | `codex/citysim-world-art-west` / `PLAY-081` | predesign geometry retained; hard-guarded runner active, but its projection must adopt the accepted v06 bridge before A/B/C | bridge revalidation plus appearance lock releases A/B/C |
| Renderer | `codex/citysim-world-rendering` / `PLAY-073` | fail-closed L4 intake is ready; non-shipping per-direction packet validation and 0–4 mutation matrix authorized/dispatched | quarantine each accepted direction; activate only after exact 4/4 |
| QA | `codex/citysim-playtest-quality` / `PLAY-075` | deterministic mature-city directional fixture and atomic L4 rubric are published on master at `184e6e5b`; live rehearsal remains deferred while the Mac is locked | one fresh independent final app gate after renderer assembly |

## Dispatch invariant

Integration refreshes this board at dispatch, candidate return, family-lock, and
integration boundaries. A waiting cell receives non-conflicting preparation,
validation, fixture, audit, or evidence work. A failed East, South, or West
source returns only that direction; it does not stop accepted siblings.

The following remain serialized: family-contract publication, shared toolchain
changes, shipping atlas/manifest mutation, production selection, the final
exact-candidate QA gate, integration, and push.
