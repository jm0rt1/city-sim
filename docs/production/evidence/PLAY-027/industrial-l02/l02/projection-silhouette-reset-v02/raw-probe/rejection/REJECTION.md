# PLAY-027 Industrial L2 East v02 primary probe — rejected before pixels

Disposition: **REJECTED_PRE_RENDER_TECHNICAL_GATE**. This is not source-art acceptance or production selection.

The one authorized fresh Metal-visible process reached the renderer capability preflight and built the frozen East scene, then failed the existing `validatedRenderedNodeBounds` completeness invariant before `NativeSourceRenderer.renderSource` could invoke a SceneKit snapshot:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level: rendered-node bounds do not contain the complete building volume
```

The shell exit status was `133`. The exact output directory remained absent. Therefore:

- governed flat-chroma raw: not emitted;
- genuine pre-chroma RGBA intermediate: not emitted;
- neutral alpha-respecting composite: not emitted;
- provenance and raw hashes: unavailable because no image was emitted;
- raw-only alpha, chroma, registration, luma, feature-survival, and visual panel gates: not runnable;
- Metal-visible process count: one;
- governed SceneKit snapshot count: zero;
- rerenders, repairs, other directions, B/C, normalization, and LOD generation: zero.

The frozen scene descriptor, material library, and pre-pixel validator remain byte-identical to the approved checkpoint. The probe’s in-memory decoder compatibility supplies only the four anchor metadata fields required by the legacy `MaterialLibraryDescriptor` decoder, after proving both immutable anchor files by SHA-256. It does not modify the approved material JSON or any rendered material definition.

No attempt was made to relax, bypass, reinterpret, or repair the rendered-node completeness invariant. The requested pixel panels and metrics cannot truthfully be produced from a pre-snapshot failure. Any causal diagnosis or descriptor repair requires a new integration disposition.

`productionSelected` remains `false`.
