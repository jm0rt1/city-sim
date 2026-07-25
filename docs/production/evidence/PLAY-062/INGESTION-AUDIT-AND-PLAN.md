# PLAY-062 renderer-lead ingestion audit and plan

**Audit baseline:** `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`

**Accepted source authority:** Industrial L1 variant-zero N/E/S/W source-v05
through clean PLAY-027 candidate
`79668c347e58d602f9627c73cb09e3272a83ef57`

**Current shipping manifest SHA-256:**
`c9351451928e035c0631b074d38fc55156325e5fcd19d3ebd4b104c5f90d8aa8`

**Scope:** production ingestion and runtime selection for Industrial L1
variant-zero N/E/S/W only. Industrial L2-L4, source-art repair, sibling
transforms, runtime mirroring or rotation, aliasing, camera-derived direction,
cross-family substitution, and shared gameplay/UI/save/package changes are not
authorized.

## Accepted four-source inventory

Every selected source is an independently authored 1536x1024 PNG under
`Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/industrial_l01/variant-0/<direction>/source-v05.png`.
The renderer audit rehashed these exact retained files and all twelve normalized
city/neighborhood/block payloads. All four raw hashes and all twelve normalized
hashes are unique.

| Frontage | Revision | Raw SHA-256 | City SHA-256 | Neighborhood SHA-256 | Block SHA-256 |
|---|---|---|---|---|---|
| north | `source-v05` | `5ca93afa57157ddf686ef5740f1907da03f513906b9c703bc556ed75e2516728` | `8134c56cb4ea3238fec85bf4b568eed0a2c8a0724695be16c105e057c3aa4583` | `d637c48c462942a6739434e3f8532291d5977bd6159da1bc9ca86a03648f3329` | `beba2ab0dbf920e0725ba7771f3c5288c02507c0b375bc8dd7940840dad8f13b` |
| east | `source-v05` | `f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f` | `a04aceca4ba2cd47b0b2fcbecb00d4dbf48fca8129c779bf6d27c825d8876d81` | `35803e7aa979aa9afecb134e457040e23fa58fdd51be18db4c4e010e3f470607` | `389407f132453db7c1cc5908c4732902f55577a1f999f9985d1eb0a9b9a6f84b` |
| south | `source-v05` | `f3588cf71e689055a2bd0a184262b24df0af8c4e41be1665af5c8eb6f8edca2e` | `4d0dcaa65bb8bbea8661f37f426441996e5d4e88de36fc2689bd28eb7ab8103d` | `0794afa8e0002f88ba01a4458800f7b0ae886b9a608d7064a3c7a0fc759da274` | `4c5228bdcf513c272b392e6175faa85327191b99433f81cd8c33b6e10a53020d` |
| west | `source-v05` | `9fa5759f88e2efd2f3eef36f66089f0e8e978dc4e052d08d919b9f1a40aa331a` | `be96b2aec303069741d625dd91620d6e29138ea6e4b6c9d3af98275cba8b6b9f` | `4fa100cfeb1abc0caecaf4cbd74ffa51abd0c521d9050a76ec2e1a4cbbf4a025` | `04a2963a211d4b7ae5ac4fa8ddbb88c46dbe18cc7b4685bf67c9167dc8bda9da` |

Each accepted provenance record declares `orientationTransform: none` and
`authoredIndependently: true`. Each scene descriptor declares the fixed 2:1
projection, 1x1 footprint, shared ground pivot, zero rotation/mirroring, and a
direction-specific frontage socket and entrance. The retained normalized bytes
are the only authorized packing inputs; PLAY-062 will not run a normalizer over
them or alter source pixels.

## Shipping gap

- The generated-v4 shipping manifest still contains one fixed legacy
  `industrial_l01` identity rather than the four accepted directional
  identities.
- Completed Industrial L1 tiles therefore cannot select architecture from an
  authoritative adjacent-road frontage.
- The existing deterministic packer and runtime selection paths cover
  Residential and Commercial but not Industrial L1.
- Power plants and any Industrial level above L1 remain outside PLAY-062 and
  retain their prior renderer behavior.

## Bound implementation

1. Add a PLAY-062 selection catalog containing exactly the four source-v05
   revisions, four raw hashes, and twelve normalized LOD hashes.
2. Extend the deterministic generated-v4 pack path to emit only
   `industrial_l01_v0_{north,east,south,west}` for Industrial L1. Reject missing,
   altered, mirrored, rotated, transformed, or cross-family inputs before
   packing.
3. Preserve stable shelf order, no page rotation, four-pixel padding,
   two-pixel extrusion, registration, alpha, source provenance, and
   byte-identical clean builds.
4. Resolve Industrial L1 presentation from authoritative tile level plus a real
   adjacent road edge. Multi-road priority remains south, north, east, west;
   roadless Industrial L1 emits a bounded explicit missing-identity diagnostic.
5. Use the same authoritative edge for the authored frontage and architecture.
   Camera, zoom, pointer location, render order, and local presentation state
   never choose direction.
6. Preserve construction, condition, selection, preview, overlays, Focus City,
   Reduce Motion, pointer/keyboard/AX behavior, public realm, and unchanged-pulse
   reuse.

## Verification and proof

- Exact four-key Industrial L1 matrix, four unique source keys/raw hashes,
  twelve unique normalized hashes, and disjoint bytes from Residential and
  Commercial; no alias, transform, or fallback path.
- Two clean pack builds with byte-identical pages/manifests, complete
  source/staged digest parity, alpha/padding/extrusion/pivot/socket/entrance and
  production-geometry validation at city, neighborhood, and block LOD.
- Exhaustive N/E/S/W runtime resolution, roadless explicit failure, and stable
  identity through pulse, save/load, undo, camera, and LOD changes.
- Staged regular and exact 900x600 proof for construction, condition, selection,
  preview, every overlay, Focus City, undo, save/load, Reduce Motion, pointer,
  keyboard, and accessibility.
- Color and grayscale Industrial-versus-Residential-versus-Commercial
  distinction, road/lot overlap checks, residency, RSS, fallback, and
  world-update/decode/total timing disclosure.

No shared contract proposal is required. The accepted manifest-v4 descriptor
shape, authoritative tile level, adjacent-road mask, and staged resource
packaging already cover this exact ingestion.
