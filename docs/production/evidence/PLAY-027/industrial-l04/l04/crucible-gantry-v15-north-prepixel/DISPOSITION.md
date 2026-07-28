# PLAY-027 Industrial L4 North v15 Phase B disposition

`REJECTED_FIXED_CAMERA_APERTURE_GATE`

This is the single authorized v15 refinement outcome. It is pre-pixel
evidence only: `sourceAuthority=false`, `productionSelected=false`, and raw,
SceneKit, Metal, and normalizer process counts are all zero.

The v14 refinement-03 non-opening hero structure is preserved exactly at
SHA-256 `b909b52dc497b11dbc50f9f1d58fdd9b0c8b9bd8e5546b185734cc64188d1072`.
The proven recessed-opening helper was used to replace only the freight/staff
opening assemblies and the solid control-annex frontage volume.

## Binding failure

The exact fixed North camera does not encounter empty aperture space followed
by the inset back plane for freight 1, freight 2, or the staff opening:

- Freight 1 is occluded by the retained crucible rim, neck, upper body, and
  shoulder. Its aperture also intersects the retained road court and west
  court rail.
- Freight 2 is occluded by the retained east gantry pier and crucible upper
  body/shoulder. Its aperture also intersects the retained road court.
- Freight 3 has a valid empty-first/back-plane-second ray, but its aperture
  intersects the retained road court.
- The staff opening is occluded by retained gantry, hall, window, and control
  roof masses plus the replacement rear body/right wall.

The literal exact-192 color and grayscale panels agree with the structural
report: the three grouped freight recesses and separate staff opening do not
survive unaided as the required road-facing loading frontage. Semantic
coloring does not override this result.

## Reproduction

Compile:

```text
xcrun swiftc -module-cache-path /tmp/play027-v15-builder-module-cache-final -parse-as-library -warnings-as-errors Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/RecessedOpeningV15Support.swift Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV15NorthPrepixel.swift -o /tmp/build-industrial-l4-v15-north-prepixel-final
```

The builder exits 1 with:

```text
FAIL fixed-camera aperture ray/overlap gate failed
```

Exact machine evidence is in `PREPIXEL-VALIDATION.json`. Primary hashes:

- descriptor:
  `5c62a3ced28417809394e9bf48eee0962c3c017cbce48c7c65e51efe49303e02`
- unchanged v14 material library:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`
- builder source:
  `066d783bc5c18452225b26c6ecedf980570872c7bb68eca9fb2dada1d7bccb5f`
- recessed-opening support:
  `9761e3ee4172b1718f79410dfea89ee9899529717bb2b1905a553ad21c178fa5`
- compiled binary:
  `69f18a683a668cd5b045f9266f663ff0337ec07172b1045246899d57454bf009`
- exact-192 color:
  `d23579aa7a46bbb5bb1a3648d263b01e3c362a75f801ad85ca30b22fcf031e98`
- exact-192 grayscale:
  `6c838a77491b3b2c26592f1405f1ee605d044b2f1130d526c766e6bca46d3784`
- registration/contact:
  `84ec04c51b6bde1b8e66f7dc946ce33fcaee8b7f2da7582fe69ba432f990eaa6`

No further geometry adjustment, raw render, normalization, or second Phase B
refinement was run.
