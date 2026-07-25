# CONTRACT-011: Offline directional scene authoring

**Status:** Approved for PLAY-027 calibration

**Date:** July 24, 2026

## Context

The governed PLAY-027 ImageGen probes proved that built-in whole-building
generation can produce attractive isometric residential appearance, but it
cannot reliably preserve a non-near road-frontage plane/socket or a
mathematically flat chroma field. The exact rejected attempts and capability
limit are retained on the world-art branch at `2b4da07`.

Further whole-building prompt iteration is not authorized. Production-quality
directional art still requires separately authored north, east, south, and
west views with deterministic geometry, pivots, frontage, light, shadow, and
registration.

## Decision

PLAY-027 may use an offline, deterministic four-scene authoring pipeline for
directional building sources.

The initial implementation must use macOS-native offline scene/rendering
frameworks already available to the repository environment, such as SceneKit,
Model I/O, Core Image, and Core Graphics. It must remain a task-owned source
tool under `Native/CitySimNative/WorldArt/` and may not add a product runtime
dependency, change `Package.swift`, or enter the shipping application.

Each logical building variant must have four explicit scene descriptors:

```text
<logical-building-id>/<variant-id>/<view-direction>/scene.json
```

Every descriptor independently declares the facade topology, entrance
geometry, frontage edge/socket, props, and occlusion exclusions for that
direction. Shared structural modules and material libraries are allowed, but
no scene or rendered raster may be created by mirroring, rotating, or
transforming a sibling direction.

## ImageGen boundary

Built-in ImageGen is no longer authorized to compose a complete building for
PLAY-027. It may be used only for non-compositional material swatches or
surface-detail inputs that:

- contain no facade, entrance, footprint, camera, light, shadow, road, parcel,
  state, label, selection, or agent composition;
- are normalized into a declared physical scale and material channel;
- retain prompt, model, provenance, source hash, crop, and rejection records;
- cannot determine massing, silhouette, geometry, frontage, or registration.

## Deterministic render contract

The offline source renderer must freeze and report:

- tool and framework versions plus source commit;
- 2:1 orthographic camera, output registration, and oversampling factor;
- 72 x 36 point tile basis, footprint, pivot, envelope, and contact polygon;
- northwest key light and southeast shadow receiver/vector;
- material-library, scene-descriptor, raw-render, and normalized-output hashes;
- a mathematically flat `#ff00ff` source field before existing deterministic
  normalization;
- repeat-run byte identity for scene metadata and pixel identity for raw and
  normalized output on the approved host/toolchain.

The renderer may not infer geometry, pivot, frontage, or state from generated
pixels. It may not bake roads, parcel markings, UI, selection, labels, agents,
or gameplay truth into source art.

## Calibration gate

Authorization is limited initially to one residential level-1 variant-zero
N/E/S/W calibration set.

Before the remaining 44 R/C/I sources may begin, that set must provide:

1. four separately authored scene descriptors and four unique source hashes;
2. exact pivot, footprint, socket, door-base, contact, scale, projection,
   light, shadow, alpha/chroma, and envelope validation;
3. source-size, native-2x actual-scale, and unlabeled grayscale contact sheets;
4. repeat-run determinism and complete source/tool/material provenance;
5. no cross-direction or cross-type aliasing;
6. independent source-art review approving family recognition, silhouette,
   material quality, frontage correctness, and game-scale readability.

A failed direction is preserved and repaired in its own scene. The pipeline
must not transform a passing sibling to replace it.

## Ownership and integration

- The world-art cell owns the task-local offline tools, scene descriptors,
  material inputs, raw masters, validators, and PLAY-027 evidence.
- Integration owns this contract, toolchain changes outside task-owned
  sources, batch expansion, and independent-review disposition.
- The world-rendering lane later owns atlas ingestion, stable runtime
  selection, staged-app proof, and performance after an accepted source batch.
- No PLAY-027 output is production-selected or shipped by this contract.

CONTRACT-006 and CONTRACT-010 remain authoritative. This contract changes only
the approved source-authoring method after the documented ImageGen capability
limit.
