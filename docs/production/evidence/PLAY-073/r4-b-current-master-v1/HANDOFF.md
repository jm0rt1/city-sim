# PLAY-073 R4-B current-master reconstruction

Product commit: `1ce6600bf109828962ca85740151965d4219a8c0`.

The current-master-only repair preserves the existing `materialSpan = 2`
terrain architecture and all 121 material patches, then adds exactly three
deterministic broad regional ground materials. Completed residential,
commercial, and industrial/service lots receive renderer-owned contact shadows
and normalized-road-socket frontage treatments. Civic landmarks and parks are
left unchanged. Treatments are ground-only, remain inside the authoritative
lot diamond, expose no labels/actions/hit targets, and preserve source identity
and buildability. Contact-shadow vertices are checked for every visible
residential/commercial/industrial/service variant and N/E/S/W frontage; the
service-campus contact is checked against each authoritative ground cell.
Repeated context and terrain signatures compare actual path elements, node
positions, z-order, fills, strokes, and line widths, not names alone.

Focused validation:

```text
swift test --package-path Native/CitySimNative --filter WorldRenderingTests
69 executed, 0 skipped, 0 failures, 49.823 seconds
```

The focused run also reported 1,866 nodes, 927 drawables, 7.845 ms total
render, 5.187 ms cold world update, 0 fallbacks, and 50,331,648 resident
bytes. The first focused attempt exposed three campus-contact vertices; the
bounded height/offset correction was followed by a passing single regression
and the final 69-test run. `git diff --check` and JSON validation are required
for this packet.

This candidate deliberately excludes the aggregate Swift suite, staged app,
subjective visual judgment, and independent QA journey. Integration owns those
gates and must review this exact two-commit candidate before acceptance.
