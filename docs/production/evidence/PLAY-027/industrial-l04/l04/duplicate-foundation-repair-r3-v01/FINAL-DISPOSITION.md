# PLAY-027 CONTRACT-019 R3 disposition

`RETURN_REMAINING_REPEAT_SPLIT`

The duplicate-foundation repair is structurally correct but does not satisfy
the binding semantic repeat gate. Exactly two diagnostic-only SceneKit/Metal
processes were consumed. No authoritative raw, normalizer, sibling, modeling,
source-authority, production-selection, ingestion, or shipping process ran.

Both runs bind the exact v18 descriptor, unchanged material library, exact
renderer binary, and identical 51-node semantic manifest
`611d60db7d39c9c0de73d1042f658c08e18c2d26bf4be9b7af3c6f577593a94f`.
The redundant 56×1.4×56 foundation no longer exists in either scene.

- renderer binary SHA-256:
  `4a84e2e49928eb57cced9a2005bb505c47217cc947f6143c86c1b8c855487b36`
- summary source SHA-256:
  `2082162b5be13ae8bb6bdece744a0353c7966e3d3aa718e61c82f1b87b632b07`
- summary binary SHA-256:
  `163e75e3a92d3ab339e33865044cefcbbaadbd2fc16b5f6e3bff32335cf4c618`

The outputs still split:

- run A PNG:
  `39c5a71a3a185a125b3404a72a36deae5274833a3e6b81f01a063fb7f9db1ade`
- run A decoded RGBA:
  `dab941daf6be1539218ee030cd8ddd32474b1296eaef0268d84c54301fe37925`
- run B PNG:
  `d9932be72d4538da41eb096c426e416e34f5eb4a40baf29dfcf32ec1bce0595e`
- run B decoded RGBA:
  `48e76f3adedc5969cef212a89487275c8c6b89cfaa8eb674ec357c040f399641`
- differing pixels: `143`
- differing channels: `167`
- difference bounds: `[558,688,731,743]`
- first difference: `(719,688)`, run A `[240,48,16,255]`, run B
  `[240,80,16,255]`

The dominant remaining transition is
`portal-header -> crucible-occluder` (`85` pixels), followed by
`other -> hall` (`24`) and `portal-header -> portal-jamb-north` (`15`).

Portal counts therefore do not remain exact across the two processes. Run A
reproduces the returned-v17 source/compact counts exactly. Run B retains the
south jamb (`155` source / `3` compact) and inset (`3388` / `57`), but changes
the north jamb to `1583` source pixels and the header to `1175` source /
`17` compact pixels.

The deterministic no-Metal summary replay is byte-identical. CONTRACT-019 R3
requires an immediate stop on any split, so no further diagnostic process or
portal modeling is authorized.
