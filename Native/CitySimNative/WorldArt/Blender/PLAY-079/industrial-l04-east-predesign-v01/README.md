# PLAY-079 Industrial L4 East predesign v01

This is an East-only, zero-pixel Blender predesign. It is not source authority,
is not production selected, and cannot invoke Process A until Integration
accepts North and publishes the shared Industrial L4 family/material lock.

The scene is independently authored from the published family, registration,
camera, light, shadow, frontage, and literal-192 requirements. No sibling
scene, component coordinates, geometry, raster, mask, or contact sheet is an
input. `orientationTransform` is explicitly `none`.

The East facade is organized around one monumental recessed freight portal on
the positive-X frontage, a compact human-scale control wing, a long high-bay
hall, two-level monitor/clerestory rhythm, a northwest process bay, paired
stacks, roof plant, tank, pipe bridge, and a south-side gantry. The process
equipment is deliberately separated from the portal projection.

`materials.json` binds provisional role names and analytic value targets only.
Its lock state is fail-closed until the accepted North family/material lock is
published.

Validation:

```bash
python3 validate_predesign.py --mode static

/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --disable-autoexec \
  --python-exit-code 1 \
  --python validate_predesign.py
```

Both modes emit JSON to standard output. The Blender mode reconstructs the
camera and geometry in memory and uses the actual `bpy` camera projection. It
does not call a render API or write an image.
