# PLAY-027 Industrial L4 duplicate-foundation repair authority

- Returned World Art candidate: `a47215eae5ea1d73a105f7a94c7c415a2f997bea`
- Integration preservation merge: `1ab764ed8e7d3ea9baa9f0fed6c63eae49fbb425`
- Matte R2: `APPROVED`
- Semantic diagnostic: `KEPT_AS_RETURN_EVIDENCE`
- Portal: `REJECTED`
- Source authority: `false`
- Production selected: `false`
- Diagnostic SceneKit/Metal processes authorized: `2`
- Authoritative raw processes authorized: `0`

## Proven defect

The two existing-renderer semantic captures have identical descriptor,
material, binary, and 52-node manifest bindings but differ across `13,629`
decoded pixels and `26,924` channels.

Renderer review localized `13,191` pixels to the projected foundation. The
scene contains canonical `foundation` and mass block `v16-foundation` with
identical `56 × 1.4 × 56` dimensions, `[0,0.7,0]` position, bounds, and
material. Their semantic labels differ, so SceneKit's coplanar depth tie
appears directly as the dominant `other → hall` A/B transition.

The portal independently fails: its literal-192 south jamb has only three
visible pixels, and the unlabelled full building does not read as a monumental
framed freight portal.

## Authorized repair

World Art may create one new immutable North descriptor revision that:

1. proves canonical `foundation` and `v16-foundation` are exact duplicates;
2. removes only `v16-foundation`;
3. preserves every other descriptor, material, camera, sampling,
   registration, contact, shadow, and semantic binding;
4. updates only exact task-owned resolver/toolchain bindings required for the
   new descriptor revision; and
5. runs exactly two diagnostic-only SceneKit/Metal semantic processes through
   the existing renderer path.

The output must have a 51-node manifest, byte-identical PNG and decoded RGBA
inventories, and zero differing pixels or channels. Portal component counts
must remain unchanged; this slice is not allowed to repair or accept art.

Stop and return on any remaining repeat split. If repeat identity passes,
commit the exact clean diagnostic packet and return for independent Renderer
and QA review before any portal modeling.

No raw, normalizer, sibling, source-authority, ingestion, shipping, or
production-selection process is authorized.
