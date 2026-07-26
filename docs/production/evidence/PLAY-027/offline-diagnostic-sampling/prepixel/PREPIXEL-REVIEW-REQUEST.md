# PLAY-027 offline diagnostic sampling pre-pixel review

Exact scope: task-owned offline tooling only. No building source, descriptor,
material, geometry, camera, shipping/runtime surface, raw source, normalized
source, or production selection changed.

The additive option
`play027-diagnostics-4x-no-msaa-software-lanczos-v1` resolves only when
explicitly requested and when output plus record are new repository files
under `/diagnostics/`. Nil invocation is a no-op. The default factor-2 +
SceneKit 4x-MSAA sampling contract remains declared and its software-Lanczos
fixture replay is pixel-byte-identical to the pre-refactor inline reference.

Three fresh native-framework synthetic processes produced identical input,
Lanczos, final PNG, decoded RGBA, and report hashes. The suite covers impulses,
one-pixel and two-pixel lines, diagonal edges, alpha
`0/1/8/9/64/128/254/255`, exact chroma boundary, eight grayscale patches, and
footprint/socket markers. The processes invoked neither SceneKit nor Metal.

One initial sandboxed synthetic process is retained as an environment failure:
it wrote only the deterministic input and could not create a software Core
Image output. It is excluded from the three passing processes and did not
produce a result that could be tuned or substituted.

Requested disposition: independent approval or rejection of this pre-pixel
tooling boundary before any SceneKit/Metal render. This record is not source
acceptance, production selection, or render authority.
