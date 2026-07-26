# PLAY-027 Industrial L3 source-v05 North/West resolver checkpoint

Disposition: **PASS — zero-pixel resolver boundary**

- Scope: exact `industrial_l03/variant-0/source-v05/{north,west}` only.
- Purpose/contract: `source-authority` under `play027-deterministic-4x-no-msaa-lanczos-v3`.
- Required effective settings: SceneKit antialiasing `none`, SceneKit shadows `disabled`, lighting `authored-constant-v1`.
- Bound geometry:
  - North: `industrial-l03-north-v05-open-loading-court`
  - West: `industrial-l03-west-v05-open-loading-court`
- Bound descriptor SHA-256:
  - North: `a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61`
  - West: `56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc`
- Renderer architecture SHA-256:
  - before: `491f0e9457df78ede8662ad1a32a4173d1bfcf49dea429b2a75a24d12b644ee4`
  - after: `648760644e6987be56076910af2a702e713be1f7673203f2757e38a28fa6d00e`
- Validator source SHA-256: `a215ff56bcae2ec1b5f2960f901c96160db55249073fc8df0fdda4e677d02d34`
- Legacy effective-contract baseline SHA-256: `82028e4bf33ee996141a243580eec2dafaa50f0d374b4f65c8da1ce850e964ca`
- Full validation report SHA-256: `4ea61379abf5dc09e9671664aff850ca1a6ae3063232c06712940c8429971bf9`

Validation passed:

- 2/2 exact positive descriptors resolve.
- 12/12 mutations fail closed, including direction, variant, revision, binding, geometry, purpose, contract, lighting, shadows, antialiasing, and source-v05 East/South.
- All 12 Industrial L3 v02/v03/v04 descriptor files retain their committed SHA-256 values.
- All 12 retained effective-contract records are byte-identical to the pre-change baseline.
- Existing Industrial L3 and Industrial L2 sampling capability tests compile with warnings as errors and pass.
- SceneKit, Metal, raw-render, and normalizer process counts are all zero.

No descriptor, geometry, material, raw, normalized, renderer CLI, product runtime, shipping, package, or shared-manifest surface changed. `sourceAuthority=false` and `productionSelected=false` remain binding. The next authorized boundary is the six-process North/West raw review gate.
