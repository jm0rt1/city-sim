# PLAY-027 Industrial L4 v16 North A-only raw probe

Disposition: `PENDING_INDEPENDENT_RENDERER_AND_QA_REVIEW`

This packet consumes exactly the one authorized North A native process. No
repeat process, sibling direction, normalization, ingestion, shipping, source
authority, or production selection is included.

## Immutable process result

- published renderer source commit:
  `3201664511ae3329fe58bb97438e230a471b8fa4`;
- compiled renderer binary SHA-256:
  `fb0b34e1376de64fd30e49aaddcc8871a75728d4188dd747632ec8a31a6d30c3`;
- builder SHA-256:
  `15d88031e4b845060d2f66cef93f96a7d9b204fd2ecd9873f885924e8099c97d`;
- descriptor SHA-256:
  `bb4d38f44223083fe88b24f482b62a3061b0322e83e50836d8fb7b2d97b3c411`;
- material SHA-256:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`;
- raw PNG SHA-256:
  `25635578bc30e6a9de895161a6f33855866d456aa8a73eb307aff86793b55b03`;
- canonical decoded RGBA SHA-256:
  `a20e26cf02afc4ba7a316251077fd844f5e2c7243d077259a1833d4fcf92499b`.

The 1536-by-1024 raw contains 118,721 non-chroma pixels with inclusive bounds
`[509,523,1026,897]`. The renderer's half-open occupancy record is
`[509,523,1027,898]` and passes its completeness thresholds. All 1,572,864 raw
pixels are opaque, hidden RGB at alpha zero is zero, and the flat exact-chroma
partition is complete. The raw retains 1,807 non-exact near-chroma edge pixels;
this is disclosed pre-normalization evidence, not silently treated as a
production-normalized spill result.

The exact descriptor resolves the v3 source-authority sampling contract with
SceneKit antialiasing `none`, `authored-constant-v1`, SceneKit shadows
disabled, and orientation `none`. The retained resolver report contains one
positive and 20 fail-closed mutations.

## World Art pixel inspection

The registered compact overlay binds pivot `[768,896]`, North socket
`[896,704]`, the North frontage edge, door base, and southeast shadow vector
`[2,1]`. The frozen analytic throat width is 7.6665 compact pixels, above the
authorized seven-pixel minimum, and the raw contact field visibly reaches the
socket.

At source and native-2x scale, the warm hall, dark double-girder gantry,
orange-hot shaped crucible, subordinate stack, northwest-lit value hierarchy,
and southeast contact shadow survive. One dark monumental recessed opening
retains an observable frame and inset at occupied-crop/native scale. At literal
192-by-128 it survives as a dark freight-scale opening, but its jamb/header
depth is materially less legible than in the occupied crop. That compact
player-recognition judgment remains explicitly for independent Renderer and QA
review; World Art does not self-accept it.

The no-Metal review builder compiled with warnings-as-errors. Two complete
review generations produced byte-identical reports and panels after excluding
the packet manifest's own filename from its inventory.

`sourceAuthority=false`; `productionSelected=false`.
