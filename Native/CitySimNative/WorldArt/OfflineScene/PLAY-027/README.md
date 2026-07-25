# PLAY-027 offline directional scene authoring

This task-owned source tool implements the CONTRACT-011 calibration boundary.
It is not part of `CitySimNative`, is not referenced by `Package.swift`, and
does not enter the application runtime or shipping asset pack.

## Fixed calibration scope

The only authorized initial batch is:

```text
residential_l01/variant-0/{north,east,south,west}
```

Every direction has its own complete `scene.json`. Each descriptor explicitly
defines all four facade planes, window bays, its one direction-specific
entrance, props, and occlusion exclusions. Sibling descriptors and rasters may
not be mirrored, rotated, or transformed.

## Native renderer architecture

The offline pipeline has six explicit stages:

1. `SceneDescriptor` decodes one independently authored scene and rejects any
   sibling derivation, transform, missing facade, or misplaced entrance.
2. Model I/O supplies deterministic mesh topology and vertex data. SceneKit
   owns the offline scene graph, orthographic camera, materials, and light.
3. The fixed camera renders a 2:1 projection at 2x oversampling. Descriptor
   geometry owns massing and the entrance; no generated pixel owns geometry.
4. Core Image performs the declared Lanczos downsample and source-color-space
   conversion.
5. Core Graphics composites the exact registration offset, southeast shadow,
   and mathematically flat `#ff00ff` source field.
6. The writer strips variable metadata and emits raw PNG plus a sorted,
   hash-complete render record. Existing deterministic normalization remains a
   later, separately recorded stage.

The camera is identical across directions. Direction changes are expressed by
independently authored facade and entrance geometry in world space, never by
rotating a camera, a scene, or a sibling raster.

## Standalone compilation

Tools compile outside the product package:

```bash
mkdir -p /private/tmp/play027-offline-tools
env CLANG_MODULE_CACHE_PATH=/private/tmp/play027-module-cache/clang \
  SWIFT_MODULECACHE_PATH=/private/tmp/play027-module-cache/swift \
  xcrun swiftc -parse-as-library \
  Sources/SceneDescriptor.swift \
  Sources/RendererArchitecture.swift \
  Tools/ValidateScenes.swift \
  -framework SceneKit -framework ModelIO -framework CoreImage \
  -framework CoreGraphics \
  -o /private/tmp/play027-offline-tools/validate-scenes
```

No committed binary, new package target, build-script hook, or product
dependency is permitted.

## Registration

- source canvas: 1536 x 1024 pixels;
- tile basis: 72 x 36 points;
- source diamond: 512 x 256 pixels;
- source ground center: `(768,768)`;
- source ground pivot: `(768,896)`;
- native-2x diamond: 144 x 72 pixels;
- actual-scale factor: `144 / 512 = 0.28125`;
- projection: fixed orthographic 2:1;
- light: northwest key;
- shadow: southeast vector `(2,1)`;
- orientation transform: none;
- production selected: false.

## Hard gate

After four raw and normalized calibration sources, source-size, native-2x,
and unlabeled grayscale sheets are returned for independent art review.
No commercial, industrial, higher-level, or additional variant work may start
without integration authorization.
