# PLAY-075 R2 candidate admission

## Product and carrier identity

- Required quality boundary:
  `74f2164da506a246af9335cab2d3a9e977624097`
- Candidate under test:
  `b4191d98ee7c526bc08a6fe272521588572e27fd`
- Shipping product:
  `a6000d1ac4c7ae8cca352ca7f55b000298a0058b`
- Accepted source:
  `5e019c3e7b7992cabeae179641a0f6748a971666`
- Merge carrier:
  `14fdd5cf848e6d5482831f7ec0e6705f018a3f2e`
- Carrier parents:
  `74f2164da506a246af9335cab2d3a9e977624097`
  and `b4191d98ee7c526bc08a6fe272521588572e27fd`
- Candidate-to-carrier `Native/CitySimNative` diff: empty
- Shipping-product-to-candidate product/build-script diff: empty

## Isolated staged identity

- Clone:
  `/private/tmp/citysim-play075-r2-b4191d9-build`
- Clone branch: `codex/citysim-playtest-quality-r2`
- Clone HEAD:
  `b4191d98ee7c526bc08a6fe272521588572e27fd`
- Candidate ID: `playtest-quality-r2-wc47ba2b1e1a5`
- Bundle/defaults:
  `com.jfmortensen.citysim.playtest-quality-r2.wc47ba2b1e1a5`
- Data root:
  `/private/tmp/citysim-play075-r2-b4191d9-build/dist/test-data/playtest-quality-r2-wc47ba2b1e1a5`
- Executable SHA-256:
  `60a1d7d65d3816fa9125cad4f9b525e35fff0baa86e4ff2653fe86e4e6b5ebba`
- Final staging-manifest SHA-256:
  `28b88ff989a5561e270044c0c67526f9de3e72fde7e308e7535d461d4e411362`
- Source/staged generated-v4 manifest SHA-256:
  `ee8f07b24eb5f12fab1790e7e7e3427f71a34c22213fc3be7f81b8d715cb6a99`
- Regular launch PID: `57726`
- Initial RSS: `78,000 KiB`
- Process disposition: terminated with `SIGTERM`

## Four directions x three LOD admission

All twelve normalized files were independently hashed from exact candidate
`b4191d98`; each actual digest matched the candidate manifest.

| Direction | City | Neighborhood | Block |
|---|---|---|---|
| East | `267a46e9b9b37267df8afb502d29f9974658c96b35d1f643f27697af80baf8bf` | `8c2cd50934e76b2783c56a3592d33023141741f492dae464e82ebc8636975222` | `f6504e6a86e80cba3d2b95838bee7721aba293257a8dc8040558944724046140` |
| North | `79e03aef3dbd414bc9e6b71a80aa4a641b616c72daff72a051799461087e6c2a` | `702311a8e7a282f8efad082e25a8f259ecb9559ae0fe978143fe877f52de919e` | `b50fa083d487163ab219e0409bf9cae9d5be3751d095a8ccd4e814190fdd603d` |
| South | `93852eda482d82c95853845c59c00e7e558d63ebf696f0e76f7246f67e796bdd` | `fcd547d862533944ff86ad79e84eb52e9e839ac69efba21157776ed7b1e9778a` | `150d89333d665ffc4417bad86eb7d6e46c89c4924492f196d820739a25bd78e4` |
| West | `ce880d5fa57a9f2ea9de48220b16b2353628badccd0d2035d33735b5e2b6f081` | `946b00d270d2d9c9f676605e621e32699c21604eb59e66e554395a6e601f2921` | `33125de6aa2a5ef8b2285e160b323d1886c6bc2b77ca5d151b15eac91ff800d9` |

- Four logical IDs, four accepted source keys, four frontage edges, and four
  view directions are present.
- All twelve L3 LOD hashes are unique.
- No L3 manifest object has alias, mirror, rotation, recolor, or fallback
  fields.
- The normalized L2 source/frontage/hash identity projection matches exact R1
  `d41c2c68` with SHA-256
  `650d2a6725fd1b826c3fe446708f6dd62944a9e4515c0680388330f862252634`.

## Fresh focused validator results

`validation/world-asset-pack-report.json`:

- passed: `true`;
- staged matches source: `true`;
- failures: `[]`;
- four pages;
- 216 payload digest checks;
- 216 extrusion checks;
- 6,472 packed-overlap checks;
- zero L3 anchor drift;
- 50,331,648-byte active-plus-next decoded high water.

`validation/production-geometry-report.json`:

- result: `pass`;
- failures: `[]`;
- 11,236 reciprocal-ground checks / zero collisions;
- 212 building-road setback checks / zero collisions;
- 820 entrance/prop exclusion checks / zero collisions;
- zero orphan or missing inventory references;
- 26,807,376-byte repeated-LOD high water.

These admission results prove exact packaging and bounded resources. They do
not substitute for the independent staged-app interaction disposition that
integration stopped before completion.
