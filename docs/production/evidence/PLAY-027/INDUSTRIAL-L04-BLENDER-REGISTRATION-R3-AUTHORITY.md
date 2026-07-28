# PLAY-027 Industrial L4 Blender registration R3 authority

**Published integration authority:** `c02a72ce39ec8190a024cae970bc6afc4efd3aae`

**Returned World Art candidate:** `39aa2f3dd33738110754cde9e7b0d54f06cf1137`

**Renderer disposition:** `RETURN_DCC_PIPELINE`

**QA dispositions:** `CALIBRATION_VISUAL_PROOF_APPROVE` and
`CURRENT_ART_PRODUCTION_RETURN`

The R2 candidate proved deterministic Blender/Cycles rendering: three fresh
processes emitted identical decoded raw and semantic RGBA; every IDAT chunk was
byte-identical; only non-authoritative timing/date text chunks differed; all
51 components and 13 materials were preserved; and alpha/chroma/hidden-RGB
checks passed.

R2 is nevertheless returned because its registration validator projected an
artificial CitySim `y = 11.4309845` plane. The governed footprint, pivot,
socket, contact, and foundation anchors are on the actual `y = 0` ground
plane. The self-fulfilling proof concealed a remaining 64-source-pixel
vertical displacement.

## Exact R3 correction

World Art may create one successor North-only calibration revision from the
clean R2 branch candidate. Preserve R1/R2 history and evidence.

Keep the accepted landscape scale conversion:

```text
aspect = renderViewportPixels.width / renderViewportPixels.height
Blender ortho_scale =
    2 * SceneKit orthographicScale * aspect
```

Correct the post-projection vertical offset using the landscape frame width:

```text
shift_x = postProjectionOffsetPixels.x / renderViewportPixels.width
shift_y = postProjectionOffsetPixels.y / renderViewportPixels.width
```

For the frozen 1536x1024 North descriptor:

```text
Blender ortho_scale = 237.5878601074218
shift_x = 0
shift_y = 128 / 1536 = 0.08333333333333333
```

Remove the derived/artificial registration plane completely. The pre-render
proof must project the governed contact polygon, pivot, and frontage socket
from actual CitySim ground `y = 0` through the configured Blender camera.

The exact governed result, within one source pixel, is:

- footprint: `[768,640]`, `[1024,768]`, `[768,896]`, `[512,768]`;
- ground pivot: `[768,896]`;
- frontage socket: `[896,704]`; and
- ground origin: `[768,768]`.

No render may begin unless that ground-plane proof passes and no governed
point touches a canvas edge.

## Render and review cadence

1. Commit the R3 importer/contract/projection-proof change before pixels.
2. Run one fresh factory-startup process A.
3. Stop and preserve A on any registration, padding, alpha/chroma, hidden-RGB,
   component/material mapping, or source-authority failure.
4. If A passes, run fresh B and C immediately.
5. Require identical decoded raw and semantic RGBA, occupied bounds, object
   manifests, projection proofs, and deterministic packet outputs across all
   three processes.
6. Preserve an exact R2-to-R3 registration comparison proving the intended
   64-pixel correction without geometry, material, camera-position, target,
   light, contact, or Cycles-setting drift.
7. Return the exact clean candidate for independent Renderer and QA review.

This authority does not accept the current v18 art. Independent QA returned it
at literal 192 because the crucible blocks the freight portal, the hall remains
a generic slab, facade/roof/material hierarchy is weak, the contact field is
too dark, and low-sample noise is visible. Portal redesign, sibling directions,
normalization, ingestion, shipping, runtime changes, and production selection
remain blocked until the ground-plane DCC calibration is independently
approved.
