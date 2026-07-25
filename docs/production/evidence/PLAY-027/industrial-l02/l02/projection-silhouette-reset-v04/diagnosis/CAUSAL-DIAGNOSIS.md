# PLAY-027 Industrial L2 East v04 causal diagnosis

The retained v03 frame is compressed before chroma composition. Weighted visible material bases have p25 106, IQR 67, and p95 207. The same geometry-owned opaque pixels fall to p25 48, IQR 37, and p95 141 after SceneKit Lambert/key/ambient response. The frozen quantizer then yields p25 48, IQR 39, and p95 148; it preserves the already-compressed distribution rather than creating the broad loss.

Six referenced pattern declarations are not implemented by the frozen renderer dispatch: v02-formed-concrete:procedural-large-formed-panels, v02-galvanized:procedural-wide-corrugation, v02-industrial-glazing:broad-mullion-grid, v02-painted-steel:procedural-wide-corrugation, v02-safety-trim:painted-safety-steel, v02-warm-concrete:procedural-large-formed-panels. Their pattern images therefore contain only the base fill, explaining the flat main facade and safety hierarchy without requiring a new render.

The chroma defect is a separate compositor-stage issue. All 8460 non-exact near-magenta raw pixels are classified against the retained genuine pre-chroma alpha in `MATERIAL-SEGMENTATION.json`; the neutral alpha composite contains 0 magenta-family pixels. V04 therefore freezes a task-owned straight-alpha flat-chroma contract that never mixes magenta into a nonzero-alpha foreground sample.

The v04 descriptor retains the canonical v03 geometry, camera, registration, component dimensions, feature spans, sockets, and authored shadow byte-equivalently after excluding material identifiers. Its material and light reset is analytic only. No Metal process, SceneKit snapshot, governed raw, normalization, or production selection is claimed.
