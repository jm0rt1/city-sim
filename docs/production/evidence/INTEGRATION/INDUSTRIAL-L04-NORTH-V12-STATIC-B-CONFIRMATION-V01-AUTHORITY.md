# Industrial L4 North v12 static-B confirmation v01

**Owner:** Integration
**Task:** PLAY-027
**Branch:** `codex/citysim-world-art`
**Published input candidate:** `28103902a75c8232644a998a34dcaf33ca643a63`

## Purpose

North v12's module-bootstrap recovery succeeded once at static geometry. This
authority opens exactly one fresh, no-render `static-b` child to prove that the
lowered Blender scene is deterministic before any rendered Process A.

This is not source-art acceptance, an appearance lock, pixel authority, sibling
release, Renderer admission, production selection, or shipping authority.

## Frozen inputs

| Input | SHA-256 |
|---|---|
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/SCENE.json` | `dad20722f4770c82992040861074188c604b46cd226e5f739291ac22683594e2` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/MATERIALS.json` | `e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json` | `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/lower_v12_scene.py` | `7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/import_v12_scene.py` | `ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988` |
| accepted static-A recovery contract | `af55da8df7b5152c361c9e23ca9c3c5ad5b2231c62609add8b1b10712b30daef` |
| accepted static-A module-bootstrap launcher | `375b1ad679a99c683fd06e50227737fb48198f1899ea6a8f0d269eda9f289f3e` |
| accepted static-A focused test | `5c77cdee1621cc5a9ae3cba0124acff34da663e9e3386fdd46a73895d0352977` |
| accepted static-A prelaunch receipt | `59e6539d03afd4c04f7926327da5cf3614357c1a8936f9fa5edbee8150908aea` |
| accepted static-A object manifest | `213ab497191808992b70459dcae25aa3ebd9a902c094a6fc225a24e57b0a5d69` |
| accepted static-A input bindings | `ee3691ffc5a8a817d35913e4359a66f0efb12042ab505f1f95b2b2c9c7bd3e1c` |
| accepted static-A material manifest | `c66bc0796c57581dc4dac629b6947b0d5ab4a515213165b8c8d5fcc992d80e88` |
| accepted static-A projection | `b5e1d6d88e03b940fb20725ddb8b18dce9ce52a6b72f332975f76f8bed79c11e` |
| accepted static-A topology | `8ad251808663f3daac85af7a0df388306f790af017e4e6d9b93ee3f7e9e51c8f` |
| accepted static-A validation | `9250eb7a26659e9c91c3a0debb9ad6de8be78d104e1cbd15ebfba6d3ed755ff2` |

The Blender executable must remain the recorded 4.5.12 LTS binary at SHA-256
`8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4`.

## Exclusive owned paths

The worker may add only:

```text
Native/CitySimNative/WorldArt/Blender/PLAY-027/
  industrial-l04-north-art-v12/blender-lowering-v01/
    static-b-confirmation-v01/

docs/production/evidence/PLAY-027/industrial-l04/l04/
  blender-north-art-v12/blender-lowering-v01/
    static-b-confirmation-v01/
```

The first root may contain one immutable contract, launcher, focused tests, and
prelaunch receipt. The second may contain only `static-b` process outputs,
provenance, exact A/B comparison, validation, and handoff evidence.

## Execution lease

- Global DCC cap: one simultaneous Blender child.
- Assigned slot: `dcc-1`.
- Attempt: `industrial-l04-north-v12-static-b-confirmation-v01`.
- Process ID: `static-b`.
- Maximum child starts: one.
- Execute only after a committed prelaunch gate proves the branch, claim,
  published authority, exact frozen hashes, absent output root, fixed child
  argv, timeout/RSS limits, repository mutation guard, and render-disabled
  configuration.
- A child start consumes the lease whether it succeeds or fails.
- The external dispatch must bind and verify PLAY-027 claim SHA-256
  `0682813bda079ddb291f3966d76fa83ef31998bfe5abdf9df4e3a849272c3f36`,
  the exact publication commit, and this authority's exact post-publication
  SHA-256 before any mutation.
- The new contract and launcher may differ from accepted static A only in
  authority, attempt, process-ID, and output-root bindings. Preserve the exact
  module-bootstrap expression, Blender argv, importer/lowerer, monitoring,
  dependency and repository scans, inventory rules, timeouts, and RSS limits.
- On failure, preserve the immutable partial child subset plus one exclusive
  `FAILURE.json`, commit that failure, and stop. Do not add comparison or
  handoff evidence, retry, or start another child.

## Required confirmation

The fresh `static-b` result must independently reproduce:

- 50 physical components;
- 47 semantic Blender objects;
- 14 materials;
- 315 mesh polygons;
- zero bevel modifiers;
- zero non-manifold edges;
- zero retained internal same-owner face area;
- maximum registration error no greater than `0.001` source pixel; and
- the same normalized object, material, projection, topology, and registration
  signatures as accepted static A; and
- byte-identical equality with the explicitly named accepted static-A
  `BLENDER-OBJECT-MANIFEST.json`, `INPUT-BINDINGS.json`,
  `MATERIAL-MANIFEST.json`, `PROJECTION.json`, `TOPOLOGY.json`, and
  `VALIDATION.json` files at their hashes above.

Do not normalize or exclude fields from those six run-neutral files. Retain a
machine-readable byte/hash comparison. Exclude only
`PROCESS-PROVENANCE.json` from byte identity because it is process-bound.

## Hard stop

No render invocation, pixel, `.blend`, normalization, Process A/B/C,
appearance lock, East/South/West source process, source admission, Renderer
quarantine, runtime activation, shipping mutation, push, or self-acceptance is
authorized. Return clean after the one child and its durable evidence commit.
