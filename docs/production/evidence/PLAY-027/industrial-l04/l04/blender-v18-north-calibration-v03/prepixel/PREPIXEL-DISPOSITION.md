# PLAY-027 CONTRACT-020 R3 pre-render disposition

Disposition: `PASS_PREPIXEL_GROUND_REGISTRATION`

The successor v03 calibration preserves the immutable v18 North descriptor,
13-material library, 51-component mapping, camera position and target, contact,
light, and Cycles settings. It retains the accepted R2 orthographic scale
`237.5878601074218` and applies the published Blender landscape shift formula:
`shift_x = 0 / 1536` and `shift_y = 128 / 1536`.

The native factory-startup `PREPIXEL` process constructed the complete scene and
configured camera, then exited before any `bpy` render call. It projected the
actual CitySim ground plane `y = 0` as follows:

- footprint: `[768,640]`, `[1024,768]`, `[768,896]`, `[512,768]`;
- pivot: `[768,896]`;
- North socket: `[896,704]`;
- world origin: `[768,768]`;
- maximum absolute projection error: `0.00018310546875` source pixel;
- edge contact: `false`.

The previous derived registration plane is absent. A/B/C process count remains
zero. This is a durable mechanical camera-registration boundary, not source
authority, production selection, portal redesign, sibling work, normalization,
ingestion, or shipping approval.

Binding evidence:

- `VALIDATION.json`
- `R2-R3-CONTRACT-DIFF.json`
- `projection-proof/PROJECTION-PROOF.json`
- `projection-proof/object-mapping.json`
