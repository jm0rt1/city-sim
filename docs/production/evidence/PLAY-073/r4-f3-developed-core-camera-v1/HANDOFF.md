# PLAY-073 R4-F3 developed-core camera handoff

The bounded camera-state repair preserves the last valid developed composition
while SwiftUI/AppKit delivers resize and viewport-inset invalidations. Automatic
refits are coalesced until the next authoritative render pulse; explicit
`frameCity()` still recomputes from current simulation state. A transient
incomplete composition can no longer replace a valid developed-core camera with
the whole-board `fitCity` fallback.

## Focused proof

The new six-permutation camera regression and the three required existing
camera regressions passed. Coverage includes regular, compact, maximized,
resize-before-insets, insets-before-resize, compact-to-maximized, and repeated
explicit Focus City/frame transitions. Developed and camera-priority bounds
remain non-null, priority coordinates remain stable, and both width occupancies
remain at least `0.60`.

SwiftPM required writable module caches under `/private/tmp`; the initial
default-cache attempt was an environment failure before manifest compilation.
No full suite, staged app, player-facing journey, subjective disposition,
integration, push, or self-acceptance was performed. Integration owns the full
Swift suite and staged verification; PLAY-075 owns independent real-app
acceptance.

## Owned paths

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-073/r4-f3-developed-core-camera-v1/`

No other paths are part of this handoff.
