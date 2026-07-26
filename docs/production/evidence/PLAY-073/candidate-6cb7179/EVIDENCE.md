# PLAY-073 integrated contextual-framing evidence

## Disposition

This packet binds the narrow typed-target contextual-framing correction to the
accepted integrated product truth plus a test-only safe-pre-fit repair.

The exact staged regular and compact routes confirm:

- the Day 1 default opening remains unchanged and readable;
- a legitimate remote Commercial target keeps its full ground diamond, the
  nearest connected road diamond, and a meaningful share of the developed
  district visible;
- switching the same active target to Road preserves that context;
- AX availability and reason match the visible Commercial/Road states.

This is not PLAY-073 completion. The overall seven-place opening remains sparse,
PLAY-076 remains the authoritative density dependency, and PLAY-077 still owns
the same-coordinate Road recovery target. The pointer Catalog pass-through path
was not used for proof and was not compensated for in the renderer.

## Exact identity

- Branch: `codex/citysim-world-rendering`
- Accepted local master authority:
  `9c6dc0b032098c60bb2ebcfb2aba411fb3b4fc27`
- Sync merge:
  `bfbe0466dbc620c0614697f90445b5f8632bcb77`
- Accepted renderer parity restoration:
  `9bd5d1dbf879816a99ef39b8dc4a56d1501aae73`
- Test-only safe-pre-fit repair:
  `6cb7179c60f7951d39d7e54733ddc34287be06f9`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle identifier:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged app:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Staged executable:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Packaged resources:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle`
- Captured staging manifest: `identity/candidate.manifest`
- Day 1 source save:
  `/private/tmp/play073-iteration3-day1.dYhZrD/quicksave.json`
- Day 1 source save SHA-256:
  `fbedaf5f4695cf506f4a19291d359d2c655fc0789893d854674b92a74b75d4ac`

The staging verification launched PID `54588`. The controlled regular route
used PID `55064`; the final compact route used PID `56292`. All were terminated
after capture, and the final exact-process check found no surviving candidate.
An intermediate compact run at PID `55717` was excluded because its remembered
window origin was offscreen and produced white capture padding. Only window
position was corrected before the final uncropped capture; product and save
bytes did not change.

## Product parity

`LotRenderer.swift` at the candidate resolves to blob
`ea5fb96074f54bc83d0b38a9273d3ab7826eb93b`, exactly matching master
`9c6dc0b`. The previously unaccepted frontage experiment remains recoverable in
branch history but is absent from the candidate.

Relative to exact master, the only surviving product-repository difference
before this evidence packet is the focused
`WorldRenderingTests.swift` safe-pre-fit regression. It configures a genuinely
safe semantically valid Commercial or Road target context before asserting the
nearby-target no-op path; it does not loosen the production opening camera.

## Real staged routes

Every binding route used the exact staged executable, a fresh isolated data
root, the same Day 1 save, Command-O, and a paused simulation. Captures were
retained only after load/action transients cleared.

The keyboard route was:

1. press `C` for Commercial;
2. use Right, Shift-Right, Right three times, Shift-Down, and Down to reach
   block `20,18`;
3. retain the blocked Commercial frame and its authoritative
   `This building needs direct road access` reason;
4. press `r` and retain the available Road preview at the same coordinate.

The pointer Catalog pass-through path was intentionally excluded.

Regular captures are uncropped `1278 x 768` decorated windows:

- `live/play073-6cb7179-regular-default.png`
- `live/play073-6cb7179-regular-commercial-blocked.png`
- `live/play073-6cb7179-regular-road-recovery.png`

Compact captures are uncropped `900 x 652` decorated windows containing the
exact `900 x 600` app content:

- `live/play073-6cb7179-compact-default.png`
- `live/play073-6cb7179-compact-commercial-blocked.png`
- `live/play073-6cb7179-compact-road-recovery.png`

Matching full AX trees are retained under `ax/`. They prove Day 1 paused
identity, no selection at default, Commercial unavailable at block `20,18`,
and Road available at block `20,18`.

## Camera contract

The exact regression freezes these contextual metrics:

| Route | Camera scale | District safe width | District safe height |
|---|---:|---:|---:|
| regular remote target | `0.8172323107719421` | `0.6095568301831683` | `0.5833820573567386` |
| compact remote target | `1.938214659690857` | `0.33808688941132353` | `0.583382016416033` |

Both complete target and connected-road ground diamonds must remain inside the
safe map rect. A semantically valid nearby target is tested in a deliberately
configured safe pre-fit camera and must leave camera scale and position exact.
No target, a nil active target, or a mismatched active target cannot synthesize
contextual framing.
