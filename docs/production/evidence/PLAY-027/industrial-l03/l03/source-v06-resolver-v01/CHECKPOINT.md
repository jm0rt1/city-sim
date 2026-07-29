# PLAY-027 Industrial L3 source-v06 resolver checkpoint

- Disposition: `PASS_ZERO_PIXEL_RESOLVER_GATE`
- Published authority: `79ff3924f912c3aaa0d160a58364e5583f4082be`
- Accepted pre-pixel ancestor:
  `9126331532adb6d0a34bf5cddd7cdb4b0c15a48a`
- Logical key: `industrial_l03/variant-0/source-v06`
- Authorized directions: North and West only
- Source authority: `false`
- Family authority: `false`
- Production selected: `false`

The task-owned sampling resolver now admits only the exact North and West
source-v06 descriptor, geometry, material-library path, material-library hash,
schema-2 v3, source-authority, no-MSAA, disabled-shadow, authored-constant
identities published by integration. East, South, swapped libraries, and every
mutated identity or sampling field fail closed.

## Frozen inputs

| Direction | Descriptor SHA-256 | Material SHA-256 | Geometry ID |
|---|---|---|---|
| North | `adc73af1704c067d75f62b818d9a6ee7da6c7ff87637356552ef72393f8c77a9` | `2a9c9fa964f6135207b7ab4bbdea37f343ebd7ac0e14cc0356ece643616d3fc8` | `industrial-l03-north-v06-open-loading-court` |
| West | `d4affd0773c557056cf15b56db66dfb76736658a995df68cdd86a48b84178f4f` | `928c5dc9963b3a67e5e4cd9e48033ec11efbc8d8aa9f32eb45f0730b8e2e3faf` | `industrial-l03-west-v06-open-loading-court` |

## Validation

- `RESOLVER-VALIDATION.json`: 2/2 positive cases and 15/15 negative
  cases pass, including swapped-library and source-v06 East/South rejection.
- `SOURCE-V02-V05-REGRESSION.json`: 12/12 retained source-v02 through
  source-v04 descriptor/effective-contract cases and 2/2 source-v05
  North/West cases reproduce; 12/12 source-v05 negative cases remain closed.
- Both validators and the complete offline renderer compile with
  `-parse-as-library -warnings-as-errors`.
- Resolver validator source SHA-256:
  `28d2f780d3f54c6a0e0dd7f0f0ad412ee647f21e99d3f57d103e9ff06fd7bfdc`.
- Renderer architecture SHA-256:
  `ef6e0a5a808c9b4e716e378ae39149458a44befbbb022c2e817de6b59628130e`.
- Resolver validator binary SHA-256:
  `4748a6775ae3c109919c89d42685bd7b87a54add9763b4c1ff0511ad2c21ccfd`.
- Regression validator binary SHA-256:
  `538876e3fa858d9486fdcc39970ad96b2181b1a93479e2ffeb3e4b4852f820cc`.
- Offline renderer binary SHA-256:
  `4a468ffcf250ae4c48440b2232cbce61181f969f741d79d9059c1bfb263844fd`.
- Resolver validation report SHA-256:
  `f2eaaa169f19686aeb0f9a66005a6e7a2a2cce5a12fe6d58dbbd2e59f6bb110c`.
- Source-v02–v05 regression report SHA-256:
  `cab4471636db40242a0238b7c25ae98bcd1292233a525c550017f9205ea25ac3`.

No descriptor, material library, raw PNG, normalized PNG, renderer CLI,
shipping resource, package, shared manifest, or production-selection file
changed. This checkpoint records zero SceneKit, Metal, raw-render, and
normalizer processes.
