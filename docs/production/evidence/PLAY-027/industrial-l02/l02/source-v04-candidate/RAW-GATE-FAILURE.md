# Industrial L2 source-v04 raw gate failure

Disposition: **frozen after repeat-identity failure; not a review candidate.**

The source-v04 descriptors were rendered in twelve fresh Metal-visible
processes with descriptor-bound `sceneKitShadows: disabled`. Every provenance
record reports the schema-2 v3 no-MSAA, factor-4, software-Lanczos pipeline,
effective disabled SceneKit shadows, Apple M5 Pro device visibility, unchanged
descriptor geometry, and `productionSelected: false`.

North passed exact three-process file and decoded-pixel identity. East failed:
the primary and run C share file SHA-256
`c17349b7b711cf4d3786ff8ea040d2e5f8d706eb85fe353a418bb37bfd16fa23`,
while run B has
`1a22b9a6bddfad198de8b585c7f319569902c26b63324be2e2ef8eb74b5a2ebc`.
Their decoded-pixel hashes are also distinct. All three East files remain
complete, opaque, flat-chroma renders with identical occupied bounds, so this
is a deterministic-identity failure rather than a completeness failure.

The governed stop was applied at East. South and West primary/B/C files had
already emitted in the render batch and are retained, but their formal repeat
validators were not run after the stop. No four-direction uniqueness,
normalization, LOD validation, or review-sheet generation was performed.

This result disproves sufficiency of the narrow source-v04 repair on the
current host/toolchain. It does not authorize a source-v05, a changed sampler,
another renderer diagnostic, or acceptance of either East identity.
