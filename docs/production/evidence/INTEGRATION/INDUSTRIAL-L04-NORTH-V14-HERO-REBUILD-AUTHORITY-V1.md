# Industrial L4 North v14 hero rebuild authority

**Owner:** Integration frontier authority

**Disposition:** authorized zero-pixel rebuild; DCC and source pixels remain blocked

**Task/lane:** PLAY-027 / `codex/citysim-world-art`
**Supersedes for future work:** North v13 as an appearance candidate only; all v13 bytes and rejection history remain immutable

## Why v13 returned

The exact v13 Process-A V5 raw is durably rejected at North commit
`bef02205d4b115bca35700ee9fa9fc6505f9a2d4`. It is not merely a dark render.
The child reduces the authored scene to broad boxes and one simple vessel,
silently omitting or flattening much of the stack, roof plant, annex detail,
bracing, glazing, heat cap, pipework, roof form, and industrial articulation.
The result is an underexposed stack of masses without a production-quality
hero silhouette or a readable monumental frontage.

The source canvas padding is not itself a camera failure. The existing v06
bridge, orthographic camera, footprint, pivot, socket, and raw source
registration remain frozen. Appearance is judged on the registered occupied
crop, native-2x output, and literal-192 output as well as the full raw.

## Non-shipping visual target

The built-in ImageGen concept at
`docs/production/evidence/INTEGRATION/industrial-l04-north-v14-hero-target-v1.png`
is a visual vocabulary target only. Its SHA-256 is
`a5ea4e52eeacd1820a9bd576c3df48850ba39f6543ff4e2a284ebd7753c2e7f1`.
The adjacent provenance record freezes the prompt and failed-v13 reference.

Do not ship, trace, raster-convert, reconstruct, or use the concept's pixels,
camera, footprint, coordinates, or geometry as source authority. The North
cell must author deterministic text geometry independently under the frozen
CitySim registration. Use the concept only for the intended level of material
richness, industrial specificity, silhouette hierarchy, lighting readability,
and believable wear.

## Frozen v14 player-facing outcome

At first glance the building must read as a major late-game foundry rather
than a generic warehouse or a larger L3. Within two seconds at literal 192 the
player must see:

1. one deep, monumental, north-road-facing freight portal as the primary read;
2. a broad warm-brick foundry with at least three distinct roof-height tiers;
3. a raised clerestory or crane-lantern crown, subordinate to the portal;
4. one integrated process tower/vessel and pipe cluster with restrained heat;
5. one compact boiler stack, a staff/control annex, and a worked loading apron;
6. strong northwest-light and southeast-shadow depth without crushed blacks;
7. coherent materials and believable use: seams, glazing, vents, rails,
   gutters, soot, rust, concrete joints, safety markings, and service doors.

The silhouette must have at least five meaningful breaks distributed across
the roofline and sides. Detail must be grouped into readable masses: dense
micro-noise, detached props, fantasy machinery, neon, and decoration that
vanishes at literal 192 do not satisfy this outcome.

## Frozen spatial and family invariants

- Preserve the accepted v06 coordinate bridge exactly: CitySim North is
  `z = -28`, `B(x,y,z) = (z,x,y)`, descriptor order `[0,1,2,3]`.
- Preserve the 56 x 56 maximum footprint, 72 x 36 tile basis, source footprint
  polygon, ground pivot `[768,896]`, North frontage socket `[896,704]`,
  fixed camera, post-projection shift, and southeast contact-shadow direction.
- Preserve the accepted vertical envelope: non-stack mass at or below 40
  world units and the subordinate stack at or below 44.
- Keep the freight opening connected to the North socket through the apron.
- Keep all industrial geometry inside the footprint except the approved
  contact shadow. Bake no road, UI, labels, people, vehicles, or gameplay state.
- Preserve the family palette roles: warm masonry, charcoal structural steel,
  weathered blue-green roof metal, oxidized process machinery, concrete/apron,
  dark freight depth, warm glazing, and restrained amber-orange heat.
- Author North independently. No sibling geometry, mirror, rotation, alias,
  whole-building ImageGen composition, or fallback is permitted.

## Required deterministic authoring architecture

Create a new versioned root
`Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14/`
and matching evidence beneath
`docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v14/`.
Do not edit or delete v13.

The v14 text scene and lowerer must explicitly support the visible forms they
claim. At minimum the implementation needs deterministic primitives or mesh
builders for:

- union-safe structural boxes and recessed compound portal frames;
- pitched/sawtooth roof wedges and clerestory glazing bands;
- cylinders and capped vessels/stacks;
- deterministic pipe runs with elbows and supports;
- trusses, braces, railings, ladders, gutters, vents, louvers, and roof plant;
- mullioned windows, service doors, loading markings, seams, and material-wear
  bands sized to survive native-2x and literal-192 review; and
- a grounded southeast contact-shadow receiver compatible with transparent
  film.

Every governed design component ID must lower to one or more named Blender
objects or be rejected by validation. No semantic component may be silently
ignored, replaced with a generic box when its declared primitive is different,
or omitted from the object manifest. Component-to-object coverage must be
100%; object-count reporting is an anti-omission diagnostic, not a substitute
for visual quality.

## Lighting and color authority

Use deterministic Cycles CPU under CONTRACT-020. Preserve northwest key and
southeast shadow semantics, but replace the v13 underexposure with a frozen
daylight rig and explicit color management. The zero-pixel packet must specify
and test the exact world fill, key type/color/energy/angle or size, optional
deterministic fill/rim if used, display device, view transform, look, exposure,
gamma, samples, seed, threads, bounce limits, and transparent-film settings.

The later Process-A gate will measure alpha-visible pixels on the occupied crop:

- each RGB channel maximum at least `0.60` and no channel clipped across more
  than `0.5%` of visible pixels;
- median visible Rec.709 luma in `[0.22, 0.58]`;
- p95 visible luma in `[0.55, 0.90]`;
- at least `95%` of non-emissive visible pixels above luma `0.035`;
- portal interior at least `0.18` luma darker than its adjacent structural
  frame while retaining visible interior depth; and
- warm emissive accents no more than `4%` of visible pixels.

These are failure floors, not automatic visual acceptance. Integration still
owns the subjective color, hierarchy, material, and appearance disposition.

## Zero-pixel deliverable and stop

Return one coherent v14 zero-pixel candidate containing:

- text scene, material, lighting/color, and lowering contracts;
- deterministic builders and focused tests;
- exact component-to-object coverage, spatial registration, occlusion,
  silhouette-break, portal-connectivity, material-role, and literal-scale
  analytic reports;
- a compact handoff identifying every v13 omission repaired and every future
  Process-A gate; and
- one clean PLAY-027 commit limited to the new v14 task/evidence roots.

Stop before Blender/DCC execution, source pixels, normalization, Process A/B/C,
appearance lock, source admission, Renderer activation, shipping, push,
integration, or self-acceptance. Integration must independently accept the
zero-pixel candidate and publish a new exact one-attempt Process-A schedule.
