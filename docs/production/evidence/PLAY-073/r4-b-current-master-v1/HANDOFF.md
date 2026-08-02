# PLAY-073 R4-B device-RGB repeat-proof repair

Product commit: `1ce6600bf109828962ca85740151965d4219a8c0`.

Proof repair route: `quality-v1:play-073-r4-b-device-rgb-proof-luna-v2`
(`ce55d83ff1938f1295874a71f291736d5c73365e3e0af0f10859be726833db5d`),
carrier `5d84d521b3b25f9ddf11d7b88e81c885a5e86946`.

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
Repeated context and terrain signatures compare actual path element types and
native scalar bit patterns, node positions, z-order, realized device-RGB
RGBA bit patterns, fills, strokes, and line widths, not names or rounded text.

The adversarial proof retains an exact one-bit coordinate drift and constructs
the color pair directly in device RGB at red `0.25` and `0.2500002`. It proves
the retired six-decimal realized-color signature aliases that pair while the
realized device-RGB red bit patterns, and therefore the lossless signatures,
differ.

Focused validation:

```text
swift test --package-path Native/CitySimNative --filter WorldRenderingTests
70 executed, 0 skipped, 0 failures, 49.319 seconds
```

The focused run also reported 1,866 nodes, 927 drawables, 7.416 ms total
render, 4.669 ms cold world update, 0 fallbacks, and 50,331,648 resident
bytes. The focused adversarial and exact-context tests each passed before the
70-test suite. `git diff --check` and JSON validation are required for this
packet.

The independently verified worker stack was applied in this exact order:

1. `1bcaad26cd4685038c327381b897084e569e8e93` — initial R4-B product;
2. `9b63056cfaeb591dd03da9af6e0ff0c80655649a` — initial evidence;
3. `1ce6600bf109828962ca85740151965d4219a8c0` — containment repair;
4. `9cd49210476e589ad848110e6d6061db41c87bac` — repaired evidence; and
5. `5f0b97e14452202759cdb0d937068919849ab675` — lossless repeat proof.

Synchronization merges `a4ce4e3c0e47cc3ea39a3b341c2b1e11be98c5dd`
and `a01ad44c563d9b2fbf3d9d3a59208ddd896d52c7` are explicitly excluded.
The corresponding cherry-picked master commits are `d79973bd`, `2fa624d3`,
`32864b0a`, `77c48741`, and `0af7f069`.

This candidate deliberately excludes the aggregate Swift suite, staged app,
subjective visual judgment, and independent QA journey. Integration owns those
gates and must review this exact five-commit candidate before acceptance.
