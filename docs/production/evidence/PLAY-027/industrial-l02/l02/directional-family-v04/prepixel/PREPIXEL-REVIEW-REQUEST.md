# PLAY-027 Industrial L2 directional family V04 review request

Disposition: `PENDING_INDEPENDENT_PREPIXEL_COMPATIBILITY_REVIEW`.

V04 is a decode-compatibility checkpoint only. It adds the eleven required
`EntranceDescriptor` fields to V03 without changing any previously reviewed
geometry, camera, material binding, registration, socket, frontage, pivot, or
shadow value.

Review the production-decoder/material ledger and canonical equivalence:

- all four directions dry-decode with the real production `SceneDescriptor`;
- N/S/W required entrance keys are complete;
- every N/S/W material reference resolves in the immutable East v05 library;
- the dangling East `v02-painted-steel` pavilion value is not propagated;
- N/S/W map that decode-only role to same-role `v05-hall-metal`, never the
  subordinate `v05-safety` accent;
- removing the eleven V04 fields reproduces V03 exactly;
- N/S/W and East geometry hashes remain four unique identities;
- analytic panels remain byte-identical because the builder has no entrance
  dependency;
- East descriptor, material library, and governed raw remain byte-exact;
- East's dangling pavilion metadata remains a separately authorized
  family-level blocker, so this checkpoint claims no complete family authority;
- SceneKit, Metal, raw, and normalization process counts remain zero.

If this checkpoint is independently confirmed, the prior authorization permits
exactly one North and one West primary. South pixels, repeats, normalization,
source authority, production selection, renderer ingestion, and shipping
remain blocked.

`sourceAuthority=false` and `productionSelected=false`.
