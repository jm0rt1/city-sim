# PLAY-027 Industrial L3 East/South material-binding repair authority

- Published integration baseline:
  `c3c727f9244ba7047f81aeb85f8eae6e4347891f`
- Owning lane: World art generation cell
- Branch: `codex/citysim-world-art`
- Scope: metadata-only source-authority repair
- Pixel mutation: forbidden
- Renderer or shipping mutation: forbidden

## Blocker

The accepted Industrial L3 family manifest correctly binds the East and South
raw masters to the cohesion material library, but the exact accepted East and
South scene descriptors still name the retired directional-family-v02 library.
The renderer's required descriptor-to-catalog material validation correctly
rejects that contradiction before production ingestion.

This is an authority-record defect, not authorization to rerender,
renormalize, retouch, replace, or reinterpret any accepted pixel.

## Exact authorized edits

Update only `materialLibrary.file` and `materialLibrary.sha256` in these two
scene descriptors:

1. East descriptor:
   `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-east-v01/scenes/industrial_l03/variant-0/east/scene.json`
   - current descriptor SHA-256:
     `1e5c69a03a6298f64f4d4d13bb0f523690729b82d5565343f40aaa8278aa3b6d`
2. South descriptor:
   `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-siblings-v01/scenes/industrial_l03/variant-0/south/scene.json`
   - current descriptor SHA-256:
     `31c7eef5e3f461b97b116288274baa8bc5980ef711d45401645e2925ac326a48`

Replace the retired binding:

- file:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-directional-family-v02/materials/industrial-l03-v02.json`
- SHA-256:
  `3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`

with the cohesion binding already recorded by the accepted raw-master
manifest and provenance:

- file:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-east-v01/materials/industrial-l03-cohesion-east-v01.json`
- SHA-256:
  `f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65`

After computing the two new descriptor hashes, update only the corresponding
East/South `descriptorSHA256` entries and metadata-derived receipt fields in:

`docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-complete-family-v01/FAMILY-MANIFEST.json`

Create a concise repair receipt beside the family manifest. It must record the
old and new descriptor hashes, the unchanged material-library hash, and exact
before/after pixel inventories.

## Required proof

The World Art lane must prove:

1. both repaired descriptors resolve the cohesion material-library path and
   exact SHA-256;
2. the family manifest, descriptor, accepted raw provenance, and raw-master
   material fields agree for all four directions;
3. a deliberately swapped file or wrong hash fails the validator;
4. East/South descriptor JSON is structurally identical before and after when
   `materialLibrary.file` and `materialLibrary.sha256` are excluded;
5. every accepted raw and normalized PNG remains byte-identical to
   `0aefb804c59b4ff9b919dc81fdca907cd4b85c5e`;
6. all 12 normalized outputs retain unique file and decoded-pixel identities,
   repeat identity, registration, alpha, chroma, padding, and contact-shadow
   passes; and
7. North/West descriptors, all scene geometry, all material-library bytes, all
   renderer/shipping/package/runtime files, and all unrelated accepted catalog
   bytes remain unchanged.

Commit one clean `PLAY-027` metadata-repair checkpoint and stop for integration
review. Do not push, integrate, self-accept, rerender, renormalize, or begin
Industrial L4 in the same checkpoint.

## Integration disposition

The prior source-family acceptance remains visually valid but is superseded as
renderer-ingestion authority until this metadata repair is independently
reviewed and published. Once accepted, integration will publish the repaired
family manifest and authorize the renderer to resume the exact replacement-R2
ingestion. Production selection and shipping acceptance remain false.
