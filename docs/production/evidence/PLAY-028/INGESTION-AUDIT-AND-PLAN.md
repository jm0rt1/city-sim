# PLAY-028 renderer-lead ingestion audit and plan

**Audit baseline:** `1d4d4f7eba1bb1cf3c8d64b1c221f33d3be91637`

**Accepted source authority:** Residential L1 at
`6380037d42ede73eca60aac4a9b1c7b710f681d6`; Residential L2-L4 at
`8f928ed5dd01453ff9d4d9910858d8bf786afa9d`

**Current shipping manifest SHA-256:**
`ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72`

**Scope:** production ingestion and runtime selection for Residential
variant-zero L1-L4 N/E/S/W only. No source-art mutation, sibling transform,
runtime mirroring/rotation, alias, camera-derived direction, or cross-family
substitution is authorized.

## Accepted 16-source inventory

Each selected source is an independently authored 1536x1024 PNG under
`Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/<logical-id>/variant-0/<direction>/<revision>.png`.
The adjacent provenance record, scene descriptor, normalization record, and
three normalized LOD PNGs are retained inputs. Hashes below are the verified
raw-file SHA-256 values.

| Logical ID | Frontage | Revision | Raw SHA-256 |
|---|---|---|---|
| `residential_l01` | north | `source-v12` | `c2eb31e53dd00b6da1afa5940169931c48e3e9e7c6b746de7d26f3c326dc7b02` |
| `residential_l01` | east | `source-v08` | `f2bb3860470f7202ac3398d7d459259745de05c3f9c0462bf8f694a1091109b2` |
| `residential_l01` | south | `source-v08` | `01896e22f790bd0d44a80db716f77b9221c3e283b78a2b89609822574bbae0b1` |
| `residential_l01` | west | `source-v09` | `8bb0a794259a7afd65e8427e68d65ab21dca74d46ff418aa74737cbdeeeaeaca` |
| `residential_l02` | north | `source-v05` | `c79c5e0906c2e2b3c25682d6f79824d4e0d52e3be1821ba62f69fc6139656f6e` |
| `residential_l02` | east | `source-v05` | `d985175f7e31681343108df3e5360b11ddeb56eab6d101316f9ffd1b39591609` |
| `residential_l02` | south | `source-v05` | `f0d7efcc05bbc9361cab8259daa9f8fd52f67f50baa1699217d9b41cbb714490` |
| `residential_l02` | west | `source-v05` | `3ecb2a3892283c4b012360aa2413a47e772dd41aeaf18a71fe20c0c0c08e9521` |
| `residential_l03` | north | `source-v01` | `9a53c7ca04e363e0d023a667a84de6ad26a7a5af2deaeb7cf2eb123ce5f7f881` |
| `residential_l03` | east | `source-v01` | `180e0cad4da66d5180b1fd3bd5df98d5e524e0924827002d3065a93811ec1e9c` |
| `residential_l03` | south | `source-v01` | `b6f709d0e4d56c4e13c7e69293891bc599dc706d8ceadddf87b8377c8dac105c` |
| `residential_l03` | west | `source-v01` | `dc5056b8cfdc9676e8db214293f15e86e1dfaf4dc3ee680c420260e2a7adce71` |
| `residential_l04` | north | `source-v01` | `b6ed8aaf95e4600bb476934824fab0976cadffe1191f3253aeb19c96cfe2f6b1` |
| `residential_l04` | east | `source-v01` | `049ce1b85236c9e443571d925b6def3783cf4226a8b0b9794e47cc195400b5e4` |
| `residential_l04` | south | `source-v01` | `cae30c6975f790b05a1de850649f2735a21079bb0c9321673106778f4ca98e34` |
| `residential_l04` | west | `source-v01` | `64b51a0bef79104132a508f53f8a1fa567de9bc87c35ecd44c19ef3cc2596646` |

The audit rehashed all 16 raw files against provenance and all 48 selected
normalized LOD files against their normalization records. The source
descriptors declare `authoredIndependently: true`,
`orientationTransform: none`, a fixed orthographic 2:1 projection, the same
ground pivot `(768, 896)`, and direction-specific frontage socket and door
records.

## Shipping gap

- The generated-v4 manifest contains one residential entry:
  `residential_l01`, level 1, south frontage, fixed south presentation.
- `LotRenderer` maps every completed Residential tile, regardless of
  authoritative level or adjacent road, to that one entry.
- Existing site frontage chooses an adjacent road, but the architecture does
  not follow it. This makes the entrance and road connection disagree for
  north/east/west lots.
- The pack builder assumes every authored source lives in the older
  `GeneratedV4/normalized/calibration/<logical-id>` layout, so it cannot select
  the accepted PLAY-027 revisioned inputs.
- The current pack has four pages and a 36 MiB decoded page total. PLAY-028
  must retain the four-page maximum and the active-plus-adjacent LOD 128 MiB
  high-water ceiling after adding 48 payloads.

## Bound implementation

1. Add one production-selection catalog owned by PLAY-028. It records all 16
   stable source keys, exact raw/provenance/normalization/scene paths and
   hashes, logical level, variant zero, frontage direction, and the three
   normalized LOD paths and hashes.
2. Extend the deterministic pack build to consume those selected normalized
   inputs without altering them. Each direction becomes a distinct manifest
   identity: `residential_l<level>_v0_<direction>`. Stable shelf sorting,
   unrotated pages, four-pixel gutters, two-pixel extrusion, payload digests,
   source inventory, and byte-identical two-build output remain mandatory.
3. Register each identity as family `residential`, variant `0`, authoritative
   level `1...4`, and frontage edge `north|east|south|west`. Carry source key,
   revision, view direction, scene/provenance/normalization digests, footprint,
   pivot, entrance socket, trim, anchor, world size, and residency metadata in
   manifest v4. No two identities may share a source, payload, or packed rect.
4. Resolve architecture from simulation truth only:
   `clamp(tile.level, 1...4)` plus an actual adjacent road edge. For
   multi-road lots use the stable priority `south, north, east, west`, which
   preserves the prior south-facing presentation when south is authoritative
   and otherwise chooses only a present road. A roadless Residential lot is a
   hard missing-identity diagnostic, not a direction or family fallback.
5. Use that same selected edge for the restrained authored frontage path.
   Camera, zoom, pointer position, and render order never participate.
6. Include level and frontage in the lot render identity and generated sprite
   name so unchanged pulses reuse nodes while level/road changes rebuild the
   exact affected tile. Preload the resolved visible identity set rather than
   all 16 identities.

## Verification and proof

- Catalog: exact 16 entries, four unique directions per level, 16 unique raw
  hashes, 48 unique normalized hashes, no aliases or transforms.
- Pack: two clean builds byte-identical; manifest/page/source/staged digests;
  alpha, trim, anchor/pivot within 0.5 world point, padding/extrusion, page and
  decoded-byte budgets, explicit rollback behavior.
- Runtime: exhaustive L1-L4 x N/E/S/W resolution and entrance adjacency;
  changed level/road rebuilds only that tile; unchanged pulse, save/load,
  undo, camera and LOD preserve identity; zero missing/fallback diagnostics.
- Visual: directional frontage matrix plus L1-L4 progression at city,
  neighborhood, and block LOD; staged default and exact 900x600; construction,
  condition, selection, valid/invalid preview, Reduce Motion, pointer,
  keyboard, and accessibility remain intact.
- Performance: disclose update/decode/total timing, node/action counts,
  resident page count, decoded bytes, high water, cache/reuse counts, and
  comparable default/compact RSS.

No shared simulation, save, store, command, HUD, Package.swift, or build-script
contract change is required by this plan.
