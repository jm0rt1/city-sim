# PLAY-027 Industrial L1 source-v05 normalized batch gate

Disposition: **PASS — review candidate evidence, not source-art acceptance**

The approved one-process source-v05 probe was rendered in two additional fresh
native SceneKit processes per direction and normalized twice through the
descriptor-bound schema-2 v3 pipeline. No source-v05 scene geometry changed
after the approved probe.

## Determinism and uniqueness

- Raw A/B/C file identity: 4/4 directions pass.
- Raw A/B/C decoded-pixel identity: 4/4 directions pass.
- Unique raw primary file identities: 4/4.
- Normalized primary/repeat file identity: 12/12.
- Unique normalized primary file identities: 12/12.
- Unique normalized primary decoded-pixel identities: 12/12.

| Direction | LOD | Primary and repeat SHA-256 |
|---|---|---|
| North | block | `beba2ab0dbf920e0725ba7771f3c5288c02507c0b375bc8dd7940840dad8f13b` |
| North | neighborhood | `d637c48c462942a6739434e3f8532291d5977bd6159da1bc9ca86a03648f3329` |
| North | city | `8134c56cb4ea3238fec85bf4b568eed0a2c8a0724695be16c105e057c3aa4583` |
| East | block | `389407f132453db7c1cc5908c4732902f55577a1f999f9985d1eb0a9b9a6f84b` |
| East | neighborhood | `35803e7aa979aa9afecb134e457040e23fa58fdd51be18db4c4e010e3f470607` |
| East | city | `a04aceca4ba2cd47b0b2fcbecb00d4dbf48fca8129c779bf6d27c825d8876d81` |
| South | block | `4c5228bdcf513c272b392e6175faa85327191b99433f81cd8c33b6e10a53020d` |
| South | neighborhood | `0794afa8e0002f88ba01a4458800f7b0ae886b9a608d7064a3c7a0fc759da274` |
| South | city | `4d0dcaa65bb8bbea8661f37f426441996e5d4e88de36fc2689bd28eb7ab8103d` |
| West | block | `04a2963a211d4b7ae5ac4fa8ddbb88c46dbe18cc7b4685bf67c9167dc8bda9da` |
| West | neighborhood | `4fa100cfeb1abc0caecaf4cbd74ffa51abd0c521d9050a76ec2e1a4cbbf4a025` |
| West | city | `be96b2aec303069741d625dd91620d6e29138ea6e4b6c9d3af98275cba8b6b9f` |

## Decoded-pixel and registration gates

- Opaque chroma pixels: 0 in all 12 normalized outputs.
- Visible magenta-spill pixels: 0 in all 12 normalized outputs.
- Transparent pixels retaining hidden RGB: 0 in all 12 normalized outputs.
- Alpha bounds and required canvas padding: pass in all 12 normalized outputs.
- Source ground pivot: exact `[768, 896]` in all four directions.
- Source frontage sockets: exact North `[896, 704]`, East `[896, 832]`,
  South `[640, 832]`, and West `[640, 704]`.
- World entrance bases: exact North `[0, 2, -28]`, East `[28, 2, 0]`,
  South `[0, 2, 28]`, and West `[-28, 2, 0]`.
- Shadow vector: exact `[2, 1]`; receiver remains the task-owned transparent
  ground plane.
- Normalized registration uses object width `410`, reference width `234`,
  target pivot `[768, 896]`, and every output's retained object bottom
  terminates at the target pivot row.
- `orientationTransform` remains `none`; `productionSelected` remains `false`.

Machine-readable authority:

- `validation/NORMALIZED-UNIQUE.json`
- `validation/REGISTRATION-AND-NORMALIZATION-V05.json`
- `validation/NORMALIZED-REPEAT-<direction>-<lod>.json`

This checkpoint authorizes review packaging only. It does not authorize
Industrial L2, renderer ingestion, shipping selection, or source acceptance.
