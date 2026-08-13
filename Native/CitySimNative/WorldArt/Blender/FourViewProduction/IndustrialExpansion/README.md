# Four-View Industrial Expansion

`copperline_machine_shop` is an original low-industrial CitySim asset authored against the canonical Four-View contract. Its 2x2 source lot uses the fixed 88x44 projected cell, 384x384 transparent canvas, `(192,300)` top-origin pivot, four orthographic cameras, and the shared `CitySimKey` light without per-view compensation.

Generate all source artifacts and representative previews:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python build_and_render.py
```

Validate source geometry, camera registration, pivot contact, manifest hashes, previews, and byte-identical clean rerenders:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python validate.py -- --report validation/validator-output.txt
```

This directory is source-only until the integration owner independently accepts and admits the canonical `camNE` PNG.
