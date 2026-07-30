# PLAY-079 Claim

- **Claim revision:** 6
- **Title:** Close the Industrial L4 East execution boundary in parallel
- **Lane:** World Art East cell
- **Branch:** `codex/citysim-world-art-east`
- **Worktree:** `/Users/James/.codex/worktrees/92c2/city-sim`
- **Base authority:** Published master containing execution-closure authority
  commit `f609460f0b8fffa3d4db2ee2b5b1b3396be85244` and this claim
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
  Current-master replay is clean at
  `edc1741456cd1b32781d10b491a55b5a2d0cae18` and proves the adapter still
  stops at `future_integration_validator_interface_not_published`. Revision 6
  authorizes zero-DCC execution closure only.
- **Validation/proof:** Independent East geometry; East road-facing portal and
  socket; actual-camera footprint/pivot/projection; alpha-free zero-pixel
  occlusion and silhouette proof; no sibling transform or alias

Do not edit accepted East predesign, North, South, West, renderer/shipping,
package, gameplay, simulation, UI, build, claim, or shared-manifest surfaces.
Do not render A/B/C, push, integrate, or self-accept. Do not edit the shared
schema, non-alias input, ledger, or sibling roots.

## Revision-6 execution-closure authority

Consume read-only:

- schema SHA-256
  `2796e224780c259b29d68b50cb12cdbbe45452535da681bba3522af920459491`;
- validator SHA-256
  `b212d2776d34b3334910c6b0b02ffba244919f4a83d5c0019c30bca87648d8ae`;
- authority SHA-256
  `0125539f015ab8069c11093e755ac6e43d7b37994c86515fc06894e401b7eb54`.

Own only the East schedule-consumer contract/consumer/tests,
`orchestrate_parallel_source.py`, `run_production.py`, `RUNNER-CONTRACT.json`,
and East-exclusive closure evidence inside the existing revision-2 exclusive
roots. Bind the exact trusted-master schedule and authenticated one-attempt
authority through the high-level orchestrator to the runner's validation-only
boundary.

Missing, stale, non-ancestral, replayed, forged, wrong-direction,
wrong-process, wrong-root, wrong-slot, wrong-claim, wrong-base,
wrong-orchestrator, direct-runner, or unauthenticated inputs must start zero
children. Stop after one clean deterministic zero-DCC closure packet. This
claim authorizes no live lease, child, Blender/DCC, render, pixel,
normalization, source packet, admission, quarantine, selection, shipping,
push, integration, or self-acceptance.
