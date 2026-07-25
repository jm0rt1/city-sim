# PLAY-027 offline directional scene authoring

This task-owned source tool implements the CONTRACT-011 calibration boundary.
It is not part of `CitySimNative`, is not referenced by `Package.swift`, and
does not enter the application runtime or shipping asset pack.

## Authorized and accepted source scope

CONTRACT-011 initially authorized only the Residential L1 calibration:

```text
residential_l01/variant-0/{north,east,south,west}
```

That calibration was independently accepted at
`6380037d42ede73eca60aac4a9b1c7b710f681d6`. Integration then authorized the
next controlled source slice:

```text
residential_l02/variant-0/{north,east,south,west}
residential_l03/variant-0/{north,east,south,west}
residential_l04/variant-0/{north,east,south,west}
```

The complete Residential L2-L4 slice was independently accepted at
`8f928ed5dd01453ff9d4d9910858d8bf786afa9d`. Integration then authorized the
Commercial L1-L4 source slice under a level-by-level review gate. Commercial
L1 `source-v04` was accepted as non-shipping source-art authority at
`9718b5e63d6322daa5b9616aea31244b3f3d6629`. Commercial L2 `source-v01` was
accepted as non-shipping source-art authority at
`a224937e6aaae9c4824566403ead8c6087d646d9`. Commercial L3 `source-v01` was
accepted as non-shipping source-art authority at
`71655d5dbaf8a56fa287e68b5b99159ee4ba6144`. Commercial L4 is authorized from
that exact base:

```text
commercial_l04/variant-0/{north,east,south,west}
```

Commercial L4 remains non-shipping and requires independent review before any
production selection. Industrial source production remains unauthorized.

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

The structural-boundary validator compiles from the same task-owned descriptor
model and rejects exact shared Y planes between overlapping authored mass,
roof, trim, chimney, and rooftop-prop volumes:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/play027-module-cache/clang \
  SWIFT_MODULECACHE_PATH=/private/tmp/play027-module-cache/swift \
  xcrun swiftc -parse-as-library \
  Sources/SceneDescriptor.swift \
  Tools/ValidateStructuralBoundaries.swift \
  -o /private/tmp/play027-offline-tools/validate-structural-boundaries
```

Retained raw failures can be localized without changing source art using the
task-owned ImageIO/Core Graphics comparator:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/play027-module-cache/clang \
  SWIFT_MODULECACHE_PATH=/private/tmp/play027-module-cache/swift \
  xcrun swiftc -parse-as-library \
  Tools/CompareRetainedRawPixels.swift \
  -framework CoreGraphics -framework ImageIO \
  -framework UniformTypeIdentifiers -framework CryptoKit \
  -o /private/tmp/play027-offline-tools/compare-retained-raw-pixels
```

The task-owned native source normalizer compiles independently as well:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/play027-module-cache/clang \
  SWIFT_MODULECACHE_PATH=/private/tmp/play027-module-cache/swift \
  xcrun swiftc -parse-as-library \
  Tools/NormalizeOfflineSource.swift \
  -framework CoreGraphics -framework ImageIO \
  -framework UniformTypeIdentifiers -framework CryptoKit \
  -o /private/tmp/play027-offline-tools/normalize-offline-source
```

It is an offline source tool only. It is not referenced by `Package.swift`,
the application runtime, a build script, a shared manifest, or a shipping
asset selection.

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

Residential L1 and Residential L2-L4 have passed their independent source-art
gates. Commercial L1, Commercial L2, and Commercial L3 are accepted as
non-shipping source-art authority. Commercial L4 alone is authorized from
`71655d5dbaf8a56fa287e68b5b99159ee4ba6144` for governed source production and
independent review. Industrial, additional variants, renderer ingestion,
packaging, and production selection remain blocked without further integration
authority.
