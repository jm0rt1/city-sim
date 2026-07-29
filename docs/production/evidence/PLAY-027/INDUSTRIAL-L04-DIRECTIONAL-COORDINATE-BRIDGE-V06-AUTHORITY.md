# Industrial L4 directional coordinate bridge v06 authority

**Returned v05 candidate:** `b8f85934563376727be70fee34fcf88c780b5d9f`

**Integrated v05 evidence commit:** `037a1f51`

**Disposition:** `AUTHORIZED_ZERO_PIXEL_COORDINATE_BRIDGE_REPAIR`

The v04/v05 proofs were internally deterministic but conflated CitySim world
coordinates with Blender-native coordinates. They projected the correct
source-space socket `[896,704]` from Blender-native `[-28,0,0]` while naming
that point CitySim `[-28,0,0]`, and masked the mismatch by permuting canonical
contact corners with `[0,3,2,1]`.

Canonical CitySim descriptors define North as the `z = -28` edge:

- North facade `[-28, -28] → [28, -28]`;
- North entrance base `[0, -28]`;
- renderer outward normal `[0, 0, -1]`;
- unpermuted footprint source polygon
  `[768,640] → [1024,768] → [768,896] → [512,768]`;
- North source socket `[896,704]`.

The frozen camera and source-space registration are coherent. Do not move the
camera, footprint, pivot, source socket, or canonical runtime direction. Repair
the Blender coordinate bridge and proof before authoring another North
building.

## Superseded clauses

The following world-space clauses are no longer operative:

- v04/v05 North socket `X = -28`;
- v05 portal outward normal `-X`;
- v04's legal-court half-plane derived from that socket;
- any conclusion that a source-space registration pass validates the
  `[0,3,2,1]` world-corner permutation.

V04/v05 source, proof, and rejection packets remain immutable evidence. Their
authority files receive only an Integration supersession annotation. They are
not source authority and do not authorize pixels.

## Authorized v06 roots

World Art may add only:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/`;
- `docs/production/evidence/PLAY-027/industrial-l04/l04/direction-bridge-v06/`.

Do not modify earlier calibration scripts, accepted art, sibling predesigns,
renderer/runtime/shipping resources, shared manifests, packages, or build
scripts.

## Canonical bridge contract

Expand descriptor contact-polygon pairs `[x,z]` to CitySim `[x,0,z]`. Apply
one documented global CitySim-to-Blender basis consistently to components,
dimensions, camera position/target, normals, lights, sockets, footprint
points, and shadows.

The candidate basis is:

```text
B(CitySim[x,y,z]) = Blender[z,x,y]
```

It must pass the complete proof below before acceptance. Do not silently
substitute another basis. A single audited global basis conversion is allowed;
per-direction/per-sibling rotation, reflection, winding change, or hidden
`[0,3,2,1]` reorder is forbidden.

The zero-pixel proof must bind:

| Direction | CitySim socket | Candidate Blender-native socket | Source socket | CitySim outward |
|---|---|---|---|---|
| North | `[0,0,-28]` | `[-28,0,0]` | `[896,704]` | `[0,0,-1]` |
| East | `[28,0,0]` | `[0,28,0]` | `[896,832]` | `[1,0,0]` |
| South | `[0,0,28]` | `[28,0,0]` | `[640,832]` | `[0,0,1]` |
| West | `[-28,0,0]` | `[0,-28,0]` | `[640,704]` | `[-1,0,0]` |

Using the frozen camera, prove:

1. all four unpermuted world corners project to the four frozen source corners
   in the exact descriptor order within `0.001` source pixel;
2. the world origin projects to the frozen source ground center;
3. canonical CitySim pivot `[28,0,28]`, converted by the same global basis to
   Blender-native `[28,28,0]`, projects to `[768,896]`;
4. each world socket is the midpoint of its canonical world edge and projects
   to its exact source socket;
5. each frontage edge projects to its exact frozen source edge;
6. camera position `[96,101.24557426726288,96]`, target
   `[0,22.861902498201186,0]`, direction normals, lights, edge tangents,
   handedness, and winding all use the same global basis;
7. two fresh `--factory-startup` processes produce byte-identical
   machine-readable proof; and
8. no `bpy.ops.render.render`, output image, ImageGen, normalization,
   contact-sheet, raw pixel, or production-selection path runs.

Headless Blender scene/camera construction and
`bpy_extras.object_utils.world_to_camera_view` are explicitly allowed for the
zero-pixel projection proof.

The packet must include the mapping contract, validator/tool hashes,
per-direction projection deltas, winding/handedness report, repeat identity,
and an explicit list of superseded v04/v05 assumptions.

## Cadence

1. Commit the task-owned bridge contract and validator.
2. Run the four-direction zero-pixel projection proof twice.
3. Commit the evidence packet and return cleanly to Integration.

Stop on any projection delta above `0.001` source pixel, hidden permutation,
direction mismatch, shared-file requirement, or pixel invocation. Do not
author North v07 geometry or render A in this authority.

After independent acceptance of this bridge, Integration will publish a new
North architecture authority against the corrected `z = -28` road edge. That
architecture may use a visible recessed/roofless loading court or turning
apron, but it must not assume that a conventional opaque far-wall portal will
be legible.
