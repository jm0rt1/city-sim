# PLAY-027 Industrial L3 raw gate v02 disposition

`REJECTED_REPEAT_IDENTITY`

North completed three fresh Metal-visible source processes from frozen commit
`4096741c7fe64404408e8ea39df116c32f5f2623`. All three retained complete
building volume, identical occupied bounds `[509, 387, 1027, 896]`, 159,577
non-chroma pixels, stable registration, and zero alpha-differing pixels.

The binding repeat gate failed:

- A/B: 2 differing pixels, 2 differing RGB channels, zero alpha differences.
- A/C: 61 differing pixels, 66 differing RGB channels, zero alpha differences.
- B/C: 61 differing pixels, 66 differing RGB channels, zero alpha differences.

The first observed divergent retained stage is the emitted raw PNG and its
canonical decoded RGBA. No stage-capture diagnostic was authorized, so this
checkpoint makes no deeper causal claim. The locality report and alpha-respecting
zoom preserve the exact decoded differences.

Per the first-failure stop, no East, South, or West process and no normalization
was run. The approved pre-pixel art is not rejected by this technical result.
`sourceAuthority` and `productionSelected` remain false. Further diagnosis or a
sampling repair requires a new integration disposition.
