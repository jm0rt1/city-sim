# PLAY-027 Industrial L3 source-v05 resolver authority

- Exact accepted pre-pixel candidate:
  `9d32ec2df9b3b7eb7cee0205970e3cc6580d7d68`
- Integration disposition: `APPROVE_NARROW_RESOLVER_ADDITION`
- Authorized logical key: `industrial_l03/variant-0`
- Authorized revision: `source-v05`
- Authorized directions: North and West only
- Sampling contract:
  `play027-deterministic-4x-no-msaa-lanczos-v3`
- Sampling purpose: `source-authority`
- SceneKit antialiasing: `none`
- SceneKit shadows: `disabled`
- SceneKit lighting: `authored-constant-v1`
- Raw-process authorization: unchanged from the published North/West raw
  authority
- Normalization authorization: `false`
- Source authority: `false`
- Production selected: `false`

The approved North/West pre-pixel descriptors fail closed before SceneKit
because the task-owned sampling resolver enumerates Industrial L3
`source-v02`, `source-v03`, and `source-v04`, but not the new `source-v05`
frontage revision. This is an authority-list omission. It is not permission to
change the sampling algorithm, descriptor, authored geometry, materials,
camera, renderer, shipping product, or any other source family.

## Exact descriptor bindings

The validator must read the committed descriptors from these exact paths and
reject any SHA-256 mismatch before calling the resolver:

| Direction | Descriptor path | SHA-256 | Scene geometry ID |
|---|---|---|---|
| North | `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-frontage-v01/scenes/industrial_l03/variant-0/north/scene.json` | `a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61` | `industrial-l03-north-v05-open-loading-court` |
| West | `Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l03-cohesion-frontage-v01/scenes/industrial_l03/variant-0/west/scene.json` | `56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc` | `industrial-l03-west-v05-open-loading-court` |

The resolver may add one narrowly named predicate that requires all of:

- logical building `industrial_l03`;
- variant `variant-0`;
- revision and revision binding `source-v05`;
- direction North or West;
- the corresponding exact scene geometry ID above;
- schema 2, the existing v3 contract, and `source-authority` purpose; and
- the already frozen no-MSAA, disabled-shadow, authored-constant sampling
  values.

It may then include only that predicate in the existing authored-constant and
disabled-shadow allow lists. Do not authorize source-v05 East/South, another
variant, another family, diagnostic purpose, a different scene geometry ID,
or a different sampling contract.

## Required fail-closed proof

Before any raw process, commit a clean task-owned resolver checkpoint proving:

1. both exact descriptor files retain the hashes above and resolve to the
   existing v3 effective contract;
2. mutation of direction, variant, revision, revision binding, geometry ID,
   purpose, contract ID, lighting, shadows, or antialiasing is rejected;
3. Industrial L3 source-v05 East and South are rejected;
4. the existing Industrial L3 source-v02/source-v03/source-v04 descriptors
   retain their pre-change file identities and resolve to byte-for-byte
   equivalent effective-contract records; and
5. no descriptor, raw, normalized, renderer, shipping, package, or shared
   manifest surface changes in the resolver checkpoint.

The hash gate belongs in the task-owned validation tool because the resolver
receives a decoded descriptor rather than source-file bytes. Do not add a
misleading in-memory file-hash assertion to the resolver.

After the clean resolver checkpoint passes, the published raw authority at
`INDUSTRIAL-L03-NORTH-WEST-RAW-AUTHORITY-9d32ec2.md` resumes automatically:
render exactly three fresh North processes and three fresh West processes,
assemble the required actual-pixel review packet, commit one clean candidate,
and stop before normalization.
