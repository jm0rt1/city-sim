# PLAY-027 Industrial L3 source-v06 resolver and raw authority

- Exact accepted pre-pixel candidate:
  `9126331532adb6d0a34bf5cddd7cdb4b0c15a48a`
- Integration disposition:
  `ACCEPT_PREPIXEL_AUTHORIZE_HASH_BOUND_RESOLVER_AND_RAW`
- Logical key: `industrial_l03/variant-0`
- Authorized revision: `source-v06`
- Authorized directions: North and West only
- Raw processes: exactly three fresh processes per direction
- East/South: immutable
- Normalization: `false`
- Source authority: `false`
- Family authority: `false`
- Production selected: `false`

Independent integration review accepts the direction-scoped source-v06
pre-pixel checkpoint. Semantic diffs, structural replay, frontage, footprint,
pivot, socket, registration, bounds, sampling contract, native/enlarged
swatches, direction-scoped library identity, and swapped-library rejection all
pass. The packet used zero SceneKit, raw, and normalizer processes.

## Exact source bindings

| Direction | Descriptor path | Descriptor SHA-256 | Scene geometry ID |
|---|---|---|---|
| North | `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/scenes/industrial_l03/variant-0/north/scene.json` | `adc73af1704c067d75f62b818d9a6ee7da6c7ff87637356552ef72393f8c77a9` | `industrial-l03-north-v06-open-loading-court` |
| West | `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/scenes/industrial_l03/variant-0/west/scene.json` | `d4affd0773c557056cf15b56db66dfb76736658a995df68cdd86a48b84178f4f` | `industrial-l03-west-v06-open-loading-court` |

| Direction | Material-library path | Material-library SHA-256 | Library ID |
|---|---|---|---|
| North | `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/materials/industrial-l03-source-v06-north.json` | `2a9c9fa964f6135207b7ab4bbdea37f343ebd7ac0e14cc0356ece643616d3fc8` | `industrial-l03-source-v06-north` |
| West | `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-source-v06-v01/materials/industrial-l03-source-v06-west.json` | `928c5dc9963b3a67e5e4cd9e48033ec11efbc8d8aa9f32eb45f0730b8e2e3faf` | `industrial-l03-source-v06-west` |

The task-owned validator must verify the retained file hashes above before
calling the resolver. It must also verify that each descriptor declares the
matching direction-scoped material path and hash and that the retained
material file matches that declared hash.

## Resolver addition

Add one narrowly named source-v06 predicate that requires all of:

- logical building `industrial_l03`;
- variant `variant-0`;
- source revision and revision binding `source-v06`;
- direction North or West;
- the corresponding exact scene geometry ID above;
- the corresponding direction-scoped material path and SHA-256 above;
- schema 2;
- sampling contract
  `play027-deterministic-4x-no-msaa-lanczos-v3`;
- sampling purpose `source-authority`;
- SceneKit antialiasing `none`;
- SceneKit shadows `disabled`; and
- SceneKit lighting `authored-constant-v1`.

Include only that predicate in the existing authored-constant and
disabled-shadow allow lists. Do not authorize source-v06 East/South, another
variant, another family, diagnostic purpose, a different geometry ID, a
different library, or a different sampling contract.

Before any raw process, commit one clean resolver checkpoint proving:

1. both exact descriptors and material libraries resolve to the v3 effective
   contract;
2. North and West each resolve only with their own material path and hash;
3. swapped libraries fail closed;
4. mutation of direction, variant, revision, revision binding, geometry ID,
   purpose, contract ID, lighting, shadows, antialiasing, material path, or
   material hash fails closed;
5. source-v06 East/South fail closed; and
6. Industrial L3 source-v02 through source-v05 retain their pre-change file
   identities and effective-contract records.

No descriptor, material, raw, normalized, renderer, shipping, package, or
shared-manifest file may change in the resolver checkpoint.

## Raw gate

After the clean resolver checkpoint, render exactly three fresh processes for
North and exactly three for West. Retain all three raw files and provenance
records per direction.

Required repeat identity:

- North A/B/C must be byte-identical and decoded-RGBA-identical;
- West A/B/C must be byte-identical and decoded-RGBA-identical.

Because the source-v06 descriptors and libraries are semantic promotions of
the selected passing diagnostics, also require:

- North raw file SHA-256 exactly
  `91b3fb983e294eeff288b13f6d89a19366393cfaf084b52527633e88ed0507ea`;
- North decoded-RGBA SHA-256 exactly
  `ca087fb06b5bcc67ea101f661ac07a5a1b263d5b3b32db4d1c6d8aa7d18764af`;
- West raw file SHA-256 exactly
  `ceaa2948be0f37cbd8f6288c9c125f15502a864ce683bc3eaa1cd0d7563477d4`;
- West decoded-RGBA SHA-256 exactly
  `f66b4fe3cde165e0c3852ce5aa0863ec7380824f46e81708804428b6717be310`.

Any mismatch is a hard stop before normalization.

The retained raw-review packet must also prove:

- complete occupied bounds, alpha visibility, zero hidden RGB, and no clipped
  footprint, plant volume, loading face, staff entrance, or contact shadow;
- two complete dark loading-bay rectangles plus a separate readable staff
  entrance in each actual SceneKit raw and actual-scale compact preview;
- preserved road socket, door-base midpoint, pivot, footprint, height, light,
  shadow, warm/dark material roles, and Industrial L3 family identity;
- unique North and West raw identities with no alias against immutable accepted
  East/South or the accepted catalog; and
- source-scale color/grayscale, occupied crop, native-2x, actual-scale compact,
  and four-direction comparison panels derived from retained bytes.

Commit one clean raw-review candidate and stop. Do not normalize, alter
East/South, touch renderer or shipping surfaces, begin L4/A2, push, or
self-accept.
