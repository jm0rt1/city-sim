# PLAY-027 Industrial L4 directional coordinate bridge v06

This task-owned zero-pixel bridge applies one global basis:

```text
B(CitySim[x,y,z]) = Blender[z,x,y]
```

It maps component positions and dimensions, camera position and target,
direction normals, light and shadow vectors, footprint points, pivots, and
frontage sockets without a per-direction transform or footprint reorder.

`validate_bridge_contract.py` performs the no-Blender structural gate.
`prove_coordinate_bridge.py` may construct the configured Blender camera and
use `world_to_camera_view`; it cannot render or emit pixels.

The bridge is proof tooling only. It does not authorize source geometry,
source pixels, normalization, renderer ingestion, or production selection.
