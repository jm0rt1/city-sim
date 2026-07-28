# PLAY-027 Industrial L4 Blender registration R2 authority

**Integration authority:** `219445009c50b5faece7c160c3755120e5a684a4`

**Returned calibration:** `514fc80dcdbcd7b9a06866ed5d5650d799871d0a`

**Disposition:** `AUTHORIZED_CAMERA_REGISTRATION_REPAIR`

The first Blender/Cycles North transfer is visually coherent and preserves all
51 governed v18 components and 13 material roles, but it failed the
registration gate because its authored contact field reached the bottom of the
1536x1024 source canvas. Processes B and C correctly did not run.

The defect is a closed camera-semantics mismatch, not an art or geometry
failure. The current importer sets:

```text
Blender ortho_scale = 2 * SceneKit orthographicScale
```

That assumes Blender's landscape orthographic scale is the vertical view span.
The retained process-A pixels prove that Blender applies this scale across the
landscape frame width. With a 1536x1024 viewport, the imported foundation is
therefore magnified by exactly `1536 / 1024 = 1.5`.

## Exact R2 correction

World Art may create one successor North-only calibration revision whose only
rendering change is:

```text
aspect = renderViewportPixels.width / renderViewportPixels.height
Blender ortho_scale =
    2 * SceneKit orthographicScale * aspect
```

For the frozen v18 North descriptor:

```text
aspect = 1.5
Blender ortho_scale = 237.5878601074218
```

Keep `shift_x = 0` and `shift_y = 128 / 1024 = 0.125`. Keep the exact camera
position, target, resolution, pixel aspect, geometry, materials, light,
contact-shadow polygon, Cycles settings, object mapping, and text authority.
Do not redesign the portal or alter any governed scene component in this
calibration.

The corrected analytical projection must restore the frozen registration:

- footprint diamond: `[768,640]`, `[1024,768]`, `[768,896]`, `[512,768]`;
- ground pivot: `[768,896]`;
- frontage socket: `[896,704]`; and
- no occupied pixel touching a canvas edge.

The repair must add a task-owned pre-render projection check which derives the
four footprint vertices, pivot, and socket from the actual configured Blender
camera and fails closed before rendering on any mismatch outside one source
pixel.

## Render cadence

1. Commit the corrected importer, successor calibration contract, and
   pre-render projection proof before creating new pixels.
2. Run one fresh factory-startup process A only.
3. If A fails registration, padding, alpha/chroma, hidden-RGB, or component
   mapping, preserve it as rejected and stop.
4. If A passes, run fresh processes B and C without another integration round.
5. Require identical decoded RGBA, occupied bounds, object manifests, and
   deterministic evidence across A/B/C.
6. Return the exact clean candidate for independent Renderer and QA pipeline
   review.

No sibling direction, portal redesign, normalization, ingestion, production
selection, runtime renderer, package, build, or shipping surface is authorized
by this repair.
