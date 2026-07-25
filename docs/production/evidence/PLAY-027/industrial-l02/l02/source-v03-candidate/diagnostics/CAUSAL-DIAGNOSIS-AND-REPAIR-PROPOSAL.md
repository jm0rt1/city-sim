# PLAY-027 Industrial L2 source-v03 causal diagnosis

Disposition: causal diagnostic complete; no repair implemented.

## Cause

The source-v03 renderer failure is a host graphics-backend availability
failure, not a scene, descriptor, geometry, material, texture, node identity,
or cumulative complexity failure.

The exact diagnostic process reports:

- `MTLCreateSystemDefaultDevice()` is nil;
- `MTLCopyAllDevices()` returns zero devices;
- `SCNRenderer(device:nil)` has no device;
- `SCNRenderer(device:MTLCreateSystemDefaultDevice())` also has no device;
- synchronous `prepare` returns false for an empty `SCNScene`;
- it also returns false for an empty node and empty material;
- a supplied abort callback that always returns false is never invoked and
  cannot have canceled preparation.

Apple documents the synchronous API as returning true when preparation
succeeds and false when preparation is canceled:
<https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare%28_%3Ashouldabortblock%3A%29>.
Here the nil-block and never-cancel controls both return false before any
candidate content participates. The renderer’s existing generic
`SceneKit could not prepare the complete scene graph` error therefore
misattributes a missing Metal backend to the authored scene.

## Scene-content exclusion

The unchanged North scene’s complete inventory has 130 unique finite nodes,
2,046 primitives, 381 geometry sources, 145 elements, 127 material
references, no external texture path, and zero validation failures.

All six isolated groups and all six cumulative sets return false. Individual
foundation, assembly-hall, light, ambient, and camera nodes return false. The
zero-node clone returns false. There is no minimal failing authored node or
resource set; the minimal failing set is the empty scene.

The full East, South, and West inventories independently contain the same
valid 130-node/2,046-primitive inventory and also return false on this
zero-device host. This confirms that the identical four-direction failure
does not track any direction-specific geometry.

## One narrow repair proposal — not implemented

Add a task-owned offline renderer capability preflight before scene
preparation:

1. require a non-nil `MTLCreateSystemDefaultDevice()` and non-nil
   `SCNRenderer.device`;
2. if either is unavailable, emit an explicit
   `renderer-backend-unavailable` diagnostic containing host/tool/framework
   identity and stop before descriptor construction or candidate output;
3. on a Metal-visible approved macOS process, retain the existing synchronous
   `prepare` guard so a true object-preparation failure remains fatal;
4. run the already-authorized A/B/C source batch only after that capability
   preflight passes.

This proposal does not skip preparation, weaken a source gate, alter
source-v03, change sampling, or normalize an unrendered set. It separates an
execution-host prerequisite from source-art validity. Integration must approve
implementation and a Metal-visible execution route before any render retry.
