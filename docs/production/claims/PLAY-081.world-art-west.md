# PLAY-081 Claim

- **Title:** Predesign the Industrial L4 West source in parallel
- **Lane:** World Art West cell
- **Branch:** `codex/citysim-world-art-west`
- **Worktree:** Integration-provisioned Codex worktree
- **Base authority:** Published master containing CONTRACT-021 and this claim
- **Planned surfaces:** West-only task-owned Blender text scene/tools under
  `Native/CitySimNative/WorldArt/Blender/PLAY-081/` and
  `docs/production/evidence/PLAY-081/`
- **Dependencies:** CONTRACT-020; CONTRACT-021; published Industrial L4 North
  family requirements
- **Status:** Predesign accepted and integrated at `8a889f2a`; pixel rendering
  remains blocked until Integration accepts North, publishes the
  family/material lock, and issues a new production authority
- **Validation/proof:** Independent West geometry; West road-facing portal and
  socket; actual-camera footprint/pivot/projection; alpha-free zero-pixel
  occlusion and silhouette proof; no sibling transform or alias

Do not edit North, East, South, renderer/shipping, package, gameplay,
simulation, UI, build, or shared-manifest surfaces. Do not render A, push,
integrate, or self-accept.
