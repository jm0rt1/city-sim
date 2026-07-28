# PLAY-027 Industrial L4 v18 North Blender registration calibration v03

This directory is the committed text authority for the CONTRACT-020 North-only
registration-repaired transfer calibration. It consumes the immutable
`source-v18-prepixel`
descriptor and v14/v17 material library without changing either input.

The sole rendering change from v02 is the ground-plane camera shift repair:

```text
aspect = renderViewportPixels.width / renderViewportPixels.height
ortho_scale = 2 * SceneKit orthographicScale * aspect
shift_x = postProjectionOffsetPixels.x / renderViewportPixels.width
shift_y = postProjectionOffsetPixels.y / renderViewportPixels.width
```

For the frozen 1536x1024 descriptor, the aspect is `1.5` and Blender
`ortho_scale` is `237.5878601074218`; `shift_x` is `0` and `shift_y` is
`0.08333333333333333`. The pre-render proof projects the governed footprint,
pivot, socket, and origin directly from CitySim ground `y = 0`; it does not
derive an elevated registration plane from expected pixels. All other camera,
scene, material, lighting, contact, and Cycles settings remain bound to v02.

The importer maps CitySim `(x, y-up, z)` to Blender `(x, y-depth, z-up)`,
preserves all 51 explicit-component objects, uses 32-segment cylinders like the
retained SceneKit source builder, and records every mapped object. The
explicit-component contract intentionally skips descriptor chimney, facade,
and entrance metadata, matching the retained `ContractSceneBuilder`.

The authored southeast contact field is reconstructed from the exact footprint
polygon and the frozen `[2, 1]` source-pixel vector. Under the 72x36 projection,
the retained `[56, 28]` shadow offset equals `+15.75` CitySim world units on x.

Canonical invocation:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --disable-autoexec --threads 1 \
  --python-exit-code 1 \
  --python Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-v18-north-calibration-v03/render_v18_north.py \
  -- \
  --repository-root "$PWD" \
  --config Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-v18-north-calibration-v03/CALIBRATION-CONTRACT.json \
  --output-root /absent/task-owned/output \
  --process-id A
```

The three authorized processes use distinct absent evidence roots and process
IDs A, B, and C. This calibration is not source authority or production
selection and does not authorize a portal redesign, sibling direction,
normalization, ingestion, shipping, or product dependency.

Before any A/B/C process, the same script runs once with process ID
`PREPIXEL` and `--projection-proof-only`. That mode constructs the complete
configured scene and camera, writes the 51-component mapping plus the
fail-closed camera projection receipt, and exits before any render call.
