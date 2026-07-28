# PLAY-027 Industrial L4 v17 semantic visibility checkpoint

Disposition: `CHECKPOINT_BLOCKED_BEFORE_SEMANTIC_VISIBILITY_PROOF`

The task-owned implementation compiles with warnings as errors and constructs
the exact v17 SceneKit node graph without rendering. It extracts deterministic
world-space triangle and node records, classifies portal and occluder
components, projects the fixed camera, and records 6,973,338 occupied samples
inside the exact 4x crop.

The one final bounded tiled-Lanczos repair still failed while materializing the
first supported 832x832 tile to 208x208. The exact command and error are in
`FAILURE-RECEIPT.json`. No semantic visibility report or panel is retained as
proof, the actual-scale gate is unrun, and no North revision is authored.

This checkpoint preserves useful extraction/node-manifest tooling for a
renderer-owned visibility probe. It does not authorize raw rendering,
normalization, source authority, production selection, or geometry acceptance.
