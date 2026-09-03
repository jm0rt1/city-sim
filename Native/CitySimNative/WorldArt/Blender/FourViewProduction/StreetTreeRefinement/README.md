# Maple Street Tree Refinement

One original modeled refinement of the Greenworks Nursery street maple. A
tapered, gently bent trunk forks into supporting branches; an irregular layered
crown reaches lower around the forks, replacing the former pole-and-ball form.
The existing warm-green materials, one-cell planting footprint, ground pivot,
four cameras, canvas and light are preserved. No runtime transform, pixel reuse,
crop, skew, offset or per-view compensation is introduced.

The unchanged `../GroundEcology/build_and_render.py` supplies the modeling,
material, rig and manifest helpers. Its independent validator reopens this source
and rerenders all four views. The historical source family is left untouched.

Run this focused source pass with Blender 4.5.12:

```sh
/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python build_and_render.py
/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python validate.py
```

The `.blend`, four transparent canonical PNGs, contact sheet and manifests are
source artifacts. Native admission requires the separately judged composed app;
the builder never writes live resources.
