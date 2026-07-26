# PLAY-027 Industrial L3 sampling capability

Disposition: `PASS_PREPIXEL_CAPABILITY`

This additive task-owned resolver capability admits only frozen
`industrial_l03` `source-v02` N/E/S/W source-authority descriptors using the
existing schema-2 v3 contract. It does not change a descriptor, material,
camera, registration contract, renderer CLI, product runtime, package, or
shipping surface. `productionSelected` remains false.

## Bound identities

- north descriptor: `78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51`
- east descriptor: `dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c`
- south descriptor: `1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b`
- west descriptor: `bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce`
- renderer architecture before:
  `e0943590ee01f8518fbd3a230fa126e607b6aa130c6fcc422e250eb9467b76af`
- renderer architecture after:
  `34c0bced859f2716b1ca04a0f576aa463022ff1b3e7e10056717458daba239e2`
- standalone validator binary:
  `ec09727a69d67feb2be30ab788eb75904aec03c6da58cf9a21d3035fd1d1e169`
- deterministic validator report:
  `8edcd1bf6d3126104409c478f6a4074a9c7ee312f59f227eb5090a85a5f33349`

## Validation

The standalone validator was compiled with `-warnings-as-errors`, run twice,
and produced byte-identical reports. Four positive descriptor cases resolved
to no MSAA, disabled SceneKit shadows, authored-constant lighting, factor-4
linear oversampling, software Lanczos 0.25, and the frozen v3
post-quantization canonicalizer. Seven mutations failed closed: logical ID,
revision, purpose, direction, shadows, lighting, and contract ID.

Accepted reproduction was replayed against baseline
`9290d7f53e7ea75d5011c19c48388084e2cbe6af`: 36/36 accepted Residential
L1-L4, Commercial L1-L4, and Industrial L1 descriptors remain byte-identical;
36/36 retain Lambert scene lighting; mutation count is zero. The report SHA is
`bb02b17507c568ab5eb51e2b02f54559a630d9ba5ef4ff6d6e84ceb4fbb0caee`.

Retained Industrial L2 resolver checks also pass:

- `TestIndustrialL2V4Sampling.swift`: source-v04 alone binds disabled shadows;
  accepted/default descriptors retain current shadows.
- `TestIndustrialL2V5Lighting.swift`: schema-1 and source-v04 retain Lambert
  defaults; the enumerated Industrial L2 authored-constant revisions still
  resolve without drift.

## Commands

All standalone tools were compiled from `SceneDescriptor.swift`,
`RendererArchitecture.swift`, and the named tool with:

`swiftc -parse-as-library -warnings-as-errors -module-cache-path <task-cache> -framework SceneKit -framework ModelIO -framework CoreImage -framework CoreGraphics`

Executed validations:

- `validate-industrial-l3-sampling-capability --repository-root <repo> --report <run-a.json>`
- `validate-industrial-l3-sampling-capability --repository-root <repo> --report <run-b.json>`
- `cmp <run-a.json> <run-b.json>`
- `validate-accepted-sampling-reproduction --repository-root <repo> --baseline 9290d7f53e7ea75d5011c19c48388084e2cbe6af --report <accepted-reproduction.json>`
- `test-industrial-l2-v4-sampling --scene <retained-directional-family-v04-north.json>`
- `test-industrial-l2-v5-lighting --source-v04-scene <retained-directional-family-v04-north.json> --legacy-scene <residential-l01-north.json> --schema <scene-v2.schema.json>`

No SceneKit/Metal render or source pixel was consumed by this checkpoint.
