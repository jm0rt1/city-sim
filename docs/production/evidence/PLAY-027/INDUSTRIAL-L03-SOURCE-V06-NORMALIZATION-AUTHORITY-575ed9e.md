# PLAY-027 Industrial L3 source-v06 normalization authority

- Exact accepted raw candidate:
  `575ed9e19f98f48148fa0cca9f075514a2b0daa6`
- Exact resolver checkpoint:
  `d2649fc8f43d68360757031ff4d1c5ed856de089`
- Integration disposition:
  `ACCEPT_RAW_AUTHORIZE_NORTH_WEST_NORMALIZATION_AND_FAMILY_REVIEW`
- Independent renderer disposition: `ACCEPT_FOR_NORMALIZATION`
- Independent QA disposition: `ACCEPT_FOR_NORMALIZATION`
- Authorized new normalization directions: North and West only
- Authorized normalizer processes: two per new direction
- East/South: immutable accepted raw and normalized bytes
- Source authority: `false`
- Family authority: `false`
- Production selected: `false`

The exact raw candidate passes independent technical and visual review. N/E/S/W
read as one asymmetric Industrial L3 plant with consistent brick, teal steel,
tan concrete, ochre trim, dark loading recesses, grounding, scale, shadow,
frontage, and value hierarchy. North and West retain two complete loading bays
plus a separate staff entrance at native and compact scale. All four directions
are unique, authored without transforms, and have no accepted-catalog
intersection.

## Exact raw inputs

Normalize only:

- North run-A:
  `docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/north/run-a/raw.png`
  - file SHA-256:
    `91b3fb983e294eeff288b13f6d89a19366393cfaf084b52527633e88ed0507ea`
  - decoded-RGBA SHA-256:
    `ca087fb06b5bcc67ea101f661ac07a5a1b263d5b3b32db4d1c6d8aa7d18764af`
- West run-A:
  `docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-raw-review-v01/diagnostics/raw-repeat/west/run-a/raw.png`
  - file SHA-256:
    `ceaa2948be0f37cbd8f6288c9c125f15502a864ce683bc3eaa1cd0d7563477d4`
  - decoded-RGBA SHA-256:
    `f66b4fe3cde165e0c3852ce5aa0863ec7380824f46e81708804428b6717be310`

Do not normalize run-B or run-C; their equality is already proven. Do not
rerender any direction.

## Frozen normalizer contract

Use the existing task-owned normalizer without modification:

- source:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/NormalizeOfflineSource.swift`
- source SHA-256:
  `c37012ca5dbf958f8b5c37df8ec712535865c1ddc769385e432792214dfb67ed`
- strict chroma helper:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/StrictNonzeroAlphaChromaCanonicalizer.swift`
- helper SHA-256:
  `5e8feb9f559bf0f01ad69d5b88ff2692a7a71b4788c6d1718e2a1b265ab78d0f`
- object width: `410`
- reference subject width: `512`
- source ground pivot: `(768,896)`
- strict chroma contract:
  `play027-zero-nonzero-alpha-chroma-premultiplied-v1`
- LOD outputs:
  - block `1024×683`;
  - neighborhood `512×342`;
  - city `256×171`.

Run two independent normalizer processes for North and two for West. Each
direction's block, neighborhood, and city output must be byte-identical and
decoded-pixel-identical across the two runs.

Use asset IDs:

- `industrial_l03_north_source_v06`;
- `industrial_l03_west_source_v06`.

## Immutable accepted East/South normalized bytes

Do not regenerate, rename, mutate, or copy-reencode these outputs. Reference
the retained accepted run-A bytes and independently verify that retained run-B
is still byte-identical:

### East source-v04

- block:
  `5e02d83a0b4f929584ab0a240ac9661f055ea1e1e371810d39077ad6d169e6ba`
- neighborhood:
  `36598c75d1d94bf0599062e20ad2e343ca1d076de96dfae8464a898fab9ee342`
- city:
  `136d1a9a2e514cbcd1306d4f589f523bf75913ef7f998efdacea6fd0025e052e`

### South source-v04

- block:
  `c0b47330aa41d7c04c19230635611eb70da534a1b5c7b0ea0fba46b4c8faba2c`
- neighborhood:
  `05207da9254d605fe80b5c0084e13fcf1c7c3a3a42104cb2f30b58cedc87e5c1`
- city:
  `05064fe4930a458f2149d196841d8405e73ebd6d6ac041bdb53df8429ac0f21e`

The retained accepted paths are under:

`docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-family-v01/chroma-repair-v01/normalized/`

## Required complete-family gate

Build one deterministic family manifest and actual-pixel review packet covering
exactly:

- North source-v06 normalized run-A;
- immutable East source-v04 normalized run-A;
- immutable South source-v04 normalized run-A;
- West source-v06 normalized run-A.

Require:

1. 12/12 unique decoded-pixel identities across four directions and three LODs;
2. North/West two-run file and decoded-pixel identity for all six new outputs;
3. East/South retained run-A/run-B identity and exact hashes above;
4. zero hidden RGB, zero exact or near-magenta spill at nonzero alpha, correct
   padding, and no lost contact-shadow support;
5. transformed ground-pivot, footprint, socket, frontage, scale, and
   registration consistency at all LODs;
6. no file or decoded-pixel intersection with accepted catalog assets;
7. no mirror, rotation, recolor, substitution, fallback, or alias metadata;
8. source-scale, native-2x, block, neighborhood, city, compact, grayscale,
   occupied-frontage, road/socket-overlay, and neutral-ground family panels;
9. explicit comparison against the rejected chalky Industrial L3 R2 family;
   and
10. visible proof that the mixed v04/v06 family remains one material language
    after alpha extraction and every LOD reduction.

Any magenta halo/spill, lost or detached contact shadow, broken frontage,
directional material-family switch, compact-scale collapse, or cross-catalog
alias is a hard return.

Commit one clean complete-family review candidate and stop. Do not edit the
normalizer, source descriptors/libraries/raws, East/South outputs, resolver,
renderer/shipping code, generated production pack, package topology, shared
manifests, or gameplay/UI/simulation surfaces; do not begin L4/A2, push, or
self-accept.
