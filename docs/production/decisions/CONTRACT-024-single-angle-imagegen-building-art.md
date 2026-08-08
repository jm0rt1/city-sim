# CONTRACT-024: Single-angle ImageGen building art

**Status:** Superseded by CONTRACT-025

**Owner:** Integration

## Decision

> Historical decision only. On August 8, 2026 the user restored building
> rotation while explicitly retaining the high-fidelity 2.5D ImageGen art
> direction. CONTRACT-025 preserves the 43 generated canonical images as the
> first authored orientation set and adds independent North/East/West views.

CitySim building art will ship as fixed-camera 2.5D raster sprites produced by
OpenAI built-in ImageGen. A building has one canonical view. Runtime code must
not rotate, mirror, synthesize, or request North/East/South/West versions of
that image.

This contract supersedes CONTRACT-023 and the unfinished PLAY-090 through
PLAY-094 directional family for new production work. Their commits and evidence
remain preserved as historical experiments; none is production-selected.

## Product inventory

Every shipping logical building identity has its own authored image. No image,
decoded payload, normalized LOD, packed rectangle, or prompt result may alias a
different identity.

- Residential levels 1-4: variants 0, 1, and 2 (12 images).
- Commercial levels 1-4: variants 0, 1, and 2 (12 images).
- Industrial levels 1-4: variants 0, 1, and 2 (12 images).
- Civic/service: park, power plant, water tower, fire station, police station,
  school, and city hall (7 images).

The resulting first production matrix is exactly 43 unique building images.
Deterministic runtime selection may repeat an identity in a large city, but
adjacent same-kind/same-level lots must use available variants before repeating.

## Frozen visual and registration reference

The architecture is a proven extension of CONTRACT-006, not a new DCC path.
The frozen references are:

- `Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png`
  SHA-256 `b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425`;
- `Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/residential_l01/source-v01.png`
  SHA-256 `e15a388c2a1a0a55488457211c23939f70eca255cbae733ee0f7b39b141c962e`;
- `Native/CitySimNative/WorldArt/GeneratedV4/templates/registration-1x1.png`
  SHA-256 `6ad1db2e7b8f670718ff4a4eb8c183737b0dec859559a2eab6a25746b53cff67`.

Every asset uses a 1536 x 1024 authoring canvas, orthographic 2:1 isometric
projection, northwest key light, southeast contained contact/cast shadow,
ground pivot `[768, 896]`, generous transparent padding, and a perfectly flat
`#ff00ff` source background. The art must read as richly detailed, realistic
hand-painted city-builder imagery rather than voxel, toy, flat-vector, or raw
3D-render output.

The fixed camera shows the same canonical building angle everywhere. Road
frontage, paths, selection, overlays, construction, condition, and simulation
truth remain deterministic renderer composition outside the building sprite.

## Generation and acceptance

- Use the built-in ImageGen tool, one distinct call per asset identity.
- Retain the exact prompt, references and hashes, tool provenance, raw output,
  disposition, and rejection reason. No silent CLI/API fallback is authorized.
- ImageGen authors appearance only. It does not author roads, parcels, labels,
  state, selection, warnings, coordinates, or interaction affordances.
- Each raw must contain one centered building on flat chroma, with no district,
  road, extra building, UI, text, logo, watermark, frame-edge alpha, or cropped
  shadow.
- Deterministic repository code removes border-connected chroma, despills,
  zeros hidden RGB, registers the ground pivot, exports explicit city,
  neighborhood, and block LODs, and packs without rotation.
- Each family must prove unique raw and normalized decoded hashes, exact
  registration, alpha/chroma/padding validity, literal-game-scale color and
  grayscale readability, prompt/provenance completeness, and no cross-family
  alias.
- A Luna worker may generate and mechanically validate candidates under a
  frozen family brief. It may not make subjective acceptance, style changes,
  production selection, shared-contract decisions, or shipping activation.

## Runtime and shipping

The renderer resolves `family + level + variant` only; view direction is not
part of the new building-art identity. The renderer may not rotate or mirror a
sprite to satisfy road adjacency. Stable coordinate, family, level, and world
visual seed determine variants across launch, save/load, replay, Undo, process
order, and LOD transitions. This changes no simulation or save schema.

Shipping activation is one aggregate renderer candidate. The pack must contain
the exact 43-image matrix and 129 normalized LOD payloads, reject missing,
aliased, transformed, fallback, orphaned, or digest-mismatched assets, stay
inside the accepted texture/memory/frame budgets, and preserve pointer,
keyboard, overlay, selection, construction, and condition behavior.

## Parallel production

After this contract is published, the shared normalizer/receipt harness,
Residential, Commercial, Industrial, Civic/service, renderer intake, and QA
preregistration may proceed concurrently under disjoint claims. A failed asset
returns only that identity. Passing sibling assets remain immutable.

Only shared style changes, shared normalizer/schema changes, aggregate pack
mutation, production selection, Integration, push, and the final independent
real-app judgment remain serialized.

## Final gate

One independent frontier QA task operates the exact staged aggregate at regular
and 900 x 600 layouts across city, neighborhood, and block scales. It must see
an immediate improvement in building identity, material quality, silhouette,
cohesion, overlap/clipping, selection/diagnostic readability, and adjacent-lot
variety. Compilation, hashes, contact sheets, or worker confidence cannot
substitute for this real-app disposition.
