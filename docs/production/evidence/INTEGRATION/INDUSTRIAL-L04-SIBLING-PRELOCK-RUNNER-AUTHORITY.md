# Industrial L4 sibling pre-lock runner authority

**Published baseline:** `af995850f0b20603c89ec7fdfda56245153a7f94`

**Governing contract:** `CONTRACT-021` revision 2

**Disposition:** `AUTHORIZED_ZERO_PIXEL_RUNNER_PREPARATION`

**Handoff schema:** `industrial-l04-prelock-runner-handoff-schema-v1.json`,
SHA-256 `05a4a5027a677536ed3370c51ccfcb0a9435c6c4cac5c47bf193377cc5af4951`

East, South, and West have independently accepted zero-pixel predesigns, but
their current tools intentionally expose no production render entry point.
Waiting to build those entry points until after North process A is accepted
would serialize setup that is independent of North appearance.

This authority reopens PLAY-079, PLAY-080, and PLAY-081 only for disjoint,
direction-local production-runner preparation. It does not authorize a pixel,
material lock, source-ready disposition, or renderer ingestion.

## Exclusive write roots

| Direction | Claim | Source/tool root | Evidence root |
|---|---|---|---|
| East | PLAY-079 | `Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/` | `docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/` |
| South | PLAY-080 | `Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/` | `docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/` |
| West | PLAY-081 | `Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/` | `docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/` |

Each cell may read its accepted predesign and the published family contracts.
It may not edit accepted predesign files, another direction, North, shared
tooling, renderer/runtime/shipping resources, package topology, or claims.

## Frozen inputs

All three cells bind CONTRACT-021 revision 2 at SHA-256
`f80844c928d904498510b8b151381f40315e072d52d81695aafcd6b91081ae4c`.

| Direction | Accepted handoff SHA-256 | Scene/contract SHA-256 | Materials SHA-256 | Validator SHA-256 |
|---|---|---|---|---|
| East | `bb8b2a00b4bf3ffa99112947d08e11cc92cae8d1ea7709e3fa79a4c58f40f390` | `e19c70693ea57a7f23669d5e93354eee0a8fa42be16e68b38d00f5608a500db7` | `1d0eda7be1e50d9fd98247cb63035443e904a2724583df1fbb328140b63ef9b9` | `86dd6b3fad5502c6c9f898d802c9fc5eb4da57e7864c981494ad5ad9f75dde33` |
| South | `ec3cc2f758e3191d6cf76d5db0686d5481e09a3d42fd3033789f8a85d189bd42` | `e0c8dd02f261844daa3d78ba05c482acbbe9b08eac835a0f863621f48010b07d` | `624b34f10354c79e0ced914ed55cf4dcb05468997d4efb679f881477984244fb` | `33ecc7cd31c7cb7efb4ace497a214499e37f4472e85216050b459e35c05c467c` |
| West | `0bfe22cb607708e21e446f7e11dbc91876f107b3910bf23fcf474e9ee428e978` | `9376538d66a653be4a07f7c8d511626f16dbb4b0d4ef42e0354efb737f1f1b9c` | `3d3588a57d7c42f09c3978aa2f2a1ac68b5ccba0cc591eba8ef3172242976463` | `70df01d053b08df2a3ebd13d1aa1df3b9291c3b3e4a3c68c28516e45f87105f7` |

## Required pre-lock implementation

Each direction creates within its exclusive roots:

1. a machine-readable runner contract that binds:
   - direction and claim;
   - exact accepted predesign scene, material, validator, and proof hashes;
   - governed camera, footprint, pivot, socket, light, Cycles, transparency,
     color, alpha/chroma, and hidden-RGB invariants;
   - `appearanceLockCommit: null`, `appearanceLockSha256: null`,
     `productionSelected: false`, and `state: awaiting_appearance_lock`;
2. a direction-local production driver with separate `validate`, `A`, `B`, and
   `C` process modes;
3. a hard guard that rejects every render mode while either appearance-lock
   field is null, the locked material mapping is absent, or any frozen hash
   differs;
4. direction-local validators for fresh-process provenance, decoded RGBA
   identity, alpha/chroma/hidden RGB, occupied bounds, footprint/pivot/socket,
   literal-192 survival, non-aliasing, and A/B/C equality;
5. deterministic output paths for raw, semantic, provenance, color/grayscale,
   native-2x, literal-192, registration, contact-sheet, rejection, and handoff
   evidence; and
6. `PRELOCK-RUNNER-HANDOFF.json` with:
   - `schemaVersion: 1`;
   - exact task, direction, branch, baseline, predesign hashes, runner hashes,
     output inventory, and validation results;
   - `renderInvocations: 0`, `pixelFiles: 0`;
   - `state: prelock_runner_ready`;
   - `sourceReady: false`, `productionSelected: false`;
   - the exact missing appearance-lock fields.

The future lock binding must include its repository path, commit, document
SHA-256, North process-A source SHA-256, and North process-A decoded-RGBA
SHA-256. Do not invent placeholder material or source hashes.

The runner may reuse or import only its own accepted direction predesign. It
must not copy, mirror, rotate, transform, or inspect sibling geometry.

## Commit and validation cadence

Each cell independently:

1. validates branch, cleanliness, baseline ancestry, and exclusive roots;
2. commits the runner contract and hard-guarded driver;
3. runs only zero-pixel validation, including missing-lock and wrong-lock
   rejection before any Blender subprocess or render API can launch;
4. commits validators plus the machine-readable readiness handoff;
5. returns a clean exact candidate for Integration review.

A pre-lock run must record zero Blender process launches, `bpy.ops.render`
calls, ImageGen calls, normalizer calls, contact-sheet calls, render
invocations, and pixel files. RGBA, literal-192, A/B/C identity, and
normalization validations remain explicitly `not_run`.

A failure returns only that direction. No cell waits for another sibling.

## Still serialized

Integration alone publishes the immutable North process-A appearance lock and
the exact post-lock production authority. After that publication, North B/C
and East/South/West A/B/C launch concurrently. Shipping atlas/manifest
mutation, production selection, final exact-candidate QA, integration, and
push remain atomic or single-writer operations.
