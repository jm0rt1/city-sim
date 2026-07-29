# PLAY-027 diagnostics-only 4x sampling pipeline

**Status:** Pre-pixel tooling candidate; no source-art or shipping authority.

**Contract ID:** `play027-diagnostics-4x-no-msaa-software-lanczos-v1`

The option is additive and must be requested explicitly with
`--diagnostic-sampling-pipeline`. A nil/default invocation resolves no
diagnostic contract and preserves the descriptor-resolved path. The option
does not edit the descriptor, materials, geometry, camera, lights, shadows,
pivot, socket, or final `1536x1024` registration.

The frozen diagnostic path is:

1. SceneKit antialiasing `none`;
2. fixed four-times linear source dimensions with the existing orthographic
   frustum and world geometry;
3. one software `CILanczosScaleTransform`, scale `0.25`, aspect ratio `1`;
4. crop to the final registered extent without clamp, wrap, or a second
   resample;
5. the descriptor's existing quantizer, compositor, post-quantization
   canonicalizer, ImageIO encoder, and `/usr/bin/sips` canonical PNG pass.

The Core Image context is frozen to software rendering, no intermediate
cache, extended-sRGB working color space, and sRGB output color space. The
filter/kernel identifier is `CoreImage.CILanczosScaleTransform`. Determinism
is established only by fresh-process output identity, not by the API choice.

The mode fails closed unless both output and provenance are new files under a
repository `/diagnostics/` path. It rejects production-selected sources,
missing descriptor/source provenance, unknown modes, independent
antialiasing/shadow/lighting overrides, and simultaneous diagnostic
isolation/stage contracts.

The renderer provenance binds the pipeline name/version, declared and
effective sampling contracts, descriptor hash, renderer source commit,
SceneKit antialiasing, oversampling, filter/kernel/scale/aspect/border,
Core Image context/color spaces, quantizer/canonicalizer, source hashes, and
final registration. `productionSelected` remains `false`.

No SceneKit or Metal pixel process is part of this checkpoint.
