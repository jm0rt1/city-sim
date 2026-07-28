# PLAY-027 Industrial L4 v17 matte and visibility disposition

- World Art diagnostic: `e8c1ba77c4ed10193a7ff53cdc7a07cab7ae989d`
- Integration preservation merge: `d46127b93be9d1108ba60cc1a0f1259135c535d0`
- Renderer disposition: `APPROVE_MATTE_ONLY_RETURN_GEOMETRY`
- QA disposition: `APPROVE_MATTE_ONLY_RETURN_GEOMETRY`
- Source authority: `false`
- Production selected: `false`

## Accepted finding

The matte attribution is complete enough to support the narrowly versioned
offline repair in CONTRACT-019:

- all `1,807` contaminated coordinates are reproduced;
- `1,552` are silhouette, `245` are contact-shadow, `10` are overlap, and
  `0` are unowned;
- two no-Metal runs are byte-identical;
- the diagnostic copy has zero chroma at nonzero alpha and zero hidden RGB;
- bounds and registration are preserved; and
- no pixel changes outside the established matte/despill set.

This accepts the diagnosis, not the v17 raw.

## Returned finding

The v17 descriptor is not being skipped: its portal blocks are emitted as
SceneKit boxes and the full source raster differs materially from v16.
However, the analytic pre-pixel language does not survive the native
presentation path. At native-2x and literal 192, the jambs/header merge with
the hall and gantry, while the crucible obscures the center. The result still
reads like the rejected v16 narrow opening rather than a monumental framed
portal.

Industrial L4 North therefore returns to PLAY-027 under CONTRACT-019. The next
gate is an exact-camera semantic-ID visibility proof plus the versioned matte
repair. No additional authoritative raw process is authorized until both
Renderer and QA approve the actual native-2x and literal-192 evidence.
