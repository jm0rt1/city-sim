# PLAY-027 Industrial L2 directional family V03 rejection

Disposition: `REJECTED_PREPIXEL_PRODUCTION_DECODER`.

V03 added only `entrance.stepCount: 1` to the independently reviewed V02
North, South, and West descriptors. Removing that one key reproduces each V02
descriptor canonically; every geometry hash is unchanged. East descriptor,
materials, and governed raw remain byte-exact.

Two fresh no-pixel panel-builder processes reproduced all four V02 visual
panels byte-for-byte. The analytic builder does not read `entrance` or
`stepCount`, so V03 has no visual change.

The complete production `SceneDescriptor` dry decode nevertheless fails on the
next required `EntranceDescriptor` key, `stepRun`. No SceneKit, Metal, raw, or
normalizer process was invoked. V03 therefore remains a compatibility
rejection rather than a render candidate. `sourceAuthority=false` and
`productionSelected=false`.
