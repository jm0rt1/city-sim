# CONTRACT-019: Offline matte canonicalization and semantic visibility

**Status:** Approved for PLAY-027 Industrial L4 North repair

**Date:** July 27, 2026

## Context

PLAY-027 Industrial L4 North v17 proved two independent failures:

1. the offline compositor turns partial-alpha silhouette and contact-shadow
   samples into opaque near-magenta pixels; and
2. the authored portal geometry reaches SceneKit, but its frame, void, and
   depth hierarchy collapse at native-2x and literal-192 presentation scale.

The retained matte-attribution packet at exact World Art commit
`e8c1ba77c4ed10193a7ff53cdc7a07cab7ae989d` reproduces all `1,807`
contaminated coordinates and assigns `1,552` to the silhouette, `245` to the
contact shadow, `10` to their overlap, and `0` to an unowned class. Two
no-Metal replays are byte-identical, remove all exact and near chroma at
nonzero alpha, leave zero hidden RGB, preserve bounds, and change no pixel
outside the established border-matte/despill set.

Independent Renderer and QA review both returned
`APPROVE_MATTE_ONLY_RETURN_GEOMETRY`. The compositor defect may therefore be
repaired independently, but the v17 source is not accepted.

## Decision

PLAY-027 may implement two versioned, task-owned offline stages:

- `matte-canonicalization-v2`, which repairs the proven compositor boundary;
  and
- `semantic-visibility-v1`, which measures whether named authored components
  survive the exact governed camera and downsampling path.

These stages remain under
`Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/`. They do not enter the
shipping application, change `Package.swift`, modify production atlases, or
select source art.

## Matte canonicalization v2

The implementation order is:

1. render geometry and contact shadow with their existing clear-alpha
   semantics;
2. perform the governed software downsample;
3. remove only border-connected matte and predicate-bound near-chroma spill;
4. clear hidden RGB for alpha-zero pixels;
5. remat alpha-zero pixels to exact `#ff00ff` only when emitting a governed
   flat-chroma source; and
6. continue through the existing deterministic quantizer and PNG writer.

The repair must be fail-closed and versioned in provenance. Admission must be
derived from the bytes being mutated, not caller assertions:

- the stage computes the decoded RGBA hash from its RGBA input;
- descriptor and material bindings are constructed from their immutable bytes;
- the no-authored-magenta rule is derived from the bound material bytes; and
- changing input bytes while retaining old metadata must reject.

It may not:

- alter an authored non-matte pixel outside the proven border/despill
  predicate;
- use a general hue-key that could erase legitimate art;
- change camera, footprint, pivot, frontage socket, contact polygon, shadow,
  bounds, or source dimensions;
- rewrite retained rejected raws or accepted source masters; or
- silently apply to a palette that permits an authored magenta-family role.

Before another authoritative raw, the implementation must pass:

- two byte-identical no-Metal replays of the immutable v17 rejected raw;
- exact reproduction of the `1,807`-coordinate input mask and coordinate SHA
  `824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109`;
- zero exact or near chroma at nonzero alpha;
- zero hidden RGB;
- unchanged occupied bounds and registration;
- zero pixel changes outside the classified matte/despill set; and
- regression checks proving the version gate leaves the accepted Residential,
  Commercial, and Industrial L1-L3 retained masters byte-identical.

The admission path itself must be invoked for all accepted retained masters;
an inventory that only compares their file hashes and labels them unscoped is
insufficient.

## Semantic visibility v1

Before another authoritative v17 raw, PLAY-027 must render a diagnostic-only
semantic-ID pass from the exact candidate descriptor, exact camera, and exact
SceneKit node construction. Each of the portal jambs, header, inset/void, hall,
gantry, and crucible/occluder groups must receive a unique diagnostic ID.

The first custom software-rasterizer attempt at checkpoint `3822fa4b` is
rejected. It duplicated camera projection, Z buffering, sampling, mask
composition, and scaling, then failed before producing any visibility proof.
Its commit remains historical evidence but its implementation must not enter
the accepted candidate.

The authorized replacement is a narrow diagnostic mode inside the existing
task-owned `OfflineSceneRenderer`:

- bind the exact candidate descriptor, material library, camera, and toolchain;
- after `ContractSceneBuilder` creates the scene, replace only named diagnostic
  node materials with unique constant semantic IDs;
- render through the existing `NativeSourceRenderer`, existing 4x SceneKit
  snapshot, governed Lanczos stage, registration, and scaling path;
- decode and measure emitted masks without re-projecting or rasterizing
  geometry in the report tool; and
- use exactly two fresh diagnostic-only SceneKit/Metal processes, A and B.

These are semantic visibility processes, not authoritative raw-source
processes. Raw, normalizer, source-authority, production-selection, and sibling
process counts remain zero. This two-process exception supersedes only the
earlier no-Metal semantic replay requirement; the matte-v2 replay remains
no-Metal.

The tool must emit, for source scale, native-2x, and literal 192:

- a descriptor-to-rendered-node manifest with descriptor and node hashes;
- per-component visible pixel count and bounding box;
- pairwise adjacency and overlap/occlusion counts;
- color and grayscale component masks;
- a portal-only composite and an all-occluders composite; and
- byte-identical A/B inventories from the two diagnostic SceneKit/Metal
  processes.

The pre-pixel repair may advance only when the actual governed raster proves:

- two separately legible jambs and one separately legible header;
- one contiguous recessed void;
- nonzero frame-to-wall and frame-to-gantry grayscale separation;
- no total occlusion of the portal center by crucible or gantry;
- stable support at native-2x and literal 192; and
- an unaided literal-192 comparison that is unmistakably stronger than v16.

At literal 192 the hard minimums are:

- each jamb at least `4 × 5` visible pixels;
- the header at least `8 × 3` visible pixels;
- the inset at least `5 × 5` visible pixels and one connected component;
- frame-to-wall and frame-to-gantry grayscale delta at least `12`; and
- no fully occluded portal center.

Analytic semantic panels alone are insufficient. The same SceneKit geometry,
camera, materials, and downsampling path used for the next raw must produce
the proof.

## Advancement order

1. Commit the fail-closed matte-v2 repair and immutable regression packet.
2. Delete the rejected custom semantic rasterizer from the candidate while
   retaining checkpoint `3822fa4b` in branch history.
3. Commit the exact-v17 existing-renderer semantic-ID diagnostic and its
   measured disposition.
4. If visibility fails, revise only the North portal value hierarchy,
   projection, and occlusion while preserving the court, hall, gantry,
   crucible, stack, footprint, pivot, socket, camera, light, and shadow.
5. Obtain independent Renderer and QA approval of the actual native-2x and
   literal-192 proof.
6. Integration may then authorize exactly one North A raw process.

No B/C repeats, siblings, normalization, renderer ingestion, shipping,
production selection, or self-acceptance is authorized by this contract.

## R3 duplicate-foundation repair

The exact existing-renderer diagnostic at `a47215ea` failed A/B identity:
`13,629` decoded pixels and `26,924` channels differ over
`[524,710,1024,895]`. The descriptor and both processes share an identical
52-node manifest. Renderer review localized `13,191` of those pixels to an
`other → hall` swap across the foundation footprint.

The cause is a redundant coplanar mass:

- canonical `foundation` is `56 × 1.4 × 56` at `[0,0.7,0]`;
- mass block `v16-foundation` has the same dimensions, transform, bounds, and
  material; and
- SceneKit receives both boxes, producing an undefined depth-ownership tie.

PLAY-027 may create one new immutable North descriptor revision that removes
only redundant `v16-foundation`. The repair must prove the removed node is
exactly coincident with canonical `foundation` before mutation and must leave
all other descriptor, material, camera, sampling, registration, socket,
contact, shadow, and semantic bindings unchanged.

Exactly two diagnostic-only SceneKit/Metal semantic processes are authorized
for that new descriptor revision. They must produce a 51-node manifest and
pass:

- byte-identical PNG and decoded RGBA outputs;
- zero differing pixels and channels;
- identical descriptor/material/binary/node manifests; and
- unchanged portal component counts relative to the v17 return, including the
  still-failing three-pixel south jamb.

This is a determinism repair only. Portal modeling remains blocked even if the
repeat gate passes. Any remaining A/B split returns to integration with no
further process.

## R4 retained-output edge-locality attribution

R3 removed the duplicate foundation and reduced the A/B split from `13,629`
pixels to `143`, but repeat identity still fails. The residual bounds are
`[558,688,731,743]`; `85` pixels transition between portal header and crucible
semantic ownership, and the header falls from `1,275` to `1,175` source pixels
and from `19` to `17` literal-192 pixels.

Read-only Renderer review establishes:

- header/lintel and crucible volumes are physically disjoint by more than
  `18` world units on X;
- semantic materials are fresh, opaque, constant-lit, and per-node;
- MSAA is disabled;
- the split changes underlying RGBA and component support, so it is not merely
  a classification label; and
- retained R3 outputs do not expose the native-4x/pre-Lanczos boundary needed
  to distinguish SceneKit preparation from raster-edge/resolve behavior.

PLAY-027 may add one task-owned no-Metal analyzer operating only on immutable
R3 A/B PNGs, provenance, descriptor SHA `3696b813…`, and 51-node manifest
`611d60db…`. Product, descriptor, material, renderer, resolver, and model
mutations are zero. SceneKit, Metal, raw, normalizer, and sibling processes are
zero.

The analyzer must run twice with byte-identical output and report, for all
`143` differing coordinates:

- A/B RGBA and semantic transition;
- distance to each run's relevant silhouette boundary;
- connected-component thickness;
- intersection with recorded post-quantization mutation sets; and
- analytic world-AABB overlap/gap plus projected conservative bounds for
  header, lintel, jambs, gantry, and crucible.

Disposition is fail-closed:

- `RASTER_RESOLVE_EDGE` only if all `85` header↔crucible pixels are within two
  source pixels of a relevant A/B silhouette boundary, none lies in a stable
  component interior, and post-quantization records explain none;
- `PREPARATION_STATE_SPLIT` if any changed component contains a stable `3 × 3`
  interior or lies more than two pixels from both relevant boundaries;
- `POSTQUANTIZATION_SPLIT` only if every differing coordinate is explained by
  differing recorded canonicalizer mutations; or
- `MIXED_OR_UNCLASSIFIED`, which stops all further SceneKit processes and
  modeling.

This diagnostic does not accept v18 or reopen portal modeling.
