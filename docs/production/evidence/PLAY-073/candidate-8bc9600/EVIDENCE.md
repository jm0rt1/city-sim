# PLAY-073 typed-target contextual-framing evidence

## Disposition

This packet binds the narrow contextual-framing correction to exact product
commit `8bc96003c4524ad761a556cfdc8175440d563906`.

Independent visual review passes this bounded renderer outcome:

- the Day 1 default framing remains readable at regular and compact sizes;
- remote Commercial and Road targets retain their full ground diamonds;
- the nearest connected road and a meaningful share of the developed district
  remain visible;
- compact no longer miniaturizes the district to the rejected `d460047`
  result.

This is **not** PLAY-073 completion or acceptance of the overall opening
composition. PLAY-073 remains rejected and open because the authoritative
seven-place opening is still sparse and requires the PLAY-076 density outcome.
The opaque park plate and mixed utility/service source fidelity also require
future accepted world-art replacements.

The Road recovery route remains on block `20,18`. The screenshots truthfully
preserve that state, but they do not accept its same-tile target correctness;
that input/UI defect remains PLAY-077. The pointer Catalog pass-through route
was not used as proof and was not compensated for in the renderer.

## Exact identity

- Branch: `codex/citysim-world-rendering`
- Product commit:
  `8bc96003c4524ad761a556cfdc8175440d563906`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle identifier:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged app:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Staged executable:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Packaged resource bundle:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle`
- Captured staging manifest: `identity/candidate.manifest`
- Day 1 source save:
  `/private/tmp/play073-iteration3-day1.dYhZrD/quicksave.json`
- Day 1 source save SHA-256:
  `fbedaf5f4695cf506f4a19291d359d2c655fc0789893d854674b92a74b75d4ac`

The captured staging manifest records verification PID `48157`. That process
and every separate regular/compact evidence process were terminated after
capture. The final process-table check found no matching exact candidate
process.

## Ordered product commits after `76c3c39`

1. `fdbd555` — `PLAY-073: Keep typed targets in district context`
2. `c56b5fb` — `PLAY-073: Reframe clipped target diamonds`
3. `d460047` — `PLAY-073: Require active target context`
4. `8bc9600` — `PLAY-073: Preserve compact district readability`

## Real staged routes

Every route used the exact staged executable, a fresh isolated data root, the
same Day 1 save, Command-O, and a paused simulation. Captures were retained
after load/action transients cleared.

The valid proof route used the real keyboard path rather than the rejected
pointer pass-through:

1. press `C` for Commercial;
2. move with Right, Shift-Right, Right three times, Shift-Down, and Down to
   block `20,18`;
3. capture the unavailable Commercial target and its authoritative
   `This building needs direct road access` reason;
4. press `r` for Road recovery and capture the available Road preview at the
   same coordinate.

Regular captures are uncropped `1278 x 768` decorated windows:

- `live/play073-8bc9600-regular-default.png`
- `live/play073-8bc9600-regular-commercial-blocked.png`
- `live/play073-8bc9600-regular-road-recovery.png`

Compact captures are uncropped `900 x 652` decorated windows containing the
exact `900 x 600` app content:

- `live/play073-8bc9600-compact-default.png`
- `live/play073-8bc9600-compact-commercial-blocked.png`
- `live/play073-8bc9600-compact-road-recovery.png`

The capture utility encoded these six files as JPEG data despite their `.png`
filenames; `SHA256SUMS` binds the exact bytes. Matching full AX trees are
retained under `ax/`. They prove Day 1 paused identity, no selection for the
default state, Commercial unavailable at block `20,18`, and Road available at
block `20,18`.

## Camera contract

The exact candidate test metrics are:

| Route | Camera scale | District safe width | District safe height |
|---|---:|---:|---:|
| regular remote target | `0.8172323107719421` | `0.6095568301831683` | `0.5833820573567386` |
| compact remote target | `1.938214659690857` | `0.33808688941132353` | `0.583382016416033` |

Both full target and connected-road ground diamonds are contained in the safe
map rect. The compact target stays below scale `2.0` and retains more than
`0.33` district safe-width occupancy. A nearby semantically valid target and a
no-target opening both preserve the exact existing camera.

Contextual framing is gated by the published active action target matching the
selection. A nil or mismatched active target cannot synthesize target/district
context. The renderer does not invent a target, road, topology, or gameplay
availability.
