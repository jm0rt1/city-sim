# Source Production and Quality

Read this reference before any source generation, DCC authoring, normalization, comparison, or visual-quality review.

## Produce one governed source per direction cell

1. Audit the current catalog and prove the logical type is not aliased.
2. Load the immutable style anchor, the exact geometry template, and the
   approved family anchor. Never use a rejected sibling as a reference.
3. Use the source method authorized by the immutable family contract. When it
   authorizes built-in ImageGen, use it once for one source attempt, follow
   CONTRACT-006’s chroma-key prompt, and retain the complete prompt and
   reference hashes. When it authorizes the offline/DCC path, do not make a
   whole-building ImageGen call.
4. Save the raw stochastic master immediately with a unique revision. Never
   overwrite a prior attempt.
5. Normalize deterministically with the existing repository tools. Do not use
   generated pixels to infer pivots, masks, footprint, frontage, or geometry.
6. Record raw/normalized hashes, geometry, frontage, view direction, model,
   date, reviewer state, and disposition.
7. Reject perspective, lighting, scale, pivot, alpha, frontage, silhouette,
   or material drift before adding the source to a contact sheet.

After two consecutive directional drift failures, stop further attempts in that
direction and return to its geometry template and anchor. Preserve passing
sibling candidates; do not keep adding prompt adjectives.

## Use the approved offline-scene fallback

When CONTRACT-011 is present and the retained capability-limit record closes
whole-building ImageGen:

- do not make another whole-building ImageGen call;
- use ImageGen only for non-compositional material swatches within the
  CONTRACT-011 boundary;
- author one explicit task-owned offline scene descriptor per direction using
  the approved macOS-native source toolchain;
- declare direction-specific facade and entrance geometry in every scene;
- never derive a sibling scene or raster by mirror, rotation, or transform;
- freeze tool/framework versions, scene/material hashes, render settings,
  camera, pivot, socket, light, shadow, and flat chroma field;
- prove repeat-run determinism before judging appearance;
- stop at the exact claim-authorized family, direction, and stage boundary
  until independent art review and Integration authorize expansion.

The offline renderer remains a source-authoring tool. It may not become a
shipping dependency or edit `Package.swift`, `Rendering/`, atlas selection, or
the application runtime.

## Enforce four-direction and family quality

- Author north, east, south, and west separately; never mirror or rotate.
- Keep footprint, pivot, contact, floor/door scale, vertical envelope, light,
  shadow, materials, and identity within CONTRACT-010 tolerances.
- Keep the entrance on the declared road-facing frontage.
- Give every logical building type its own source and pixel identity.
- Make variants materially different in massing, roofline, entrance rhythm,
  and materials; reject recolor-only or prop-only changes.
- Require unlabeled grayscale recognition for residential, commercial, and
  industrial families.
- Include no baked roads, labels, UI, selection marks, agents, or false state.
