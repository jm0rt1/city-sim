# PLAY-066 developed public-realm envelope

Candidate base: `cef63edb11eb473aa4be63a0bce8f921df60f684`
Authority HEAD: `8af212aca6c281d75b9f12a3002b2b9fa22116ae`

The existing district fabric materials were strengthened without adding
geometry, nodes, parcels, roads, lots, gameplay cells, or new truth:

- `district.fabric.authored-envelope` fill alpha: `0.34 -> 0.48`
- `district.fabric.expansion-band` fill alpha: `0.16 -> 0.24`
- `district.fabric.public-realm-envelope` fill alpha: `0.48 -> 0.60`

Focused proof:

```text
CLANG_MODULE_CACHE_PATH=/private/tmp/PLAY-066-current8af2-clang-cache SWIFT_MODULECACHE_PATH=/private/tmp/PLAY-066-current8af2-swift-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/PLAY-066-current8af2-swift-cache swift test --disable-sandbox --package-path Native/CitySimNative --scratch-path /private/tmp/PLAY-066-current8af2-scratch --filter 'WorldRenderingTests/(testMacroTerrainReplacesTheRepeatedCellPlateAndKeepsEmptyLotsInteractive|testRoadEnclosedCommonsStayVacantAndJoinTheAuthoritativeFrontageNetwork|testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs)'
```

Result: 3 tests passed, 0 failures. Existing assertions retained buildability,
inverse coordinate mapping, road/lot geometry, camera framing, selection, and
zero active actions. The focused test also asserts the three resulting fill
alphas.

The six same-state seed-42 frame exports use the existing test-owned export
surface. Regular is logical `1280x800`; compact is logical `900x600` and is
stored at the host's 2x backing resolution (`1800x1200`).

| Frame | SHA-256 |
|---|---|
| `regular-city.png` | `6e5adc9f76a244ece263e9b0546c59c2dc759844bb2a953b982b552042cf1fb4` |
| `regular-neighborhood.png` | `71c35408434c17dfdcaf8913c2e248a8e796bbc84aca3976d905ad2296d08eac` |
| `regular-block.png` | `d0b40e8a6ab9479ea843361197f93564c9b8e48a09bb11201f7ddd523bef269c` |
| `compact-city.png` | `ca5353fc3350fdaaa8861602090b20c10efe4244c501fdb790bf706e335755fe` |
| `compact-neighborhood.png` | `3fa452f31ef41dfded1e466d1910c2c9b8cf4ec4d2c27856550c312f00a6d4ae` |
| `compact-block.png` | `ed66f097b0836f48c4de4b7b369308194f2f1702e3bcd7937acc58d6038bde67` |

This is focused renderer evidence only. Aggregate, staged-app, independent QA,
integration, push, and release gates remain outstanding.
