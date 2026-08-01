# PLAY-073 R4-A rendered-pixel baseline

**Disposition:** frozen pre-product baseline; not acceptance

**Merged renderer baseline:** `b69a9b7c83156ebdd9d0d126198942becdacafc3`

**Authority:** `dae73ec40d48376aa74a1041e86fc1047ecac539`

**Fixture:** `CityGameState.newCity(seed: 42)`

## Frozen definition

The test-owned definition is `play073-r4-a-rendered-pixel-v1` in
`WorldRenderingTests.testR4ARenderedPixelMeasurementBaselineIsDeterministic`.
It renders the authentic opening twice and requires byte-identical semantic
masks and frame PNGs.

- Regular is the real renderer fixture at `1280 x 800` points with HUD insets
  top `104`, leading `24`, bottom `160`, trailing `24`.
- Compact is the exact `900 x 600` fixture with HUD insets top `138`, leading
  `19`, bottom `236`, trailing `19`.
- The safe aperture is the rendered backing-pixel crop remaining after those
  fixed insets. The recorded backing scale is `2`.
- District/public realm is the binary rendered union of authoritative
  `district.ground.*`, every real `road.*` drawable, and renderer-owned lot
  foundations, frontage/aprons/curb breaks, neighborhood public-realm,
  block-entrance, planting-soil, parking, service-yard, civic-forecourt,
  park-terrace, and contact drawables. It does not add a road, occupied parcel,
  action, or hit target.
- Plain terrain begins with the rendered `terrain.macro.turf` mask, subtracts
  district/public-realm pixels, and remains plain when the fully composed
  terrain changes no rendered RGB channel by more than `12 / 255` from the
  unmodulated turf. This prevents nearly transparent nodes from satisfying the
  gate without a perceptible pixel change.
- Plain-terrain components use four-connected rendered pixels.
- Opaque building pixels are non-background pixels from authoritative
  `lot.generated-v4.*` sprites at the shipping camera detail, before
  interaction overlays.
- Selection and preview impact conservatively counts any opaque-building pixel
  whose rendered RGBA changes by more than `12 / 255` from the unselected
  frame. This can overcount harmless emphasis, but cannot hide an obscuring
  overlay.

## Baseline result

| Layout | District width | Plain terrain | Largest plain component | Selection impact | Preview impact |
|---|---:|---:|---:|---:|---:|
| Regular | `0.708198` | `0.761921` | `0.725895` | `0.013752` | `0.019553` |
| Compact | `1.000000` | `0.551711` | `0.240602` | `0.026008` | `0.115002` |

The baseline therefore fails R4-A on the regular largest-plain-terrain
component and on compact preview impact. It is retained to prevent the product
iteration from redefining the measurement after seeing the candidate.

The exact dimensions, camera values, counts, component ledger, fixture hash,
frame hashes, and mask hashes are in `MEASUREMENT-LEDGER.json`. All frame and
mask files are worktree-local deterministic test renders; they are not the
shared staged app, the isolated L3 bundle, or PLAY-075 evidence.
