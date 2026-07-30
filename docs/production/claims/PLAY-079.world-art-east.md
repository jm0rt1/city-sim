# PLAY-079 Claim

- **Claim revision:** 5
- **Title:** Predesign the Industrial L4 East source in parallel
- **Lane:** World Art East cell
- **Branch:** `codex/citysim-world-art-east`
- **Worktree:** Integration-provisioned Codex worktree
- **Base authority:** Published master containing CONTRACT-021 and this claim
- **Planned surfaces:** East-only task-owned Blender text scene/tools under
  `Native/CitySimNative/WorldArt/Blender/PLAY-079/` and
  `docs/production/evidence/PLAY-079/`
- **Revision-2 exclusive roots:**
  `Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/`
  and
  `docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/`
- **Dependencies:** CONTRACT-020; CONTRACT-021; published Industrial L4 North
  family requirements
- **Accepted bridge dependency:**
  `3e01ca6738d7574718f9aeff4b66771eee109feb`
- **Status:** Predesign accepted and integrated at `3575d6ac`. Direction-local
  zero-pixel runner and handoff now pass against accepted v06 at candidate
  `22e15b06`; the stale CONTRACT-020 hash is repaired. Pixel rendering remains
  blocked until Integration publishes the exact appearance lock and post-lock
  production authority. While North v08 is redesigned, East may bind its
  zero-pixel runner/handoff to source-stage schema v2 SHA-256
  `93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7`
  and the common
  44-master non-alias input and prove the prelaunch guard fails closed, under
  `INDUSTRIAL-L04-DIRECTION-PRELOCK-REPAIR-AUTHORITY.md`. That preparation is
  complete. The next bounded slice is zero-pixel launch readiness only: adapt
  the East orchestrator to consume and fail closed against the exact
  Integration-published schedule and per-process grant, with adversarial no-DCC
  tests and zero-child evidence under
  `INDUSTRIAL-L04-DIRECTION-SCHEDULE-ADAPTER-AUTHORITY.md`.
- **Validation/proof:** Independent East geometry; East road-facing portal and
  socket; actual-camera footprint/pivot/projection; alpha-free zero-pixel
  occlusion and silhouette proof; no sibling transform or alias

Do not edit accepted East predesign, North, South, West, renderer/shipping,
package, gameplay, simulation, UI, build, claim, or shared-manifest surfaces.
Do not render A/B/C, push, integrate, or self-accept. Do not edit the shared
schema, non-alias input, ledger, or sibling roots.
