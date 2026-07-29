# Industrial L4 source-stage schema v2 authority

- **Disposition:** `V1_SUPERSEDED_BEFORE_SOURCE_PRODUCTION`
- **Replacement:** `industrial-l04-source-stage-handoff-schema-v2.json`
- **Replacement SHA-256:** `93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7`
- **Owner:** Integration
- **Pixel/source impact:** none

Independent Integration review found two defects in v1 before any source
candidate or pixel production was authorized:

1. the LOD record used `allOf` to add `detail` to a raster schema with
   `additionalProperties:false`, so no LOD record containing the required
   detail field could validate; and
2. identity, source-key, launch-process, and final registration relationships
   were not bound tightly enough by direction.

V1 remains retained as rejected contract evidence. It must not validate a
launch-bound or source-candidate handoff and must not be copied or repaired by
a direction cell.

V2:

- gives city, neighborhood, and block independent named LOD slots;
- binds task, branch, direction, logical ID, source-key path, process release,
  output-root set, frontage socket, frontage edge, and authored orientation;
- binds the accepted v06 bridge, CONTRACT-010, CONTRACT-021 revision 2, and the
  common 44-master non-alias input by exact path and hash;
- requires A/B/C source and semantic/provenance records, three LODs, complete
  D4 fingerprints, direction-specific registration, and all source gates for a
  source candidate;
- identifies the selected process/source without allowing a worker to set
  source, Renderer, or production acceptance;
- keeps production selection false; and
- distinguishes North B/C release from sibling A/B/C release after the exact
  appearance lock.

JSON Schema is only the structural gate. Every packet must also pass:

- `Native/CitySimNative/WorldArt/Shared/accepted_master_non_alias_v1.py`,
  SHA-256
  `2c44bc3a4ffe3fdfc68a477b70f3af9478122e9b796543f32a154859ac300a39`,
  which fail-closes the exact 44-master authority and forbidden-set digest;
- `Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift`, SHA-256
  `2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab`,
  which recomputes ImageIO/CoreGraphics premultiplied-sRGB file, decoded-RGBA,
  occupied-bounds, and D4 identities; and
- `Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py`,
  SHA-256
  `7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340`,
  which validates the exact schema, repository-confined direction-owned paths,
  published Integration authority, Git ancestry, process/root isolation,
  A/B/C identity, selected-source binding, exact LOD dimensions, registration,
  canonical D4 identities, and 44-master non-intersection.

The worker disposition is `source_candidate` with
`candidateReadyForIndependentReview:true`. The packet must keep
`sourceReady`, `integrationAdmitted`, `rendererQuarantined`, and
`productionSelected` false. Integration publishes a separate source-admission
receipt only after semantic, technical, and literal-scale review.

The later Integration-published source-production profile is one exact JSON
authority with schema
`citysim.integration.world-art-source-production-profile.v1`. It binds
Industrial L4 variant 0, the exact appearance lock, committed material mapping,
this schema path/hash, direction process releases, the maximum concurrent DCC
process count and Integration exception owner, and false source/Renderer/
production/shipping grants. Until that published profile exists on `master`,
semantic validation must fail closed and no source process may launch.

East, South, and West may finish their direction-local pre-lock repairs while
v2 is published, but their final future-source binding must use the exact v2
path and hash. No direction may render from either schema until Integration
publishes the North appearance lock and a post-lock production authority.
