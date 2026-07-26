# Industrial L3 pre-pixel architecture v02

Authority base: `9290d7f53e7ea75d5011c19c48388084e2cbe6af`

Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`

This source-only architecture advances Industrial L2 into a high-capacity
manufacturing campus: four loading bays, a separate staff/quality entrance,
stepped high-bay and assembly volumes, roof-monitor rhythm, a process tower,
ducting, and a service-yard tank group. North and West use independently
authored open loading courts so their far-edge frontage survives the fixed
production camera without mirroring, rotation, or camera tricks.

The family retains the frozen 56 x 56 footprint, pivot, named road sockets,
frontage edges, northwest light, authored southeast contact shadow, floor/door
scale, and schema-2 v3 deterministic sampling contract. Horizontal root bounds
are exactly `[-28, 28]` on X and Z in all four scenes. The strict structural
validator records zero coincident Y boundaries and zero camera-visible
coincident material-owner planes for every direction.

## Frozen identities

| Direction | Descriptor SHA-256 | Canonical geometry SHA-256 |
|---|---|---|
| North | `78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51` | `6b2a7639a232bca3bdb88483ebdfab103f2995c23bf85b1712c1c0c5f175dd16` |
| East | `dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c` | `28029337cad34e5d2bc932d6cc005ad6029b510fea50b72dec2fe9642805a7d6` |
| South | `1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b` | `4a0b3d9b3baa101be07140c24efe9a909f70d177e523b688ec939c15f9190676` |
| West | `bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce` | `42a2b6fbe21be2b6d45fbabb2d39f01b5f6f44673d1c96a0796984b380153faa` |

Material library SHA-256:
`3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`.

The analytic source/native-2x color and grayscale sheets are explicitly
non-authority previews. No SceneKit, Metal, raw-source, or normalizer process
was consumed by this checkpoint.

`sourceAuthority: false`

`productionSelected: false`
