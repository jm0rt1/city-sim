# Industrial L4 matte canonicalization v2

`matte-canonicalization-v2` passes the CONTRACT-019 pre-pixel regression gate
for the immutable rejected v17 North raw.

- The exact 1,807-coordinate mask and SHA-256
  `824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109`
  reproduce.
- The transparent canonical output has zero exact or near chroma at nonzero
  alpha, zero hidden RGB, unchanged retained occupied bounds and registration,
  and zero changes outside the border-connected matte or retained-despill
  predicates.
- Two fresh no-Metal replays are byte-identical.
- All 44 accepted Residential, Commercial, and Industrial L1-L3 raw masters
  remain byte-identical and reject the exact-v17 version gate.

This approves only the task-owned matte implementation boundary. It does not
accept v17 geometry or pixels, authorize a raw process, select production art,
or modify renderer/shipping behavior.
