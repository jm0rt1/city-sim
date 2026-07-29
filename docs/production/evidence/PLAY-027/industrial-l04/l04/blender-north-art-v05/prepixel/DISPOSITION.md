# PLAY-027 Industrial L4 North art-v05 zero-pixel return

**Disposition:** `REJECT_ZERO_PIXEL_CAMERA_FAR_OCCLUSION`

The v05 descriptor correctly relocates the complete portal assembly to the
governed `X=-28` facade, places its threshold inside the footprint at
`X=-20.4`, preserves outward normal `-X`, and passes the static aperture,
process-overlap, footprint, pivot, socket, camera, light, shadow, material, and
Cycles checks.

The binding actual-camera PREDESIGN proof fails:

- portal inset: `0x0`, zero visible pixels;
- north jamb: zero visible pixels;
- south jamb: zero visible pixels;
- all three reveals: zero visible pixels;
- visible court and threshold: zero visible pixels;
- staff entry: `4x8`, pass;
- four monitor caps and three silhouette tiers: pass;
- occupied compact envelope: `56x48`, below returned v03 `62x50`.

The frozen camera is `+X/+Z`; the relocated `X=-28` facade remains camera-far
behind the preserved hall. Plane/socket agreement therefore does not produce
a player-visible frontage. No raw render was called, process A remains
unconsumed, and no sibling or normalization work ran.

Final command:

```text
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec --threads 1 --python-exit-code 1 --python Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v05/render_north_art_v05.py -- --repository-root /Users/James/.codex/worktrees/0648/city-sim --contract Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v05/ART-CONTRACT.json --output-root /Users/James/.codex/worktrees/0648/city-sim/docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v05/prepixel/proof --process-id PREDESIGN --predesign-proof-only
```

The command exited `1` after writing the fail-closed proof and before any
`bpy.ops.render.render` call.
