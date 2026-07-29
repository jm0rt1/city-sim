# PLAY-080 Industrial L4 South predesign

This directory contains an independently authored, South-only, zero-pixel
Blender predesign. It reconstructs the published R3 registration targets with
an actual Blender orthographic camera and validates the South facade, portal,
footprint, pivot, socket, silhouette, light, shadow, and process occlusion
without invoking `bpy.ops.render`.

The material bindings are provisional role intent. Pixel A remains blocked
until Integration publishes the accepted North family/material lock.

Static proof:

```bash
python3 validate_predesign.py \
  --mode static \
  --scene industrial-l04-south-predesign-v01.scene.json \
  --materials industrial-l04-south-predesign-v01.materials.json \
  --output ../../../../../docs/production/evidence/PLAY-080/PREDESIGN-STATIC-PROOF.json
```

Actual-camera zero-pixel proof:

```bash
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --disable-autoexec \
  --python-exit-code 1 \
  --python validate_predesign.py -- \
  --mode actual-camera \
  --scene industrial-l04-south-predesign-v01.scene.json \
  --materials industrial-l04-south-predesign-v01.materials.json \
  --output ../../../../../docs/production/evidence/PLAY-080/PREDESIGN-ACTUAL-CAMERA-PROOF.json
```

Both commands are intended to run from this directory. The Blender command
creates meshes and projects them through the configured camera; it emits no
image and performs no render.
