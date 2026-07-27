# Industrial L3 East/South material-binding repair

**Disposition:** `PENDING_INDEPENDENT_METADATA_REVIEW`

This metadata-only repair executes the authority published at
`ca3be18c3ea4e34aa3694e358451f904f1385642`. It does not rerender,
renormalize, modify a material library, select production art, or change any
renderer or shipping surface.

## Exact descriptor changes

- East:
  `1e5c69a03a6298f64f4d4d13bb0f523690729b82d5565343f40aaa8278aa3b6d`
  → `047c8b86d770496b3fdcdfad11ad14db8b59694f1734231b3f2e3130f20de277`
- South:
  `31c7eef5e3f461b97b116288274baa8bc5980ef711d45401645e2925ac326a48`
  → `02545716facbd61640033c44758632fdb3d47793d51f1d3ee6b1fef8559ccf69`

Both now bind the already accepted cohesion library:

- file:
  `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-east-v01/materials/industrial-l03-cohesion-east-v01.json`
- SHA-256:
  `f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65`

North and West descriptors are byte-identical to accepted candidate
`0aefb804c59b4ff9b919dc81fdca907cd4b85c5e`. East and South are structurally
identical to that candidate after excluding only `materialLibrary.file` and
`materialLibrary.sha256`.

## Manifest and pixel identity

- accepted manifest SHA-256:
  `8c9c2038993d1a9389342784d2bccc4d78cebdb7b063c3f741620d2cbeca8a09`
- repaired manifest SHA-256:
  `78fef5beed40229d0637ba74e85737c939bbaa460f42a17b49f24769e92704a1`
- raw PNGs byte-identical to `0aefb80`: `4/4`
- normalized run-A/run-B PNGs byte-identical to `0aefb80`: `24/24`
- normalized outputs: `12/12` unique file identities and `12/12` unique
  decoded-pixel identities
- repeat, alpha, chroma, padding, registration, and contact-shadow gates:
  `12/12 PASS`
- swapped valid-library binding: `REJECTED`
- wrong material hash: `REJECTED`

Machine proof:
`MATERIAL-BINDING-VALIDATION.json`
(`02ffc9c5cd932de24a7ad0e85af23ba1839d6d5c32a409a16fa27e6847595430`).

`sourceAuthority=false` and `productionSelected=false` remain unchanged pending
independent integration review.
