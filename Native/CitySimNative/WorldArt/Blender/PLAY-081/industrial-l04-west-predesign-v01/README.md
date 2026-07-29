# PLAY-081 Industrial L4 West zero-pixel predesign

This directory is the independent, text-only West predesign authorized by
CONTRACT-021. It consumes published registration, camera, light, shadow,
family, and material-role requirements only. No sibling scene geometry,
component coordinates, pixels, masks, or transforms were consumed.

The West design uses a socket-connected frontage apron and one monumental
recessed forge throat on the governed West edge. A long high-bay foundry,
three unequal roof-monitor heights, subordinate offset stack, low warm control
wing, and projection-separated gantry/process court create a distinct
heavy-industry silhouette. The material binding contains provisional numeric
roles only; Integration's future North family/material lock must replace those
values before any Pixel A authorization.

The static proof is pure Python and emits no pixels:

```sh
python3 Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-predesign-v01/validate_predesign.py \
  --repository-root "$PWD" \
  --scene Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-predesign-v01/PREDESIGN-CONTRACT.json \
  --materials Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-predesign-v01/MATERIAL-ROLE-BINDING.json \
  --output docs/production/evidence/PLAY-081/STATIC-PREDESIGN-PROOF.json
```

The actual-camera proof launches factory-startup Blender, constructs the
West-only scene, projects it through the governed camera, and exits without
calling `bpy.ops.render` or writing an image:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --disable-autoexec --threads 1 \
  --python-exit-code 1 \
  --python Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-predesign-v01/prove_actual_camera.py \
  -- \
  --repository-root "$PWD" \
  --scene Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-predesign-v01/PREDESIGN-CONTRACT.json \
  --materials Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-predesign-v01/MATERIAL-ROLE-BINDING.json \
  --output docs/production/evidence/PLAY-081/ACTUAL-CAMERA-PREDESIGN-PROOF.json
```

Pixel A, B/C, normalization, source authority, renderer ingestion, shipping,
runtime changes, production selection, push, integration, and self-acceptance
remain forbidden.
