# PLAY-073 R4-F2 place-cohesion handoff

## Result

The bounded R4-F2 product/test milestone is committed at
`c27185950e23653644c0b3167999f1f85e3bd2fc`.

The implementation adds construction-owned ground and foreground context
phases, fixed family variant counts, normalized frontage-bound context
treatments, parcel-contained ordinary-family contact shadows, and cached
deep-copy templates. It does not import the rejected grove/court geometry or
the historical expansion of `WorldRenderingTests.swift`.

## Focused proof

`PLAY073PlaceCohesionTests` passed in two fresh process invocations. The three
directly affected existing `WorldRenderingTests` passed as well. The tests
cover deterministic repeated node/placement identity, frontage priority and
roadless failure, context containment, fixed variants, template isolation,
three-layer context presence, and absence of labels/actions.

The SwiftPM commands required writable module caches in `/private/tmp`; the
initial default-cache attempt was an environment failure before manifest
compilation. No full suite, staged app, final real-app journey, independent
visual disposition, integration, push, or self-acceptance was performed.

## Contact sheets

The color and grayscale PNGs are deterministic technical geometry schematics
for the frozen ground → sprite → foreground and parcel-shadow contract. They
are not runtime screenshots and must not be used as visual-quality or player
acceptance evidence. Integration must run the exact aggregate candidate and
PLAY-075 must perform the independent real-app disposition.

## Owned paths

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/PLAY073PlaceCohesionTests.swift`
- `docs/production/evidence/PLAY-073/r4-f2-place-cohesion-v1/`

No other paths are part of this handoff.
