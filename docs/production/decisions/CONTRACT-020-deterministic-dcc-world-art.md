# CONTRACT-020: Deterministic DCC world-art rendering

**Status:** Approved for PLAY-027 Industrial L4 calibration

**Date:** July 28, 2026

## Context

CONTRACT-019 R5 reached `HARD_PIPELINE_LIMIT`. Exact candidate bindings,
explicit `prepare`, fixed time, two warmups, no MSAA, a removed duplicate
foundation, and a bounded portal-joint depth rule still produced
process-dependent SceneKit pixels. The final R5 A/B diagnostic differs across
`195` pixels and `346` channels. The depth rule was rolled back.

SceneKit remains valid for the shipping SpriteKit product and for already
accepted historical source masters. It is closed as the authority renderer
for new PLAY-027 source art because exact candidate identity cannot be proved.

Blender `4.5.12 LTS`, build `84afd5f785f7`, is installed as a local
development tool at:

```text
/Applications/Blender.app/Contents/MacOS/Blender
```

It is not a product dependency.

## Decision

PLAY-027 may build a deterministic, headless Blender/Cycles CPU source-art
pipeline under:

```text
Native/CitySimNative/WorldArt/Blender/PLAY-027/
```

The pipeline may consume the existing explicit scene descriptors and material
libraries, but Blender becomes the source-authority renderer for new
Industrial L4 work. Existing SceneKit raws and evidence remain immutable.

## Frozen toolchain

Every process must use:

- Blender `4.5.12 LTS`, build hash `84afd5f785f7`;
- `--background --factory-startup --disable-autoexec`;
- Cycles on CPU only;
- one fixed render thread;
- fixed random seed and sample count;
- adaptive sampling disabled;
- denoising disabled;
- motion blur disabled;
- transparent film;
- fixed resolution, percentage, pixel aspect, color management, exposure, and
  gamma;
- no external add-ons, network assets, user startup files, or nondeterministic
  procedural inputs; and
- `--python-exit-code 1`.

The task-owned fingerprint records the Blender executable SHA-256, full
`--version` output, Python version, machine architecture, operating system,
Cycles settings, scene-builder hash, descriptor/material hashes, and exact
command.

## Authored scene contract

North, east, south, and west remain separately authored scenes. A shared
importer and material library are allowed, but no accepted view may be
mirrored, rotated, or transformed from a sibling.

The Blender scene builder must preserve or explicitly validate:

- 2:1 orthographic camera and fixed road-facing view;
- 72 × 36 tile basis, footprint, pivot, frontage socket, contact polygon, and
  vertical envelope;
- northwest key light and southeast contact shadow;
- explicit named components and stable node/object IDs;
- authored floor, door, window, prop, and material scale;
- source, native-2x, literal-192, and shipping LOD registrations; and
- no roads, labels, selection, UI, agents, or gameplay state baked into art.

Blender source scenes must be reconstructible from committed text inputs and
scripts. A binary `.blend` may be retained as evidence, but it cannot be the
only editable authority.

## Determinism gate

Every calibration or candidate uses three fresh Blender processes. Acceptance
requires:

- identical decoded RGBA pixels across A/B/C;
- identical occupied bounds, alpha, registration, and component/object
  manifests;
- zero hidden RGB and zero visible chroma spill;
- no nondeterministic timestamps or paths in authority manifests;
- byte-identical deterministic post-render evidence;
- unchanged output when rerun from `--factory-startup`; and
- a retained source/native-2x/literal-192 color and grayscale packet.

PNG container bytes may differ only if decoded RGBA and a separately audited
metadata inventory prove the difference is non-pixel metadata. Authority
manifests bind decoded RGBA.

## Initial calibration

Authorization is initially limited to one Industrial L4 North transfer:

1. import exact v18 geometry, materials, camera, registration, socket, contact,
   and light semantics without redesigning the portal;
2. prove object/geometry mapping and three-process decoded identity;
3. compare the Blender transfer with retained v18 SceneKit and accepted
   Industrial L3 at source, native-2x, and literal 192;
4. prove the existing three-pixel south-jamb failure remains visible rather
   than being hidden by the migration; and
5. return for independent Renderer and QA pipeline review.

Only after calibration passes may Integration authorize a Blender-native
Industrial L4 North art revision. That revision must materially improve the
full unlabelled literal-192 building, not merely a semantic mask.

## Quality bar after calibration

The Blender-native Industrial L4 family must use the DCC pipeline to deliver:

- materially richer silhouette, bevel, facade depth, glazing, metal, masonry,
  roof equipment, and contact shadow than accepted L3;
- one monumental road-served recessed freight portal recognizable within two
  seconds at literal 192;
- two supporting sides, a clear header, contiguous dark inset depth, and
  separation from gantry/crucible;
- distinct N/E/S/W frontage and authored occlusion;
- coherent material and massing identity across directions; and
- no alias, recolor-only substitute, mirror, runtime rotation, or fallback.

## Ownership and stop gates

World Art owns the task-local Blender scripts, text scene sources, material
inputs, raw masters, manifests, validators, and PLAY-027 evidence. Integration
owns this contract, toolchain admission, batch expansion, and source
acceptance. Renderer later owns shipping ingestion.

Stop on:

- any decoded-pixel repeat mismatch;
- an importer that changes geometry or registration without explicit proof;
- user configuration or add-on dependence;
- GPU/Cycles Metal rendering;
- missing text source authority;
- whole-building ImageGen composition;
- direct edits to shipping atlases, product Rendering, `Package.swift`,
  gameplay, simulation, UI, or saves; or
- self-acceptance, push, ingestion, normalization authority, or production
  selection.
