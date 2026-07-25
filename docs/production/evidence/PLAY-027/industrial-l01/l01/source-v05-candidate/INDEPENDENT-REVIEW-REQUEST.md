# PLAY-027 Industrial L1 source-v05 independent review request

Requested disposition: **independent source-art review of Industrial L1
variant-0 N/E/S/W source-v05**.

This is a non-shipping review candidate. It is not self-accepted,
`productionSelected` remains `false`, and Industrial L2 remains unauthorized.
The exact candidate is the commit containing this request; integration should
bind its disposition to the reported handoff hash.

## Durable lineage

1. `e2690f524dbf468255605cfe77a236404a015fa9` — freeze the separately
   authored source-v05 gantry/loading-throat descriptors.
2. `7feeabe5114be33e4339bd6db751361d43c259fe` — preserve the approved
   one-process N/E/S/W probe.
3. `d4440f48e854c136e4116fc61166ec627e90b499` — prove three-process raw
   file and pixel identity.
4. `265257ccdecff6608ec57f7d286d8052709f4688` — freeze two-run normalized
   outputs and technical validation.
5. `ec2adbe1c2951c20bdedbc5ebc8375be29e547dd` — freeze the complete
   visual, grayscale, and cross-family packet.
6. This request's commit — refresh accepted-source preservation at `ec2adbe`
   and freeze the exact review request.

## Exact raw source identities

| Direction | source-v05 SHA-256 |
|---|---|
| North | `5ca93afa57157ddf686ef5740f1907da03f513906b9c703bc556ed75e2516728` |
| East | `f20d78d6b4b43c7111250f231351166397e3444e3f7a7243f282dacd94592e4f` |
| South | `f3588cf71e689055a2bd0a184262b24df0af8c4e41be1665af5c8eb6f8edca2e` |
| West | `9fa5759f88e2efd2f3eef36f66089f0e8e978dc4e052d08d919b9f1a40aa331a` |

All four are unique. Each primary is exactly file- and pixel-identical to its
two retained fresh-process repeats.

## Exact normalized primary identities

| Direction | Block | Neighborhood | City |
|---|---|---|---|
| North | `beba2ab0dbf920e0725ba7771f3c5288c02507c0b375bc8dd7940840dad8f13b` | `d637c48c462942a6739434e3f8532291d5977bd6159da1bc9ca86a03648f3329` | `8134c56cb4ea3238fec85bf4b568eed0a2c8a0724695be16c105e057c3aa4583` |
| East | `389407f132453db7c1cc5908c4732902f55577a1f999f9985d1eb0a9b9a6f84b` | `35803e7aa979aa9afecb134e457040e23fa58fdd51be18db4c4e010e3f470607` | `a04aceca4ba2cd47b0b2fcbecb00d4dbf48fca8129c779bf6d27c825d8876d81` |
| South | `4c5228bdcf513c272b392e6175faa85327191b99433f81cd8c33b6e10a53020d` | `0794afa8e0002f88ba01a4458800f7b0ae886b9a608d7064a3c7a0fc759da274` | `4d0dcaa65bb8bbea8661f37f426441996e5d4e88de36fc2689bd28eb7ab8103d` |
| West | `04a2963a211d4b7ae5ac4fa8ddbb88c46dbe18cc7b4685bf67c9167dc8bda9da` | `4fa100cfeb1abc0caecaf4cbd74ffa51abd0c521d9050a76ec2e1a4cbbf4a025` | `be96b2aec303069741d625dd91620d6e29138ea6e4b6c9d3af98275cba8b6b9f` |

All 12 are unique and each is byte-identical to its independent second
normalization run.

## Binding validation result

- Raw three-process identity: 4/4 pass.
- Raw directional uniqueness: 4/4 pass.
- Exact RGBA visibility: 4/4 pass; visible-alpha and non-magenta RGB bounds
  match, with zero hidden building RGB.
- Normalized two-run identity: 12/12 pass.
- Normalized uniqueness: 12/12 pass.
- Opaque chroma, visible magenta spill, transparent hidden RGB: zero in all
  12 normalized outputs.
- Alpha bounds and padding: 12/12 pass.
- Ground pivot, directional socket, directional entrance base, shadow, and
  normalized bottom registration: 4/4 directions and 12/12 outputs pass.
- Accepted Residential L1-L4 and Commercial L1-L4 source mutation count
  relative to `91f885925fd601786fa95dbb969b71fefef5ddcd`: zero.
- Dark-palette grayscale separation: 12/12 pass across block, neighborhood,
  and city; median luma `48`, 10 populated value bands, p95-p05 `96`–`101`.
- Review/diagnostic packet repeat build: 13/13 exact file identities.

## Required visual review order

Primary panels:

1. `review/FOOTPRINT-NATIVE-2X-COLOR.png`
2. `review/FOOTPRINT-NATIVE-2X-GRAYSCALE.png`
3. `review/NATIVE-2X-COLOR.png`
4. `review/NATIVE-2X-GRAYSCALE.png`
5. `review/ZOOM.png`
6. `review/SOURCE-SCALE.png`

The footprint and zoom envelope is `[341, 300, 342, 317]`, which contains all
four full alpha bounds and does not crop the tall loading gantries.

Cross-family and all-LOD panels:

1. `diagnostics/review-evidence/CROSS-FAMILY-NATIVE-2X-COLOR.png`
2. `diagnostics/review-evidence/CROSS-FAMILY-NATIVE-2X-GRAYSCALE.png`
3. `diagnostics/review-evidence/GRAYSCALE-BLOCK-ORIGINAL-PIXELS.png`
4. `diagnostics/review-evidence/GRAYSCALE-NEIGHBORHOOD-ORIGINAL-PIXELS.png`
5. `diagnostics/review-evidence/GRAYSCALE-CITY-ORIGINAL-PIXELS.png`

Please independently judge:

- whether North and West now read as physically honest far-edge loading
  infrastructure at the exact road socket;
- whether all four views retain complete grounded factory volumes, service
  aprons, shadows, and directional frontage identity;
- whether the deliberately dark industrial palette preserves sufficient
  hierarchy at every LOD;
- whether the factory/sawtooth/exhaust/gantry silhouette remains unmistakably
  non-residential and non-commercial in color and grayscale.

No Industrial L2 work should begin without a separately published independent
disposition and new integration authority.
