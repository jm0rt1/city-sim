# PLAY-027 CONTRACT-019 R3 pre-pixel boundary

`PASS_PREPIXEL_51_NODE_BOUNDARY`

This checkpoint is diagnostic-only. `sourceAuthority=false` and
`productionSelected=false`. No SceneKit/Metal snapshot, authoritative raw,
normalizer, sibling, portal-modeling, ingestion, or shipping process was run.

The canonical `foundation` and redundant `v16-foundation` produce identical
canonical semantic bytes:

- dimensions: `56 × 1.4 × 56`
- position: `[0,0.7,0]`
- material: `v14-dark-foundation`
- both canonical definition SHA-256:
  `fa1653597d413b309bbba9d36d20dbf2cb24d55bd87e3d14ac79ac8850c5ded2`

The immutable v18 descriptor removes only `v16-foundation`. Reconstructing the
v17 descriptor by reinserting that exact mass and restoring the three
revision-identity fields is canonical-byte identical to v17. The only identity
changes are `sourceRevision`, `sampling.sourceRevisionBinding`, and
`sceneGeometryID`.

- v18 descriptor SHA-256:
  `3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630`
- unchanged material SHA-256:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`
- real builder geometry-node count: `51`
- canonical foundation nodes: `1`
- redundant foundation nodes: `0`
- semantic manifest SHA-256:
  `611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f`
- resolver/semantic fail-closed negatives: `14/14`

The descriptor builder and resolver preflight each reproduced byte-identically
in a fresh output. This commit is the required durable boundary before the two
authorized diagnostic SceneKit/Metal processes.
