# PLAY-027 Industrial L3 source-family acceptance

- Exact accepted source candidate:
  `0aefb804c59b4ff9b919dc81fdca907cd4b85c5e`
- Integration disposition:
  `ACCEPT_SOURCE_FAMILY_AUTHORIZE_REPLACEMENT_R2_INGESTION`
- Independent renderer disposition:
  `ACCEPT_SOURCE_FAMILY_FOR_RENDERER_INGESTION`
- Independent QA disposition:
  `ACCEPT_SOURCE_FAMILY_FOR_RENDERER_INGESTION`
- Source authority: `true`
- Family authority: `true`
- Production selected: `false`
- Shipping acceptance: `false`

Integration accepts the exact mixed-revision Industrial L3 family as source
authority:

- North: source-v06 normalized run-A;
- East: immutable accepted source-v04 normalized run-A;
- South: immutable accepted source-v04 normalized run-A;
- West: source-v06 normalized run-A.

The accepted family manifest is:

`docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-complete-family-v01/FAMILY-MANIFEST.json`

- manifest SHA-256:
  `8c9c2038993d1a9389342784d2bccc4d78cebdb7b063c3f741620d2cbeca8a09`;
- validation SHA-256:
  `f78d52e762b4bd68dcd7325740684a6d394204a87cce1924e65a9ef6c1707d91`;
- author disposition SHA-256:
  `98f1dc30301803343dc2b14402a8e36315da495fbcddfb74c163ad3680a0b7e1`.

Independent verification confirms:

- 12/12 direction-by-LOD outputs have unique file and decoded-pixel identities;
- all 12 outputs are byte- and decoded-pixel-identical across two retained
  normalization runs;
- East/South retained accepted bytes are unchanged;
- North/West use distinct direction-scoped source-v06 material libraries;
- hidden RGB, visible exact/near chroma, halo, padding, contact-shadow,
  grounding, pivot, frontage, and road-socket gates pass;
- no alias, mirror, rotation, recolor, fallback, or accepted-catalog
  intersection exists;
- N/E/S/W remain one recognizable asymmetric Industrial L3 plant at block,
  neighborhood, city, compact, and grayscale scales; and
- compared with rejected R2, the accepted source materially improves depth,
  warm/cool material hierarchy, dark loading recesses, entrance clarity,
  grounding, and rotation cohesion.

## Replacement-R2 renderer authority

The renderer lane may ingest exactly the 12 manifest-listed run-A assets into
the existing generated-v4 production pack. It must:

1. preserve the runtime logical selections
   `industrial_l03_v0_{north,east,south,west}`;
2. preserve authoritative road frontage and all unrelated catalog bytes;
3. make no loader, gameplay, save, simulation, UI, public-manifest-schema, or
   package-topology change unless a new integration contract is approved;
4. prohibit rerendering, renormalization, tinting, mirroring, rotation,
   substitution, aliasing, and fallback;
5. enforce descriptor `sourceRevision == selection.source_revision` for every
   explicit-file selection;
6. enforce that each catalog entry's material-library file and SHA-256 match
   the bound descriptor, including the distinct North/West v06 libraries;
7. require material-library file/hash provenance in offline directional
   validation without expanding the runtime Swift manifest contract;
8. produce two deterministic pack builds with exact source-to-pack identity,
   four-direction by three-LOD lookup proof, zero geometry collisions, and
   unchanged Industrial L1/L2 and unrelated payload hashes; and
9. stop at one exact replacement-R2 candidate for staged regular/compact
   interaction, visual-cohesion, accessibility, and performance acceptance.

This acceptance does not select production assets by itself. The renderer owns
production ingestion, integration owns staged-app acceptance, and QA owns the
independent final disposition.
