# CONTRACT-025: Authored four-view 2.5D building art

**Status:** Approved production authority

**Owner:** Integration

## Decision

CitySim keeps the richly detailed, realistic 2.5D ImageGen art established by
the CONTRACT-024 wave, and buildings rotate correctly. Every logical building
identity has four independently authored North, East, South, and West sprites.
Runtime selects the matching authored view when the world rotates; it may not
mirror, rotate, skew, synthesize, or alias a raster image.

The 43 high-quality images already generated under PLAY-097 through PLAY-100
are preserved as the South / rotation-zero appearance anchors after frontier
orientation and visual review. They are not discarded or regenerated merely
because the view contract changed. North, East, and West siblings must retain
the same building's massing, roofline, material palette, windows, props,
condition, silhouette, scale, and identity while moving frontage and visible
facades to the governed orientation.

This contract supersedes CONTRACT-024 for new production work. CONTRACT-024
artifacts and commits remain durable source evidence.

## Exact production matrix

- Residential levels 1-4, variants 0-2: 12 identities x 4 views = 48 sprites.
- Commercial levels 1-4, variants 0-2: 12 identities x 4 views = 48 sprites.
- Industrial levels 1-4, variants 0-2: 12 identities x 4 views = 48 sprites.
- Civic/service identities: 7 identities x 4 views = 28 sprites.

The first production release is exactly 43 logical identities, 172 authored
source sprites, and 516 explicit city/neighborhood/block LOD payloads. No raw,
decoded payload, normalized LOD, packed rectangle, or prompt result may alias
another identity or direction.

Canonical identity names follow the integrated renderer matrix:
`residential_lNN_vN`, `commercial_lNN_vN`, `industrial_lNN_vN`, and
`civic_<kind>_v0`. Direction is a separate enum: `north`, `east`, `south`, or
`west`.

## Frozen 2.5D visual language

All four views retain the CONTRACT-024 quality bar: richly detailed,
materially believable, hand-painted city-builder imagery; orthographic 2:1
isometric projection; northwest key light; contained southeast contact shadow;
and no voxel, toy, flat-vector, or raw 3D-render appearance.

Each source uses the 1536 x 1024 authoring canvas and code-owned ground pivot
`[768, 896]`. Background cleanup may remove border-connected chroma and
despill, but must preserve the full authored coordinate system. Generated
occupied bounds, shadows, landscaping, or props may not determine crop, scale,
pivot, frontage socket, or footprint geometry.

The accepted South source is the visual reference for its three siblings.
Each sibling is produced through a separate built-in ImageGen call or edit with
the exact South image as a bound reference. Prompts must explicitly preserve
the named building identity and rotate the authored camera/frontage to one
target direction only. No CLI/API fallback is authorized.

## Direction and frontage

- `south` is the preserved CONTRACT-024 canonical view and rotation zero.
- `east`, `north`, and `west` are separately authored siblings.
- Entrances, paths, loading bays, service doors, storefronts, and civic steps
  must visibly face the declared road edge.
- Roofs, chimneys, rooftop equipment, signs, landscaping, and shadows must be
  compositionally consistent but genuinely re-authored for the new view.
- A failed direction returns only that identity-direction. Passing siblings
  remain immutable.

## Runtime and persistence

Renderer resolution is `family + level + variant + direction + LOD`.
Direction derives deterministically from the current world/camera rotation and
lot frontage. Stable coordinates, family, level, visual seed, and rotation
produce the same image across launch, save/load, replay, Undo, process order,
and LOD transitions. No simulation or save-schema mutation is required unless
implementation proves otherwise and Integration approves a separate contract.

Variant selection still uses all available same-kind/same-level variants before
adjacent repetition. Rotating the world changes only the authored view, never
the logical building identity or variant.

## Validation and activation

Every source packet binds prompt, South reference path/hash, tool provenance,
raw path/hash, exact direction, gameplay meaning, and disposition. Mechanical
gates reject missing views, aliases, runtime transforms, fallback, chroma or
alpha defects, frame-edge content, pivot/scale drift, frontage mismatch,
orphaned payloads, and nondeterministic normalization.

Each identity is quarantined until all 4/4 authored views and all 12 normalized
LOD payloads pass. Renderer assembly may review complete families internally,
but shipping activation is atomic at the exact 172/516 aggregate so the city
never mixes the new art with partial directional fallback.

Frontier review owns appearance matching, direction truth, literal-scale
readability, overlap/clipping, mixed-fidelity seams, and final production
selection. Luna owns frozen-prompt sibling production, provenance, deterministic
normalization, mechanical validation, contact sheets, and handoff packets.

## Parallel production

South preservation, North generation, East generation, West generation, shared
harness repair, renderer intake, and QA preparation are disjoint workstreams.
North/East/West run concurrently from the same accepted South anchors. A failed
direction does not block processing or review of passing directions.

Serialized work is limited to shared contract/tool changes, South appearance
admission, exact four-view family joins, shipping manifest/atlas mutation,
production selection, Integration, push, and the final independent real-app
journey.

## Final gate

One independent frontier QA task operates the exact staged 172/516 aggregate
at all four rotations, city/neighborhood/block LODs, and regular/900 x 600
layouts. It must verify immediate visual quality, stable identity while
rotating, correct frontage, no overlap/clipping/fallback/mixed-fidelity seams,
selection and diagnostic readability, interaction, accessibility, and accepted
performance budgets. Tests, hashes, contact sheets, or attractive isolated
sprites cannot substitute for this candidate-bound real-app judgment.
