# PLAY-027 Industrial L2 renderer capability preflight

Status: task-owned tooling boundary frozen before any Metal-visible candidate
render.

The default offline renderer now captures the host rendering capability before
scene construction or `SCNRenderer.prepare`. It binds the created
`SCNRenderer` to the reported system-default Metal device and reuses that exact
renderer for the unchanged prepare and snapshot path.

When no Metal device is visible, or the renderer has no device, the process:

- writes a typed `renderer-backend-unavailable` JSON record;
- records zero candidate output, failure classification, scene construction,
  and scene preparation;
- exits successfully without creating a raw PNG or candidate provenance;
- does not classify the unchanged Industrial L2 source-v03 scene as failed.

An explicitly requested capability record is diagnostics-only, JSON-only, and
must not already exist. On a Metal-visible host, the complete existing scene
construction, rendered-node bounds, `SCNRenderer.prepare`, render, compositor,
and PNG validation path remains mandatory.

## Compilation and guard validation

- default renderer compilation: pass;
- scene-preparation diagnostic compilation with
  `PLAY027_SCENE_PREP_DIAGNOSTIC`: pass;
- default renderer test binary SHA-256:
  `1b28b5f14cdb885cf70380df8efb73870d8a71095f4e49974550833160ba69f6`;
- diagnostic renderer test binary SHA-256:
  `1372058c9c42f20308abadd91b7a15e249c35eee5e6537a948ee5afa27bfec98`;
- forbidden capability-record path: exit 133;
- forbidden raw, provenance, and capability outputs: all absent.

Both executables were compiled from the task-owned descriptor, architecture,
canonicalizer, stage-diagnostics, capability-preflight, and renderer sources.
The diagnostic executable additionally included
`Tools/DiagnoseScenePreparation.swift`. Both linked only the existing macOS
native frameworks, including Metal and SceneKit. No product package or runtime
target changed.

## Zero-device contract

Two fresh default-renderer processes used the unchanged North descriptor and
governed industrial material library. Both exited 0 with the typed unavailable
result. Their exact capability records are byte-identical:

`764c788191226a6c7222c91fd8610bac226e11a74192b747ed0983c2f3ecb22f`

The requested `forbidden-candidate.png` and
`forbidden-candidate-provenance.json` do not exist. The two retained records
are `NORTH-ZERO-DEVICE.json` and `NORTH-ZERO-DEVICE-REPEAT.json`.

## Frozen candidate inputs

| Input | SHA-256 |
|---|---|
| North descriptor | `aee5c7ef5de5b62fb357335c09d9a020ed97582882bfd1bf7ac7bc21f6d3a5b6` |
| East descriptor | `24ccd400535090532be046fe9868c069f3fc1b94aa999fc4c6569b74c24c03e1` |
| South descriptor | `ce4c8067135a1f57ee50dbfed9aa3b83b7fab6aa847aa7bd8c79cb783bb72d1c` |
| West descriptor | `8ce989ea6c4b85fbdf04ba002236179c45b71b0fbe2cc2d5a39a2abf28b29a1e` |
| Industrial material library | `166a19d5569a927d6ccdbaf1b29131835238bb3622e66d3b376d9eb33008f1ef` |
| Schema-2 v3 toolchain fingerprint | `201ef1a1bdc54fb048f7bb00708e97c1605c0ca48814ba28c8dc6fdc65d3fccd` |

The descriptor and material surfaces have no diff from the accepted
source-v03 architecture boundary. This checkpoint authorizes no new source
revision, normalization, or source-art acceptance.
