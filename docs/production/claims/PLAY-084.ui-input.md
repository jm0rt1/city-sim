# PLAY-084 Claim

- **Title:** Make consequences land in the HUD
- **Lane:** UI and input
- **Owner:** Agent 301 — UI and Input Lead
- **Owning task:** `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-input-game014-currentcc21`
- **Worktree:** `/Users/James/.codex/worktrees/7f1d/city-sim`
- **Governance baseline:** `8f538aeb0ddc8873252d4d6ba6191125143c509a`;
  execution begins only from the protected fast-forwarded claim-bearing commit
- **Accepted product candidate:** `4b57e43c4e2329a7d83b97494ea9e9942ba69814`
- **Planned surfaces:**
  `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/HUDConsequenceFeedbackTests.swift`,
  `docs/production/evidence/PLAY-084/`, and
  `docs/production/completed/PLAY-084.ui-input.md`
- **Dependencies:** PLAY-082 product/evidence frozen on master through
  `89340edce77c3e2014012b2c1cf898f393cc37e4`
- **Validation/proof:** Signed/coalesced metric presentation; current-value
  primacy; accessibility and Reduced Motion equivalence; exact HUD height and
  aperture; regular/compact pointer and keyboard journeys; complete native
  suite; staged verify
- **Status:** Ready for a validated schema-2 outcome lease after an exact
  collision-free protected fast-forward to the claim-bearing authority commit

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
or color/motion-only meaning. The outcome lease may inspect, implement,
focused-test, stage only actual changed allowed paths, and create one coherent
`PLAY-084:` commit in the same task. Do not run the aggregate suite, stage the
app, launch QA, push, integrate, pin, self-score, or self-accept.
