# Four-View Park Expansion

`canal_lantern_park` is an original 2x2 park lot authored against CitySim's canonical Four-View contract. Paths, basin, pergola, planters, and lot boundaries remain parallel to shared world XY. The source uses the fixed 88x44 projected cell, 384x384 canvas, `(192,300)` top-origin pivot, four orthographic cameras, and `CitySimKey` light without compensation.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python build_and_render.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python validate.py -- --report validation/validator-output.txt
```

This directory remains source evidence; live admission is a separate integration decision.
