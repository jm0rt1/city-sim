# PLAY-027 Turbine Works pre-pixel rejection trail

This record preserves two failed derived-evidence attempts. Neither failure
produced or changed governed source pixels.

## Numeric bridge failure

The first replay terminated before emitting the candidate packet because the
registration overlay attempted to cast an integer JSON coordinate directly to
`Double`:

`Could not cast value of type 'Swift.Int' to 'Swift.Double'`

The repair was limited to reading numeric JSON values through
`NSNumber.doubleValue`.

## Derived-panel orientation failure

The next deterministic replay passed its machine gates, but visual inspection
found that the grayscale, clay-overlay, and frontage/socket derived panels were
vertically inverted. The preserved representative artifacts are:

- `rejections/grayscale-orientation/SOURCE-GRAYSCALE-NESW.png`
  — SHA-256
  `dee5a5735860be0c7e5f1c8c2000e1470501b45e19dd165a4d680f106d80de93`
- `rejections/grayscale-orientation/FRONTAGE-SOCKET-NESW.png`
  — SHA-256
  `dc1e0e1e5188c7029f67ca02fc4b9e1a67982874a83e5b5ed5f37edb21ca3708`

The correction was restricted to the derived-panel CoreGraphics coordinate
system and registration-overlay Y mapping. Scene descriptions, geometry,
materials, camera, lighting, frontage, pivot, socket, contact, shadow, and
accepted v06 clay massing were unchanged.

Final runs F and G are byte-identical across all 16 emitted files. The final
candidate remains non-authoritative: `sourceAuthority=false` and
`productionSelected=false`.
