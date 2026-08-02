# PLAY-073 R4-E focused proof repair v1 authority

**Owner:** Integration frontier debugging authority

**Status:** active successor to failed checkpoint
`1c3d59c7f36750195ade80f382b3a280762e2e5f`

**Execution:** `LUNA_LOCAL_DEBUG / gpt-5.6-luna / max`

**Acceptance:** Integration and a fresh independent staged-app QA task remain
`FRONTIER_AUTHORITY / gpt-5.6-sol / high`.

## Diagnosis and frozen repair

The first R4-E attempt correctly created explicit ground-underlay and
foreground-accent phases, but its focused proof does not measure those phases
truthfully:

1. the structural assertion is inverted and requires the forbidden ground
   shape in the foreground;
2. `terraced-court.planted-strip` is incorrectly promoted to foreground even
   though the authority permits only the court hedge face, step face, and
   planter lip there;
3. the isolated court mask includes every residential context node rather
   than only the court role;
4. the alleged facade mask retains foundations, frontage, and lifecycle
   geometry instead of isolating the accepted generated residential sprite;
5. alpha-presence in the composed frame counts an occluding building pixel as
   surviving court detail; and
6. color and grayscale contrast are calculated from the same color raster.

The warm-stone court is also translucent even though the frozen R4-E authority
requires opaque district-coherent paving.

One repair is authorized:

- remove `terraced-court.planted-strip` from foreground classification;
- make the warm-stone underlay opaque without changing its geometry;
- correct the inverted structural assertion;
- isolate exact court-underlay, court-foreground, and accepted-sprite masks;
- derive visible court pixels from actual composed-versus-court-hidden raster
  deltas, not whole-frame alpha;
- measure facade overlap only against the accepted sprite mask;
- measure color contrast from the composed color frame and grayscale contrast
  from separately retained deterministic integer Rec.709 bytes; and
- retain every existing numerical threshold, governed frame, repeat-identity,
  non-residential, interaction, source-identity, and resource invariant.

This is a proof/invariant repair, not authority to tune coordinates, scale,
shape, palette, thresholds, accepted source art, or shared contracts.

## Exact mutable surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- new root
  `docs/production/evidence/PLAY-073/r4-e-depth-layered-residential-frontage-v2/`

`LotRenderer.swift` and the preserved v1 failed evidence are read-only.

## Focused gate and stop

Run the corrected R4-E exporter twice, compare color and grayscale outputs
byte-for-byte, run all `WorldRenderingTests`, validate JSON and hashes, and run
`git diff --check 1c3d59c7f36750195ade80f382b3a280762e2e5f..HEAD`.

Stop immediately if the corrected proof still reports any foreground/facade
overlap, insufficient color or grayscale separation, inadequate visible court
pixels or survival, non-residential drift, or another focused failure. Such a
result requires frontier geometry/palette judgment. Do not tune beyond this
repair, run the aggregate suite or staged app, mutate another path, accept,
integrate, push, or pin.
