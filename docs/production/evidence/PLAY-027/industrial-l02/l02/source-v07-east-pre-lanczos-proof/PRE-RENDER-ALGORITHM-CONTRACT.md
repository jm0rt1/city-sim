# PLAY-027 Industrial L2 East source-v07 pre-Lanczos contract

This revision changes the task-owned offline sampling pipeline only. The
Industrial L2 East authored scene, topology, material library, camera, light,
shadow, footprint, pivot, socket, frontage, and registration payload are
identical to frozen source-v06.

The complete SceneKit 4× frame is decoded once to immutable sRGB RGBA8. One
pure transform then visits each pixel independently:

1. Exact opaque `#ff00ff` is copied byte-for-byte.
2. Fully transparent pixels retain alpha zero and receive zero hidden RGB.
3. Fully opaque, non-chroma RGB channels use the frozen mapping
   `min(255, ((value + 8) / 32) * 32 + 16)`.
4. Any alpha value other than `0` or `255` rejects the frame.
5. Alpha is never written. The transform has no prior-run input, voting,
   cache, seed, process state, neighborhood dependency, or scan-order
   dependency.

The output is passed to the existing software
`CILanczosScaleTransform` scale `0.25` path. The existing post-Lanczos
quantizer, schema-2 v3 isolated-pixel canonicalizer, ImageIO/sips PNG
canonicalizer, compositor registration, and authored contact shadow remain
unchanged.

The fail-closed tests bind the algorithm ID, version, step, midpoint,
chroma key, alpha policies, immutable buffer, and no-state declaration. They
also prove exact chroma preservation, alpha preservation, transparent hidden
RGB cleanup, same-bucket convergence, no broadening across a quantization
boundary, dimension rejection, partial-alpha rejection, and contract-drift
rejection.

The governed render gate remains stricter than the unit tests: all three
canonicalized full 4× frame hashes must match exactly. A single mismatch
rejects and freezes the attempt before normalization.
