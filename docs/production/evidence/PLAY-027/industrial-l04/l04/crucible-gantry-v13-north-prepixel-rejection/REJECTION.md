# PLAY-027 Industrial L4 North v13 pre-pixel rejection

Disposition: `REJECTED_PREPIXEL_GATE`

Base: `fccc5f53fdedb4150ba588cc2ed9943172bec66c`

The substantive Crucible Gantry Works repair exhausted its two authorized,
materially distinct layouts. Neither passed all untouched literal-192
player-scale gates. This is a durable rejection, not source authority.

## Corrected contract

The v13 validator does not require three complete far-facade door rectangles.
It instead measures literal player-visible header/recess/post beats, their
visible pixel contributions and separators. It separately measures the bridge
beam, both uprights, clear opening, tapered crucible, mouth, staff return,
literal role-based grayscale medians, North socket contact, silhouette
connectivity, and negative alias against accepted Industrial L3.

## Attempt 1

`layout-01-longitudinal-open-court-gantry` passed gantry scale, court/socket,
staff, silhouette, value separation, material grouping, and non-alias gates.
It failed:

- crucible-to-support separation: `0`, required `>2`;
- freight beat 1: `2x3`, 4 visible pixels, required `>=4x3` and 12 pixels;
- freight beat 2: `3x3`, 7 visible pixels, required `>=4x3` and 12 pixels.

Exact output:

`FAIL v13 gates failed: ["crucibleSeparatedFromSupportsOver2", "freightBeat1AtLeast4x3", "freightBeat2AtLeast4x3"]`

## Attempt 2

`layout-02-transverse-gantry-road-edge-freight-zone` was a materially distinct
full-width transverse lifting assembly with the three beats moved to the
North road-edge court. It passed the same premium value, gantry, staff,
registration, connectivity, and non-alias gates, but failed:

- crucible-to-support separation: `0`, required `>2`;
- freight beat 1: `3x3`, 6 visible pixels;
- freight beat 2: `2x5`, 9 visible pixels;
- freight separators: `[-1, 8]`, both required `>2`.

Exact output:

`FAIL v13 gates failed: ["crucibleSeparatedFromSupportsOver2", "freightBeat1AtLeast4x3", "freightBeat2AtLeast4x3", "freightSeparatorsOver2"]`

The two-layout ceiling is exhausted. No sightline tweak, third layout,
threshold change, raw render, or post-failure reinterpretation was performed.
Unaided native and exact-192 color/grayscale inspection agrees with the hard
stop: the transverse beam still reads closer to a canopy/portal than premium
lifting machinery, the crucible/support silhouette merges, and two freight
beats do not survive as distinct loading rhythm. No reviewer score is claimed.

## Strong passing measurements

The final layout retained these exact literal-192 results:

- gantry beam bounds: `39x25`;
- gantry uprights: `22x12` and `14x26`;
- clear aperture: `24.0000018558x18.8960651912`;
- crucible: `25x25`; mouth: `8x5`;
- staff return: `6x12`;
- roof/hall median luma: `83/126`, delta `43`;
- gantry/hall median luma: `44/126`, delta `82`;
- crucible/gantry median luma: `93/44`, delta `49`;
- freight recess/header median luma: `49/105`, delta `56`;
- accepted-L3 silhouette IoU: `0.6867749419953596`;
- North court reaches world road edge `z=-28` and the exact socket.

## Tool and evidence identity

Warnings-as-errors compile:

```text
xcrun swiftc -module-cache-path /tmp/play027-v13-module-cache -parse-as-library -warnings-as-errors Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV13NorthPrepixel.swift -o /tmp/build-industrial-l4-v13-north-prepixel
```

- final builder source SHA-256:
  `25e91ff37b7a73cf2d5613265f911d92dbb7afaf88cd2505d080702fe2d186c3`;
- final compiled binary SHA-256:
  `3a9676e75b12206ad49f5298bbd9b7787f9d5b0ce1cc069c2b69d0821867940f`;
- layout 01 descriptor SHA-256:
  `e26f2a4d438738081055406dd86631d6382f8c64b5a1f5175197df26c381d000`;
- layout 02 descriptor SHA-256:
  `592bca8998bfb929982d38b2a732cbae0c327eddb5b23c66f2890e7b4c482db7`;
- material SHA-256:
  `95d349f7f5bcc5ffbd5d42ef99e641f033b9fcd74171ba278849185a24f5626e`.

Each attempt retains its production-decodable descriptor/material artifact,
complete metric report, source/native/exact-192 color and grayscale panels,
semantic/value/registration/silhouette/hero masks, v12-v13 comparisons, and
blind accepted-L3-v13 comparisons.

Neither attempt reached the complete-pass boundary, so two-run replay identity
was correctly not consumed or claimed. Raw, SceneKit, Metal, and normalizer
process counts are all zero.

`sourceAuthority=false`

`productionSelected=false`
