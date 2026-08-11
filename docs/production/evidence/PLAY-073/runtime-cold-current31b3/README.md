# PLAY-073 Renderer Cold-Path Evidence

- Baseline: `31b3b406ca9ac5448695ccae3c3ff53b1c1ada86`
- Branch: `codex/citysim-renderer-runtime-cold-current31b3`
- Scope: first-frame tile construction only
- Frozen gate: `6.03 ms`; its assertion and fixture were not edited

## Diagnosis

The existing cold-profile test attributed `12.556 ms` of a `14.092 ms`
world update to tile construction. Three unchanged shipping-gate processes
then measured `5.521 ms` PASS, `5.402 ms` PASS, and `6.591 ms` FAIL.

A temporary detailed profile, removed before the candidate was built, measured
the warmed block frame at:

- signatures: `0.035 ms`
- structurally empty records: `0.352 ms`
- road records: `1.776 ms`
- developed records: `1.545 ms`
- record bookkeeping: `0.015 ms`
- tile-root attachment: `0.787 ms`

The retained optimization removes only work with no rendered output:

1. Interior roads no longer create terrain containers and empty ground nodes
   that `makeTileRecord` immediately discarded.
2. Structurally empty roots call `removeFromParent()` only when they are
   actually attached.

No texture, color, geometry, topology, hit target, state mapping, deterministic
seed, node-count gate, drawable-count gate, fixture, threshold, or assertion
changed.

## Focused proof

The unchanged shipping renderer gate was run in three fresh test processes on
the final source and passed at:

- `5.028 ms`
- `5.101 ms`
- `5.283 ms`

Each run reported `1066` nodes, `565` drawables, and zero actions. The directly
affected empty-lot interaction and attachment regression also passed:

`WorldRenderingTests/testMacroTerrainReplacesTheRepeatedCellPlateAndKeepsEmptyLotsInteractive`

## Pixel identity

The shipping gate exported the same fixture before and after the optimization.
Every PNG compared byte-for-byte equal:

| Frame | Before SHA-256 | After SHA-256 |
|---|---|---|
| City | `0ee9f33424daedfae4a6ee6cf4cb4cd3e57f0da78795ae33634e3d5d94c3f4d4` | `0ee9f33424daedfae4a6ee6cf4cb4cd3e57f0da78795ae33634e3d5d94c3f4d4` |
| Neighborhood | `b0599e445eb758f5b13419daf2bf35429f79a532b2b64a409bd9d69353c91ffe` | `b0599e445eb758f5b13419daf2bf35429f79a532b2b64a409bd9d69353c91ffe` |
| Block | `5a18a57f15e4de672876eed37cfc80fec2bbde3d70efda73c63d693cc4d9cd5c` | `5a18a57f15e4de672876eed37cfc80fec2bbde3d70efda73c63d693cc4d9cd5c` |
| Compact | `84ff31b1f785049c11418295323c527c7125503d97e55ea8dd81285c575e313d` | `84ff31b1f785049c11418295323c527c7125503d97e55ea8dd81285c575e313d` |

These are deterministic SpriteKit harness exports, not real-app acceptance.
Integration retains aggregate, package, player-journey, and release authority.
