# PLAY-027 Industrial L2 East complete 4x capture freeze

This checkpoint adds diagnostic-only support to persist the complete
pre-canonical SceneKit 4x RGBA frame. It does not change the frozen authored
scene, material library, topology, camera, registration, light, shadow,
sampling, compositor, quantizer, normalizer, or any prior v05/v06/v07 source,
rejection, provenance, or toolchain record.

The renderer accepts exactly:

- contract
  `industrial-l02-source-v06-east-full-precanonical-rgba-v1`;
- the immutable source-v06 East scene from Git object
  `ac523576aac0fee3b2f0b2a4f64f6b2b892415b9` at ancestor
  `6d3dffd60925ad1aa1a4babcf6c959b44d324714`;
- scene SHA-256
  `70b36a0e76581524e64d40f19e364659eed6a53d7f7ab8d8924c51ba5d0951dd`;
- unchanged material SHA-256
  `4f4e34aa87891d70c442e596315bcbd474f059638c0af69abe6ecaac17af0815`;
- Industrial L2 variant-zero East source-v06, `productionSelected:false`;
- descriptor-bound no-MSAA, disabled SceneKit shadows,
  authored-constant lighting, 4x oversampling, and no pre-Lanczos
  canonicalizer;
- explicit diagnostic `none/current/current`, coordinate `(707,687)`;
- a new `run-a`, `run-b`, or `run-c` directory beneath the exact task-owned
  evidence root.

Each admitted process writes `PRE-CANONICAL-4X.png` as lossless sRGB RGBA8,
decodes it immediately, and rejects unless all `6144 x 4096 x 4` decoded bytes
equal the immutable in-memory frame. The default renderer path is a no-op for
this contract. Revision, direction, descriptor hash, descriptor path,
coordinate, evidence-root, partial-alpha, and overwrite drift fail closed.

No diagnostic pixels exist at this checkpoint.
