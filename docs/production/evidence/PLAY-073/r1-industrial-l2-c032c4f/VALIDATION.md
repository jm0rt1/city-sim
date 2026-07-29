# PLAY-073 R1 Industrial L2 validation

## Candidate identity

- Published authority: `10c2ed8cacc6c14a748aa953365b5779c7e06ad5`
- Accepted Phase A ancestor:
  `41ad1eee9d1431a4962a7af6ed4fa85ceea0fedd`
- Independently approved source ancestor:
  `e2a6144448707c67792e6e0619d5e8dee1ba10bb`
- Shipping product: `c032c4f2e7f73a339ec4d1b1898cc2ece1f746d7`
- Offline validator adoption:
  `8fdb122` (no executable, resource, or rendered-pixel delta)
- Branch: `codex/citysim-world-rendering`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged executable SHA-256:
  `45808a460fa5e4ca86d7510f538f591f11847d935973ee4fe368f6cd9ca5947c`
- Staging manifest SHA-256:
  `9ea6c587d92a95bdc3d2c78b27ac54cde7b2518764c6f31ff880f5548eb6bd63`
- Source and staged generated-v4 manifest SHA-256:
  `1f4e9961ecb8ade54d2bb169721d11ca337e2f61053c72078a5e6bf71d59480b`

`./script/build_and_run.sh --verify` passed once from the exact shipping
product. The staged app loaded the packaged
`CitySimNative_CitySimNative.bundle/WorldAssets.atlas`; the validator reports
`staged_matches_source: true`.

## Exact Industrial L2 inputs

The selection catalog SHA-256 is
`ab5a7bd7d6a1de3359167be732e32bb13f4b253ac11ef0fae1d81154d63fe2e2`.
Every shipping input is the approved run-a normalized byte sequence.

| Direction | Raw source | City | Neighborhood | Block |
|---|---|---|---|---|
| North v07 | `095267c78f333eb43c3fd0e14c4e9bb14bb83a787188ddecfa9c94dd92ab88e3` | `60969ffb594fee16efa1114e75edf6dcb5e57c4041c1c8019c1796d7a7ff8b0a` | `76d1d302d8b1dfaa41ca799bbce5bf5ae4bee9754091e08a31eb1c0c0c6c7736` | `c539f4478296e929fb77250ad8476572e7b8155ad96abd2ebebe3170b052debc` |
| East v05 CONTRACT-018 master | `a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8` | `861db1d52b55f82c70f51a31c606baa063092127384c66703b89d4cdfa79372c` | `c229dfa0759fa7232786eee92fcdd6786cd1d13728fb09b8aa9b39b30d49ed93` | `54e3e6c8f07f50af8bab56dd8d46923b8bdc70c6e7929ff45ee514d1fbea6086` |
| South v07 | `b3cafd821e29980a86a6d74f562a2ad97d5f877b4106f746aaa88bc19d9922a5` | `b70085caaef5045df7289364d34f983054bc3b80d991ddb9507e9654ac1abbc3` | `976b998aa14adb1f040651616b31c5bc2e0ead77fb388054d7bf04b1d863dceb` | `c98e9b56a5705613a482b4ca249b4cb2b23a74fd6123638fc8282e7e8e5ba6f7` |
| West v07 | `6132d867c7ba6f2d9e0013c593ea75024ad45c546549d9e094b7663309ed155d` | `3853833738f2d2660ad9abe01cdee98f35ce6a80aa0a21f8afcd3f837fed9f8b` | `f0a3732a12672f91c023126bdc55b09c11acd2735930900b17c1106216858823` | `4c66e3d326606838bb484beef0a685cbf73d38d2e127572bd19be8e0c83077dd` |

The generated path contains no runtime mirror, rotation, recolor, sibling
alias, cross-family substitution, or silent fallback. Industrial L3/L4 remain
unshipped.

## Deterministic pack and geometry

The fresh `/private/tmp/play073-r1-pack-b` build and the independently rebuilt
canonical atlas produced byte-identical generated-v4 manifests and pages.
Legacy rollback files intentionally exist only in the canonical atlas.

| Generated file | SHA-256 |
|---|---|
| `generated-v4-manifest.json` | `1f4e9961ecb8ade54d2bb169721d11ca337e2f61053c72078a5e6bf71d59480b` |
| `pages/block/page-00.png` | `efc1abd9f91a2821e2c013736781dc12561f972c56d0bd4b1f71c860da93fd5b` |
| `pages/block/page-01.png` | `5191f34f50cddfa9e2a57b2d10089f1c4d7e4d563b36bbff28a2d495a8349566` |
| `pages/city/page-00.png` | `29b84a3c928909bfb4511c7a821062b16e53d3ffbde4cd747510e4e03412bee9` |
| `pages/neighborhood/page-00.png` | `c158f10745008365e8bab4397049e517e6e219cddaa9b67bccbdefc0ca5ccdb8` |

The retained pack report passes with:

- four pages;
- 8 Industrial L1/L2 identities and 24 unique Industrial LOD hashes;
- 204 payload digest checks;
- 204 extrusion checks;
- 5,727 packed-overlap checks;
- zero anchor drift and zero failures; and
- 50,331,648-byte active-plus-adjacent high water.

The retained geometry report passes with:

- 9,604 reciprocal-ground checks / zero collisions;
- 196 building-road setback checks / zero collisions;
- 756 entrance/prop exclusion checks / zero collisions;
- zero orphan/missing inventory references; and
- 25,682,880-byte repeated-LOD decoded high water.

The first geometry invocation correctly exposed that its old package-only
resolver could not locate immutable repo-root `docs/...` source paths.
`8fdb122` adds the same bounded package-or-repository resolution already used
by the pack builder; the single repaired rerun passed.

## Focused renderer gate

`swift test --package-path Native/CitySimNative --filter WorldRenderingTests`
passed **66/66** in 47.121 seconds.

Focused coverage proves all 4 directions x 3 LOD lookups, authoritative
frontage and deterministic multi-road priority, stable identity through
unchanged pulses/save-load/condition restore/Undo/camera/LOD, construction and
condition presentation integrity, explicit roadless/L3+ rejection, selection
and overlay neutrality, Reduce Motion action suppression, and zero fallback.

Latest retained diagnostics:

- cold world update: 4.561 ms;
- cold total render: 7.763 ms;
- unchanged-pulse soak: 4,286 pulses at 0.0007 ms average;
- city: 1,823 nodes / 890 drawables;
- compact neighborhood: 1,843 nodes / 904 drawables;
- generated residency high water: 50,331,648 bytes;
- actions: 3 normal / 0 Reduce Motion lifecycle actions; and
- fallbacks: 0.

Per the R1 fast cadence, the worker did not duplicate the full integration
suite. Integration owns the single full-suite and staged identity gate.
