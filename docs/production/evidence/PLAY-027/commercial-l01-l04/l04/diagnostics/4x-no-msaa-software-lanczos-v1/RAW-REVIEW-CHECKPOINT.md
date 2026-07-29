# PLAY-027 Commercial L4 West raw-review checkpoint

**FINAL_DISPOSITION:** `PENDING_NORMALIZED_CALIBRATION`

**Raw diagnostic result:** `technicalPassed=false` under the intentionally
overstrict raw-only near-magenta gate

**Source authority:** No

**Production selected:** No

**SceneKit/Metal process count:** 3 (West A/B/C only)

**Normalization run count:** 0

The frozen diagnostic captures prove exact fresh-process determinism:

- A/B/C raw PNG SHA-256:
  `889de4bfb6eda7ae1eed79669918ca5089590a80672eff6ce6a63a3b2126832a`
- A/B/C canonical decoded RGBA SHA-256:
  `4ba9c6298e490db091b53c5c4b875002dc2c15f3d9017d4492adcfe549ba6655`
- A-vs-B and A-vs-C differing files, pixels, channels, and alpha pixels: zero
- occupied bounds: `[619, 418, 1029, 906]`
- occupied pixels: `97,392`
- pivot/socket/door/frontage/shadow registration: exact
- second no-Metal review-builder replay: byte-identical report and six panels

The no-Metal raw review also records 37,766 non-exact near-magenta pixels and
shows the expected opaque matte edge after masking only exact `#ff00ff`.
That remains a valid observation, and `review/REVIEW.json` remains unchanged
with `technicalPassed=false`. It is not a valid production-quality
acceptance/rejection conclusion because the accepted Commercial L4 West
source-v03 raw has the same opaque-matte presentation:

- accepted source-v03 raw SHA-256:
  `ac58ebd8c769fddd24d160f1ba4e4a5097d04f17ccab41bbb120672f5173433f`
- accepted source-v03 occupied bounds: `[619, 418, 1029, 906]`
- accepted source-v03 occupied pixels: `97,392`
- accepted pipeline quality gate: zero visible-magenta spill after the
  governed deterministic border-matte removal and despill stage

No normalization has been authorized or run against this diagnostic. The
packet therefore stops at raw evidence. Integration must separately authorize
a diagnostics-only normalization replay before the sampling pipeline can be
classified for source production. This checkpoint does not relax the raw
diagnostic threshold, claim source acceptance, or mutate accepted Commercial
art.
