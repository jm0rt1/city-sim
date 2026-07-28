# PLAY-027 Industrial L4 matte canonicalization v2 R2

Disposition: `PASS_BYTE_DERIVED_FAIL_CLOSED_ADMISSION`

The canonical output remains byte-identical to the returned v01 candidate:
PNG SHA-256 `39bcb896664ef436853790e2acd87bb0d450b8401bb5318708757aef331a2385`
and decoded RGBA SHA-256
`d5ef428818b2ea5ba5e44c3d46f30c06b69589964ed37f53843a6976128c87ad`.

R2 computes the decoded RGBA, descriptor, and material hashes from the bytes
presented to the stage. It derives the no-authored-magenta result by decoding
the bound material bytes. Stale metadata paired with mutated RGBA, descriptor,
or material bytes rejects.

All 44 accepted Residential, Commercial, and Industrial L1-L3 masters now
enter the actual admission function and reject from their own decoded bytes;
their files remain byte-identical. Two complete no-Metal replays produced
identical three-file inventories.

This is an offline task-owned pipeline checkpoint. It does not accept v17
geometry, authorize raw rendering, select production art, normalize assets, or
change renderer/shipping surfaces.
