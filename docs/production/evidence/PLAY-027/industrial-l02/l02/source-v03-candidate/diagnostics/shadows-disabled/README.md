# Industrial L2 source-v03 shadows-disabled isolation

Disposition: **PASS as causal diagnostic evidence; not source-art acceptance.**

This packet changes one renderer variable for unchanged Industrial L2 source-v03 North and East scenes: every SceneKit light has `castsShadow` disabled. The diagnostic keeps the accepted schema-2 v3 no-MSAA, 4x linear oversampling, software Lanczos, quantizer, canonicalizer, fixed camera, geometry, materials, light placement, chroma background, and output size unchanged.

The override is hard-guarded to diagnostic output and record paths. A deliberately forbidden non-diagnostic invocation exited 133 before creating either output. Every retained provenance record declares `sceneShadows: disabled`, `descriptorGeometryChanged: false`, and `sourceAuthority: false`.

## Results

- North is byte- and pixel-identical across three fresh Metal-visible processes: file SHA-256 `f4bcd27762f966057f2c544991bddc28e7b1e6d77fcaad49363880adf502d853`, decoded-pixel SHA-256 `3e4055f747c2ba828dc4a85ae288a1af485842fc573c5fac6e45692ba6930cb6`.
- East is byte- and pixel-identical across three fresh Metal-visible processes: file SHA-256 `1a22b9a6bddfad198de8b585c7f319569902c26b63324be2e2ef8eb74b5a2ebc`, decoded-pixel SHA-256 `ea439d006928fa6d205da1f31b216c48545095c9779b9f8920839348484d0367`.
- Exact retained-byte RGBA validation passes for all six files. North has 69,418 visible non-chroma pixels in bounds `[619,578,1029,906]`; East has 67,598 in `[619,597,1029,906]`. Both have visibility ratio 1.0, zero hidden non-magenta pixels, matching RGB/alpha bounds, and flat opaque chroma corners.
- North's deterministic result is byte-identical to the retained current-shadow primary identity. East's deterministic result is byte-identical to retained current-shadow run C. The current-shadow path therefore intermittently emitted the same shadow-absent identity now produced deterministically.
- Comparing retained shadow-present B identities to the deterministic results localizes 1,157 changed North pixels to `[771,701,801,807]` and 603 East pixels to `[682,687,712,781]`, with zero alpha differences. The no-shadow A/B comparisons have zero pixel differences.

The controlled visual sheet [CURRENT-VS-NO-SHADOW.png](CURRENT-VS-NO-SHADOW.png) places current-shadow B and shadows-disabled A side by side for North and East. All four panels preserve the complete building, loading frontage, footprint, registered southeast ground shadow, material hierarchy, and silhouette. The disabled result removes localized facade shadow blotches. This is a diagnostic comparison, not an art disposition.

## Causal conclusion

SceneKit shadow rasterization is the remaining nondeterministic stage for these unchanged scenes. Disabling only SceneKit shadow maps makes both affected directions exactly deterministic across fresh Metal-visible processes while converging to identities already observed in the current-shadow failure packet. No descriptor, material, candidate raw, accepted art, South/West evidence, or normalized output was changed.

## Proposal — not implemented

If integration separately authorizes a production repair, introduce a backward-compatible, descriptor-bound sampling revision for new sources that disables SceneKit shadow maps. Preserve schema-2 v3 no-MSAA, 4x oversampling, software Lanczos, fixed projection, authored northwest lighting, and the deterministic registered southeast footprint shadow already produced by the offline compositor. Do not reinterpret accepted descriptors and do not expose an opportunistic production CLI choice.

Before any source revision can be considered, freeze the additive descriptor/schema and tests, then require three-process N/E/S/W raw identity, two normalization runs, full uniqueness and registration/RGBA/chroma/alpha/spill/padding gates, complete original-scale review panels, and byte-preservation regression for all accepted Residential, Commercial, and Industrial L1 art.
