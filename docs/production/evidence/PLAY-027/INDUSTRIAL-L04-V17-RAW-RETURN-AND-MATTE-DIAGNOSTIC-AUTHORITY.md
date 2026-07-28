# PLAY-027 Industrial L4 v17 raw return and matte diagnostic authority

- Rejected raw candidate: `526d7c410491f11367ebf013236d281da0b60887`
- Integration preservation merge: `df7e14fe50687310b423fd034b6b8dd09a740c51`
- Disposition: `REJECTED_PLAYER_VISIBLE_NEAR_CHROMA`
- Diagnostic owner: PLAY-027 World Art
- Additional Metal/SceneKit/raw processes authorized: `0`
- Normalizer authority processes authorized: `0`
- Source authority: `false`
- Production selected: `false`

The v17 architectural repair remains materially stronger than v16 and accepted
Industrial L3. The actual A raw is nevertheless rejected because 1,807
near-magenta pixels visibly attach to the building silhouette and southeast
contact wedge.

Renderer diagnosis establishes that this is not a modeling or material defect:

1. SceneKit produces clear-alpha geometry.
2. Software Lanczos produces partial-alpha silhouette samples.
3. `NativeSourceCompositor` fills an opaque `#ff00ff` canvas, draws a
   translucent contact shadow, and alpha-composites the downsampled source.
4. This is the first stage where silhouette and shadow coverage become opaque
   near-magenta.
5. The quantizer bypasses exact `[255,0,255,255]` only, so it freezes the
   continuous fringe/wedge as ordinary image content.

V16 and v17 have identical contamination despite different architecture:

- count: `1,807` each;
- coordinate intersection: `1,807`;
- Jaccard similarity: `1.0`;
- sorted-coordinate SHA-256:
  `824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109`;
- histogram:
  - `1,202` × `(255,16,255,255)`
  - `529` × `(240,16,240,255)`
  - `70` × `(255,16,240,255)`
  - `6` × `(240,16,255,255)`.

No further modeling revision is authorized for this defect.

## Authorized no-Metal diagnostic

World Art may add one task-owned diagnostic tool and evidence packet that
operates only on immutable retained files:

- v17 raw SHA-256:
  `9aea278d4fe7640a4dd126c4393fd284f2849f80168b5e62d6e8dbe2cf75c5d7`;
- v17 decoded RGBA SHA-256:
  `0d9ca24f63de0f17c72cd36c38b742bd6fe6aca8aaee60c987a541af952e620f`;
- v16 raw SHA-256:
  `25635578bc30e6a9de895161a6f33855866d456aa8a73eb307aff86793b55b03`;
- v16 decoded RGBA SHA-256:
  `a20e26cf02afc4ba7a316251077fd844f5e2c7243d077259a1833d4fcf92499b`;
- v17 descriptor SHA-256:
  `6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a`;
- material SHA-256:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`;
- renderer binary SHA-256:
  `da2c8c420f4c4fe3ef8d2e0706cd2a640190c0b6fa89d79e8b89b843ab1b08e6`.

The diagnostic must:

1. reproduce the exact near-chroma mask, coordinate hash, and histogram;
2. analytically project the registered contact polygon and shadow support
   using the frozen compositor math;
3. classify every contaminated coordinate as silhouette edge,
   contact-shadow edge, or overlap;
4. apply the existing border-connected matte-removal/despill logic only to an
   explicitly diagnostic copy;
5. emit native-2x and literal-192 color/grayscale comparisons, attribution
   masks, metrics, and an immutable input/output manifest; and
6. mark every output `diagnosticOnly=true`, `sourceAuthority=false`, and
   `productionSelected=false`.

## Repeat and stop gates

Two fresh no-Metal runs must be byte-identical:

- input coordinate count remains `1,807` with coordinate SHA
  `824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109`;
- every contaminated coordinate receives deterministic ownership;
- the diagnostic copy has zero exact/near chroma at nonzero alpha and zero
  hidden RGB;
- no pixel outside the classified matte/spill set changes;
- descriptor, camera, pivot, socket, contact polygon, bounds, and source files
  remain byte-identical; and
- Metal, SceneKit, raw, and authority-normalizer process counts remain zero.

Stop if contamination remains, a legitimate candidate pixel changes, or
ownership cannot distinguish the shadow and silhouette paths. Commit the
diagnostic packet and return for independent Renderer and QA review.

Any change to compositor order, raw alpha/matte semantics, `flatChromaRGBA`,
the raw rejection rule, or shared renderer architecture requires a separate
integration-approved versioned contract.
