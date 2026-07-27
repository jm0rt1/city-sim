# PLAY-027 Industrial L4 Turbine v08 North capability rejection

Disposition: `REJECTED_PRE_PIXEL_CAPABILITY`

The exact accepted North descriptor cannot enter the governed renderer at the
published merge checkpoint. The failure occurs in
`DescriptorSamplingResolver.resolve` before backend capability inspection,
SceneKit preparation, Metal rendering, or pixel output.

## Frozen authority and inputs

- merge checkpoint:
  `b48357f70f4d10bb76e978c5c823c1cf7959b867`;
- accepted pre-pixel ancestor:
  `58bdac23653389ad62603f9e2567bd65430fd7ed`;
- published authority ancestor:
  `48823cb7e3f709a2c3c9a3bff190b2e2a384f0b9`;
- North descriptor SHA-256:
  `9f812479746ba031335aad53f89d562e1f03de0b868b5b533bf43007eb4a9472`;
- material library SHA-256:
  `f8cf1d4ff9ab4446ec562fe949dd09c45399a32d9a763f7d6dd6380b66e52b94`;
- compiled renderer binary SHA-256:
  `f9f196c1df60bace84d41760bd4057c6ce53c6c619c17b88e07fb39952dfe5a9`;
- `RendererArchitecture.swift` SHA-256:
  `ef6e0a5a808c9b4e716e378ae39149458a44befbbb022c2e817de6b59628130e`;
- `OfflineSceneRenderer.swift` SHA-256:
  `4c1335e7dca44774280e678b9ff21d0c58550a2a19d112871a0c8fddf67e8e2f`.

The exact renderer compiled with `-warnings-as-errors`. One fail-closed
invocation was attempted with the accepted descriptor and material library:

```text
/tmp/play027-l4-v08-north-raw-build/offline-scene-renderer \
  --repository-root /Users/James/.codex/worktrees/0648/city-sim \
  --scene /Users/James/.codex/worktrees/0648/city-sim/Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v08-prepixel/scenes/industrial_l04/variant-0/n/scene.json \
  --materials /Users/James/.codex/worktrees/0648/city-sim/Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l04-turbine-v08-prepixel/materials/industrial-l04-turbine-v08-prepixel.json \
  --output /Users/James/.codex/worktrees/0648/city-sim/docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-raw-v01/diagnostics/raw-repeat/north/run-a/raw.png \
  --record /Users/James/.codex/worktrees/0648/city-sim/docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-raw-v01/diagnostics/raw-repeat/north/run-a/provenance.json \
  --backend-capability-record /Users/James/.codex/worktrees/0648/city-sim/docs/production/evidence/PLAY-027/industrial-l04/l04/turbine-v08-north-raw-v01/diagnostics/raw-repeat/north/run-a/backend-capability.json \
  --renderer-source-commit b48357f70f4d10bb76e978c5c823c1cf7959b867
```

It exited `133` with the exact error:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level: SceneKit shadows may be disabled only by the enumerated Industrial L2 revisions or Industrial L3 source-v02/source-v03/source-v04 N/E/S/W and exact source-v05/source-v06 North/West v3 source-authority descriptors
```

## Stop boundary

The accepted v08 descriptor requires `sceneKitShadows=disabled` and
`sceneKitLightingMode=authored-constant-v1`, but the merged resolver does not
enumerate Industrial L4. The raw authority forbids renderer mutation, so no
resolver change was made.

No raw PNG, provenance JSON, or backend capability JSON exists. No SceneKit or
Metal process ran and the raw pixel count is zero. North run B/C, identity
checks, semantic-visibility checks, and review-panel generation remain unrun.
No East, South, West, normalization, product, shipping, package, shared
manifest, or production-selection surface was touched.

`sourceAuthority=false`; `productionSelected=false`.
