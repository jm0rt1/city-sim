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

The repair must be fail-closed and versioned in provenance. It may not:

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

## Semantic visibility v1

Before another authoritative v17 raw, PLAY-027 must render a diagnostic-only
semantic-ID pass from the exact candidate descriptor, exact camera, and exact
SceneKit node construction. Each of the portal jambs, header, inset/void, hall,
gantry, and crucible/occluder groups must receive a unique diagnostic ID.

The tool must emit, for source scale, native-2x, and literal 192:

- a descriptor-to-rendered-node manifest with descriptor and node hashes;
- per-component visible pixel count and bounding box;
- pairwise adjacency and overlap/occlusion counts;
- color and grayscale component masks;
- a portal-only composite and an all-occluders composite; and
- two byte-identical no-Metal replays.

The pre-pixel repair may advance only when the actual governed raster proves:

- two separately legible jambs and one separately legible header;
- one contiguous recessed void;
- nonzero frame-to-wall and frame-to-gantry grayscale separation;
- no total occlusion of the portal center by crucible or gantry;
- stable support at native-2x and literal 192; and
- an unaided literal-192 comparison that is unmistakably stronger than v16.

Analytic semantic panels alone are insufficient. The same SceneKit geometry,
camera, materials, and downsampling path used for the next raw must produce
the proof.

## Advancement order

1. Commit the matte-v2 implementation and immutable regression packet.
2. Commit the exact-v17 semantic-ID diagnostic and its measured disposition.
3. If visibility fails, revise only the North portal value hierarchy,
   projection, and occlusion while preserving the court, hall, gantry,
   crucible, stack, footprint, pivot, socket, camera, light, and shadow.
4. Obtain independent Renderer and QA approval of the actual native-2x and
   literal-192 proof.
5. Integration may then authorize exactly one North A raw process.

No B/C repeats, siblings, normalization, renderer ingestion, shipping,
production selection, or self-acceptance is authorized by this contract.
