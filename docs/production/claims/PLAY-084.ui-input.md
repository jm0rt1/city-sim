# PLAY-084 Claim

- **Title:** Make consequences land in the HUD
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** Next published clean Integration commit containing this
  claim
- **Planned surfaces:**
  `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`,
  one new focused HUD test file, `docs/production/evidence/PLAY-084/`, and
  `docs/production/completed/PLAY-084.ui-input.md`
- **Dependencies:** PLAY-082 product/evidence frozen on master through
  `89340edce77c3e2014012b2c1cf898f393cc37e4`
- **Validation/proof:** Signed/coalesced metric presentation; current-value
  primacy; accessibility and Reduced Motion equivalence; exact HUD height and
  aperture; regular/compact pointer and keyboard journeys; complete native
  suite; staged verify
- **Status:** Ready for dispatch after exact published-baseline synchronization

Use only existing authoritative `CityGameStore` state and analytics. Add no
public/store/command/simulation truth. A material value change may produce one
brief, directionally truthful acknowledgement, but ordinary zero, formatting,
or repeated tick noise must not flash continuously or accumulate stale deltas.
Current values remain visually and accessibly primary.

Reduced Motion must retain signed/static meaning without scale, travel, or
repeated opacity animation. Preserve every existing metric action, focus rule,
accessibility identifier, Strategy Command Center action, compact composition,
and the 118/104-point HUD height limits.

Do not edit `BuildToolbarView`, `ContentView`, stores, commands, objectives,
alerts, shared theme tokens, SpriteKit, gameplay/simulation/persistence,
package/build files, other claims, art, or legacy Python. Stop on any contract
need, compact-height growth, map-aperture loss, continuous ticking feedback,
or color/motion-only meaning. Commit coherent product, test, evidence, and
completion outcomes separately. Do not push, integrate, pin, self-score, or
self-accept.
