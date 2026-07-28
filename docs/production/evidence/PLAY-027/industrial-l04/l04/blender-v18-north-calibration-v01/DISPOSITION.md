# PLAY-027 CONTRACT-020 Blender North calibration disposition

**Disposition:** `REJECTED_REGISTRATION_GATE`

The committed text-authority/importer checkpoint is `e740bfd0`. Its no-render
preflight passed twice byte-identically with all 51 v18 rendered components
and 13 material roles accounted for.

Fresh Blender process A completed under the exact committed factory-startup,
Cycles CPU, one-thread contract. It emitted:

- `diagnostics/run-a/raw.png`
- `diagnostics/run-a/semantic.png`
- `diagnostics/run-a/object-mapping.json`
- `diagnostics/run-a/provenance.json`

The immediate canonical RGBA gate found:

- raw file SHA-256:
  `3fec725cab9a1f1dbefedc4f63c015af9d8def84da27ae07aa7e373de91e0f7e`;
- decoded premultiplied RGBA SHA-256:
  `319f80f786c449d958ba50adc934532b1b2a56ce5e005b337483cfcf9cfeaea2`;
- dimensions: `1536x1024`;
- alpha bounds: `[275,531,1153,1024]`;
- padding: `[275,531,383,0]`;
- hidden RGB pixels: `0`;
- opaque chroma pixels: `0`;
- visible near-magenta spill pixels: `0`; and
- alpha/chroma gate: pass.

Bottom padding is zero, so the transferred object/contact field reaches the
lower canvas boundary. That violates CONTRACT-020's exact registration and
padding requirement. Process A is therefore a calibration rejection, not a
source candidate.

Processes B and C were not run. No SceneKit process, normalizer process,
sibling direction, source authority, production selection, ingestion, or
shipping work was performed. The committed importer was not changed after
process A. A future integration authority must explicitly decide whether to
correct Blender camera-shift/registering semantics and authorize a new
three-process calibration.
