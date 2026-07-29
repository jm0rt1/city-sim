# PLAY-027 Industrial L4 v17 semantic renderer v1

Disposition: `PASS_PREPIXEL_SEMANTIC_RENDERER_CONTRACT`

The contract is bound to exact v17 descriptor SHA-256
`6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a`,
material SHA-256
`147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`,
geometry `industrial-l04-crucible-gantry-v17-north-monumental-portal`,
and the existing schema-2 v3 sampling contract.

The mode runs after the real `ContractSceneBuilder`, replacing only rendered
node materials with constant diagnostic semantic IDs. It continues through the
existing `NativeSourceRenderer`, factor-4 SceneKit snapshot, governed software
Lanczos, registration, quantizer, and PNG path. No camera projection, raster,
depth buffer, or scaling implementation is duplicated.

Twelve focused mutations reject: contract, descriptor hash, material hash,
revision, direction, geometry, antialiasing, shadows, lighting, purpose,
output run, and competing diagnostics. Both renderer and standalone validator
compile with warnings as errors.

Pre-pixel process counts are zero for SceneKit renderer, Metal, authoritative
raw, and normalizer. The next authorized action is exactly diagnostic run A
and run B. This checkpoint does not accept v17 geometry or source art.

Compile commands:

```text
xcrun swiftc -D PLAY027_SCENE_PREP_DIAGNOSTIC -parse-as-library -warnings-as-errors -module-cache-path <task-cache> Sources/*.swift ValidateIndustrialL4V17SemanticRendererV1.swift -framework AppKit -framework CoreGraphics -framework CoreImage -framework ImageIO -framework ModelIO -framework SceneKit -framework UniformTypeIdentifiers -o validate-industrial-l4-v17-semantic-renderer-v1
xcrun swiftc -parse-as-library -warnings-as-errors -module-cache-path <task-cache> Sources/*.swift -framework AppKit -framework CoreGraphics -framework CoreImage -framework ImageIO -framework Metal -framework ModelIO -framework SceneKit -framework UniformTypeIdentifiers -o offline-scene-renderer-semantic-v1
```

Renderer binary SHA-256:
`9f1b9269b90e1d827685c8b2b0a484c5a4c9e5303868aae9d04d20f371342490`.
