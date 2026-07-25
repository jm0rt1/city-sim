# PLAY-027 Industrial L2 East v04 alpha-relation repair

**Disposition:** Pending independent pre-pixel tooling review. Industrial L2
source art remains unclassified and `productionSelected` remains `false`.

This checkpoint changes only the current task-owned v04 probe and review tools.
It replaces the rejected full-array alpha equality with the approved per-pixel
relation:

- input alpha `0` requires output RGBA exactly `[255, 0, 255, 255]`;
- input alpha greater than `0` requires output alpha equal to input alpha;
- the quantizer and post-quantization canonicalizer may not change foreground
  alpha.

The probe records separate immutable full input/output alpha hashes,
foreground-only input/output alpha hashes, zero-to-chroma count, and relation
violation count. The review tool now fails closed unless the future governed
provenance reports identical foreground alpha hashes, at least one
zero-to-chroma mapping, and zero relation violations.

Synthetic proof covers alpha `0`, `1`, `64`, `128`, `254`, and `255`.
Deliberately invalid zero-field RGB, zero-field opacity, foreground alpha, and
post-quantizer alpha outputs all fail closed. Two independent proof writes are
byte-identical at
`8e259ddf68e830aebfa31127e89f63eb3716dbe9d8068e6c2cc25ce663efb326`.

Both tools compile with warnings-as-errors. The historical `8fac58b` rejection
packet remains byte-identical. No capability preflight, Metal process,
SceneKit snapshot, PNG, review packet, normalization, or other direction was
run. A new governed process requires a separate integration disposition.
