# PLAY-060 renderer-lead ingestion audit and plan

**Audit baseline:** `91f885925fd601786fa95dbb969b71fefef5ddcd`

**Accepted source authority:** Commercial L1-L4 variant-zero N/E/S/W through
clean PLAY-027 candidate `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`

**Current shipping manifest SHA-256:**
`1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`

**Scope:** production ingestion and runtime selection for Commercial
variant-zero L1-L4 N/E/S/W only. Source-art repair, sibling transforms,
runtime mirroring/rotation, aliasing, camera-derived direction, cross-family
substitution, and Industrial ingestion are not authorized.

## Accepted 16-source inventory

Every selected source is an independently authored 1536x1024 PNG under
`Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/raw/<logical-id>/variant-0/<direction>/<revision>.png`.
The renderer audit rehashed these exact retained files and all 48 normalized
city/neighborhood/block payloads. The 16 raw hashes and 48 normalized hashes
are each unique.

| Logical ID | Frontage | Revision | Raw SHA-256 |
|---|---|---|---|
| `commercial_l01` | north | `source-v04` | `a60220fc054165a0c54af70038bfcfbc16ac6768fd4f266c388ecfc27480379d` |
| `commercial_l01` | east | `source-v04` | `57db0fe3cbb696e85ac537baa63eff42c0766147eae9ea3179337da670cabda2` |
| `commercial_l01` | south | `source-v04` | `3786264c9543281d0377b776ce001f46eff8d7f8ead8b65c775d2de7eace016e` |
| `commercial_l01` | west | `source-v04` | `27bfa3228b8335d3bd9a223e0106beac32eeddb309c59e6a518ba9be72e6f58e` |
| `commercial_l02` | north | `source-v01` | `fdf75f3d40c1e4274c1153493d94e188ff24840ed2ad06cc98ce01ff9127bc47` |
| `commercial_l02` | east | `source-v01` | `94fb7430bbc23efa7c081983434445bc52faa4a2dc4226fad9b1f40579e8766a` |
| `commercial_l02` | south | `source-v01` | `eed9dd92f593a860abf8c24cdccaf5a7e59574c761c95628b467ac1ac1c85efa` |
| `commercial_l02` | west | `source-v01` | `579a656b0623c5897cd5204bef23c29be9f739b45c4c4701b70801d36d76ba4d` |
| `commercial_l03` | north | `source-v01` | `9a81e8b710296c40ab16021c7db7fe0bed68a5e87a6dbb9dc4b07d43322a6c4e` |
| `commercial_l03` | east | `source-v01` | `a29c3f2ee33410409ea482c8f15c7f05f2b6a3b227feccc9c575991258ab4363` |
| `commercial_l03` | south | `source-v01` | `63984ab4ec0166b2b451901a48c5b2033b3d5ba103e269a6435831b557812736` |
| `commercial_l03` | west | `source-v01` | `7fbb3fedd2bd88d612e7853106c6dd2d510e55b45597c458438005d6412610f9` |
| `commercial_l04` | north | `source-v03` | `9e996eb088bddc197468c5f881c111cf64ab16fa5220de7641d876d0601b4cff` |
| `commercial_l04` | east | `source-v03` | `a97d881325c22217e57807a2b63b9cdbd9218de37f155c1dd097cc67a52c617c` |
| `commercial_l04` | south | `source-v03` | `985d2df5c5c852b4614609eec120bfc67e6ac4d1efb8376791ec8a5020d77122` |
| `commercial_l04` | west | `source-v03` | `ac58ebd8c769fddd24d160f1ba4e4a5097d04f17ccab41bbb120672f5173433f` |

Each accepted scene descriptor declares `orientationTransform: none`, a
fixed 2:1 orthographic projection and `(768, 896)` ground pivot, and its own
direction-specific frontage socket, entrance geometry, descriptor hash, and
scene-geometry identity. The retained normalized bytes are the only authorized
packing inputs; this task will not run a normalizer over them or alter them.

## Shipping gap

- The generated-v4 shipping manifest still contains one fixed Commercial
  entry, `commercial_l01`, with a south-facing legacy production identity.
- `LotRenderer` maps every completed Commercial tile, regardless of its
  authoritative level or adjacent road, to that single entry.
- Site frontage already chooses an actual adjacent road, but the architecture
  does not follow it. North/east/west entrances can therefore disagree with
  the road-facing public realm.
- The pack builder has a governed PLAY-028 selector for Residential but no
  Commercial selection catalog. The accepted Commercial normalized payloads
  are not present in production pages.
- The current generated-v4 pack remains the accepted four-page baseline.
  Commercial ingestion must retain the four-page limit and the 128 MiB
  active-plus-adjacent decoded-byte ceiling.

## Bound implementation

1. Add a PLAY-060 production-selection catalog containing exactly the 16
   accepted source revisions, raw hashes, and 48 normalized LOD hashes.
2. Generalize the existing deterministic directional pack path so Residential
   and Commercial each retain their own family, source paths, provenance,
   geometry registration, and manifest identities. Commercial identities are
   `commercial_l<level>_v0_<direction>`.
3. Reject missing, altered, mirrored, rotated, cross-level, or cross-family
   inputs before packing. Stable shelf order, no page rotation, four-pixel
   gutters, two-pixel extrusion, and byte-identical rebuilds remain mandatory.
4. Resolve Commercial presentation from authoritative `tile.level` clamped to
   `1...4` plus a real adjacent road edge. Multi-road priority remains
   `south, north, east, west`; roadless Commercial lots emit a bounded explicit
   missing-identity diagnostic.
5. Use the same selected edge for the authored frontage path. Camera, zoom,
   pointer position, frame order, and save-local presentation state never
   participate.
6. Preserve level and frontage in node identity so unchanged pulses reuse the
   existing tile while authoritative level or adjacency changes rebuild it.
7. Keep construction, condition, selection, preview, overlays, Reduce Motion,
   pointer/keyboard/AX behavior, public realm, and Focus City composition
   unchanged.

## Verification and proof

- Exact 16-key Commercial matrix, 16 unique source keys/raw hashes, and 48
  unique normalized hashes; no alias, transform, or fallback path.
- Two clean pack builds with byte-identical pages/manifests, complete
  source/staged digest parity, alpha/padding/extrusion/pivot/socket/entrance and
  production-geometry validation.
- Exhaustive L1-L4 x N/E/S/W runtime resolution, roadless explicit failure,
  and stable identity through pulse, save/load, undo, camera, and all LODs.
- Staged default and exact compact proof with real Commercial selections,
  direction/level matrix, city/neighborhood/block LOD, construction,
  condition, selection, preview, Reduce Motion, pointer, keyboard, and AX.
- Color and grayscale L1-L4 progression, Commercial-versus-Residential
  distinction, road/lot overlap checks, node/action/update/decode/total render
  timing, residency, RSS, and fallback disclosure.

No shared contract proposal is required. The existing manifest-v4 descriptor
shape, authoritative tile level, adjacent-road mask, and staged resource
packaging fully cover this ingestion.
