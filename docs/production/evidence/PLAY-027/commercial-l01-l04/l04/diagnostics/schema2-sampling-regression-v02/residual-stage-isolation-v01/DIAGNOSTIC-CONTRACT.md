# PLAY-027 residual stage isolation v01

This task-owned diagnostic preserves the committed 12-process Residential L3
West canonicalizer-v2 calibration at `24f8093`, including its exact 10/2 final
PNG identity split. It does not replace, rewrite, or delete any calibration
attempt.

The retained target is source coordinate `(732,778)`, interpreted as a
top-left decoded RGBA source pixel. Every fresh-process attempt must retain:

1. prequantized in-memory RGBA SHA-256, target RGBA, and local 3x3;
2. quantized-before-majority in-memory RGBA SHA-256, target RGBA, and local
   3x3;
3. post-majority in-memory RGBA SHA-256, target RGBA, local 3x3, and the
   target's per-channel eligibility/mutation decision;
4. the exact ImageIO pre-sips PNG bytes plus decoded RGBA SHA-256, target
   RGBA, and local 3x3;
5. the final sips PNG bytes plus decoded RGBA SHA-256, target RGBA, and local
   3x3.

Each attempt uses a new directory. The capture path is diagnostic-only,
descriptor sampling remains unchanged, canonicalizer thresholds remain
unchanged, and no additional repair is present. Mutation-count equality is
recorded only as context and is not stage-boundary evidence.

Residential L4, the full schema-2 regression restart, normalization, and
Commercial L4 source-v03 remain frozen pending independent disposition.
