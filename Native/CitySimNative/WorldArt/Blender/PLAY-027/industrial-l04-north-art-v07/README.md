# PLAY-027 Industrial L4 North art v07

This zero-pixel North architecture uses the accepted v06 global coordinate
bridge and canonical CitySim North road edge `z=-28`.

The design replaces the invalid opaque far-wall assumption with two separately
authored foundry wings framing a roofless freight throat. The throat reaches
the canonical North socket and widens into a hammerhead service court. A
monumental frame, three deep side-return freight recesses, a bridge gantry,
high-bay roof monitors, hot-process machinery, a separate staff entrance, and
a subordinate stack preserve Industrial L4 scale and identity.

`validate_predesign.py` owns the static descriptor gate.
`prove_actual_camera.py` constructs component geometry and the accepted camera,
then uses `world_to_camera_view` and camera-ray intersection at literal
`192x128`. It does not invoke rendering or emit pixels.

`MATERIALS.json` is a byte-identical, task-local copy of the immutable
North L4 family input at SHA-256
`474952f3f28a880d5517bab4e964c8bcdd6d773ffa5349c515b1831f58e92fab`.
Keeping it in this root makes the predesign replay self-contained without
changing any material value or role.

This candidate remains zero-pixel predesign evidence only:
`sourceAuthority=false`, `productionSelected=false`, and A/B/C are unproduced.
