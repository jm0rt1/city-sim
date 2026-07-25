# PLAY-027 schema-2 v3 Residential L3 West calibration

Status: PASS — authorized full regression gate may begin

Exact renderer checkpoint: `f723825d80a49e630d0490817c74d1cafd951629`

Twelve fresh processes produced one exact PNG file identity:

`b15ec294b1f276372702dca3822f4326646cc42e299ba0187bd81b681bec3add`

The decoded RGBA identity is:

`81e528484ed0757cfa8b87dbea666ee0e29e9cb66fc847801c8b55cbfe359b5c`

Both causal inputs occurred independently:

- green 23 at prequantized `(733,778)`: 3 runs, six stable votes plus
  one recorded boundary assist;
- green 24 at prequantized `(733,778)`: 9 runs, ordinary seven-vote rule.

All 12 targets converge to `[16,48,16,255]`. ImageIO pre-sips and final sips
decoded RGBA match the post-majority buffer in every run. Each assisted target
records the immutable prequantized coordinate/value, `[23,24]` boundary pair,
effective support seven, competing support two, and reason.

The packet retains 48 run files. This pass satisfies the integration-authorized
calibration prerequisite only; it is not source-art acceptance. The complete
accepted Residential L1–L4 and Commercial L1–L3 N/E/S/W regression must still
pass before Commercial L4 source-v03 can be considered.
