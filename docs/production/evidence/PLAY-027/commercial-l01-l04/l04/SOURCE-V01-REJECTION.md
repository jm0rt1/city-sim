# PLAY-027 Commercial L4 source-v01 rejection

## Disposition

Commercial L4 `source-v01` is rejected before normalization. Preserve every
raw PNG, provenance record, fresh-process repeat, exact-RGBA report, and
validator result. None of these bytes is a review candidate or production
selection.

## Repeat failure

| Direction | Primary SHA-256 | Run B SHA-256 | Run C SHA-256 | Result |
|---|---|---|---|---|
| north | `a6b59667d977f83e3e13169e2c99d8952d2ab4beb5338faa2c3fc1adae29018c` | same | same | pass |
| east | `263a9ad6e2651c75e50260f3971bdec3d170d87360cbc026bd7cc340a249d481` | `16d34acadc9828654733a3f94fdefe4fe9347983f5249af66b88de2b3f01416d` | `16d34acadc9828654733a3f94fdefe4fe9347983f5249af66b88de2b3f01416d` | reject |
| south | `60d3b237b3c257ab4764ebea842598f4b601a65be0f69f60986757d10703ef2c` | `a14453128d0b0d44e33bfb62ce0a5b8b16af57b3229a2be6390ddcb2869f280f` | `60d3b237b3c257ab4764ebea842598f4b601a65be0f69f60986757d10703ef2c` | reject |
| west | `90f8c9ff732c5ae0f120ce06d025abdaf6092fc4895cfde52face903221cacda` | same | same | pass |

The north and west reports contain one pixel identity each. East and south
each contain two pixel identities across three fresh processes, so the
deterministic raw-render contract fails despite complete visible geometry.

## Retained passing evidence

The four primary raws are unique. Exact standard RGBA decoding reports:

- complete occupied width and height against accepted Commercial L3;
- alpha-visibility ratio `1.0` in every direction;
- zero hidden non-magenta pixels;
- matching RGB and alpha-visible occupied bounds;
- complete tower, footprint plate, southeast shadow, crown, and target
  frontage in the retained occupied-crop sheet.

These passing checks do not waive repeat nondeterminism.

## Local geometry diagnosis and repair boundary

The new L4 tier stack introduced overlapping or boundary-coincident geometry:

- podium mass top, podium cornice, and podium terrace coping;
- lower-shaft top, transfer cornice, and transfer crown;
- upper-shaft top, upper crown cornice, and crown slab;
- mechanical-penthouse top and rooftop-prop bases.

Direction-dependent east/south byte divergence with complete geometry is
consistent with depth-winner ambiguity at those surfaces. Before another
render, the L4 family is frozen and the scene template must be repaired so
every tier, trim, roof slab, and rooftop prop has a non-overlapping vertical
interval with explicit separation. Prompt changes, sibling transforms,
normalization, and propagation are forbidden.

Commercial L4 `source-v02` may begin only after the repaired four-scene
descriptors pass the same uniqueness, registration, camera, light, frontage,
and cross-direction building-equality gates and the repair is durably
committed.
