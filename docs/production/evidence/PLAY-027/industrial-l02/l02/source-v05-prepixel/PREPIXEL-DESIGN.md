# PLAY-027 Industrial L2 source-v05 pre-pixel design

**Disposition:** frozen review candidate; no building pixels or normalization
are authorized or present.

Industrial L2 source-v05 retains the complete source-v04
`integrated-logistics-geometry-v3` geometry, fixed camera, 2:1 footprint,
ground pivot, directional sockets, entrance bases, northwest light contract,
and authored southeast contact shadow. Each N/E/S/W descriptor remains an
independent scene description with its own geometry ID and geometry payload;
no sibling mirror, rotation, transform, raster, or substitute source exists.

The only production-path changes are descriptor-bound and additive:

- `sceneKitLightingMode: authored-constant-v1`;
- `.constant` SceneKit materials from the source-v05-only 21-role library;
- two zero-intensity, non-shadowing SceneKit lights;
- the already frozen schema-2 v3 path: no MSAA, SceneKit shadows disabled,
  fixed 4x linear oversampling, software `CILanczosScaleTransform` at 0.25,
  step-32 quantization, ImageIO/sips canonicalization, and immutable
  post-quantization canonicalizer v3;
- the authored contact/footprint shadow remains enabled and unchanged.

The material library deliberately separates northwest-lit and side planes,
recesses, sawtooth and flat roofs, bright and side trims, two glazing values,
loading throat and door, hazard crown and recessed hazard roles, foundation,
mechanical, exhaust, rooftop metal, and oxide tank roles. Its deterministic
ladder spans relative luminance 0.122218 through 0.681284 and presents each
authored color beside its exact Rec.709 grayscale value.

All 36 accepted Residential L1-L4, Commercial L1-L4, and Industrial L1
canonical descriptors are byte-identical to
`ba4845612c2a5e8ce746c2a08379342bbca946f1` and still resolve
`lambert-scene-lights`. The source-v04 rejection evidence tree remains exact
Git tree `2261bc847a46f9659e657e5e435c69f37611d784`, and its four descriptor bytes
are separately archived in this packet.

`productionSelected` remains `false`. This checkpoint requests only
independent pre-pixel architecture review; it is not source-art acceptance or
raw-render authority.
