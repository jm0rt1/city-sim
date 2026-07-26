# PLAY-027 Industrial L2 East V06 metadata compatibility

Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`

East v06 is a metadata-only compatibility revision of immutable East v05.
It changes only the revision/binding plus the four integration-approved,
same-role reference classes:

- `entrance.pavilionMaterialID`: `v02-painted-steel` to `v05-hall-metal`
- `building.chimney.materialID`: `v04-process-metal` to `v05-process-metal`
- east facade material: `v04-corrugated-hall` to `v05-hall-metal`
- north/south/west facade material: `v04-formed-concrete` to `v05-admin-concrete`

All referenced material IDs now resolve in the immutable East v05 material
library. Production `SceneDescriptor` decode and schema-2 sampling resolution
pass.

`building.usesExplicitComponentGeometry` is true. The governed
`ContractSceneBuilder` skips chimney construction at
`OfflineSceneRenderer.swift:640-642` and skips facade/window and entrance
construction at `OfflineSceneRenderer.swift:644-674`. The identity proof
therefore compares the actual explicit-component render-consumed subset:
foundation, mass blocks, roof volumes, trim bands, props, camera, light,
registration, material-library reference, and sampling with only its revision
binding removed. Its hash is unchanged:
`ac0b1b2a5d674bc22404474a6be3dd2672a3a69f5ce81c13a163488402969d91`.

The East v05 material library, canonical geometry, scene-node/material inputs,
raw, provenance, both normalized runs, and all review panels remain unchanged.
No rerender is required because none of the repaired metadata is consumed by
the explicit-component scene path.

Exact anchors:

- East v05 descriptor: `482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0`
- East v06 descriptor: `a7732ba762b4569b50a1dc19291d42b2c4030cf21509a242caad49eea339b517`
- East v05 material library: `6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb`
- East v05 canonical geometry: `6c727c4b7053d69578e97c2f73cf3054cd2dda106bf06625e0dac12a356798fb`
- East v05 raw: `a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8`
- East v05 raw provenance: `c67e61224957890199a745f292327a6fd2f75739492af0a3d74d3d19e24c7f27`
- Renderer source: `b712784c25bff79d3032755f4dde6e251ebee9a7bc7250361e0c7deea483f5b0`

Process counts for this checkpoint are zero SceneKit, zero Metal snapshots,
zero raw pixels, and zero normalizer processes. `sourceAuthority=false` and
`productionSelected=false`. North/West pixels remain blocked pending
integration review of this checkpoint.
