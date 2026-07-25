# PLAY-062 deterministic pack identity

- Exact product: `02612e414912fdabcab858b0ca97e1f5edbc2757`
- Bundled interpreter:
  `/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
- Builder:
  `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`
- First fresh output: `/private/tmp/play062-build-one.5iaAIz/WorldAssets.atlas`
- Second fresh output: `/private/tmp/play062-build-two.9siw8y/WorldAssets.atlas`
- Recursive `diff -qr` between fresh outputs: no differences
- Every fresh generated file compared with its committed production counterpart:
  no differences
- Source/staged parity validator: `staged_matches_source: true`

| Generated file | SHA-256 |
|---|---|
| `generated-v4-manifest.json` | `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8` |
| `pages/block/page-00.png` | `90aeb2c8e56bfc95d8279581ebee60f3dc692e45407aff4e364a0ba087bbff1a` |
| `pages/block/page-01.png` | `9c8c5fa6dce3b31b89ded5a7cac0c3dad822c74092d48c197b3b6c28b3b2d4dc` |
| `pages/city/page-00.png` | `7f3ce7f818f49dedabca13046e7f01e837e5d0dd4d12456ee0a9732dcad8e964` |
| `pages/neighborhood/page-00.png` | `2e35efbac673adb8d8297700c7129dbfc5cb5cc9226149b062bd30011defbef0` |

The builder consumed the exact retained normalized Industrial L1
`source-v05` bytes. It did not invoke image generation or normalization,
change accepted source art, mirror, rotate, recolor, synthesize, or alias a
sibling.
