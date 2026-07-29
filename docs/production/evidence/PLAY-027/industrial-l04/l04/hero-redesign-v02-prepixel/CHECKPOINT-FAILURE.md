# Industrial L4 hero v02 concept/tool checkpoint

- Task: `PLAY-027`
- Published authority:
  `b264e3e81c870c6e52961add93ae9b50edcf1f80`
- Accepted continuity:
  `5b1378a2c81d7d55a39b19366b5206c28f70d9f7`
- Disposition: `CHECKPOINT_PREPIXEL_VALIDATION_FAILED`
- Source authority: `false`
- Production selected: `false`
- SceneKit/Metal source processes: `0`
- Normalizer processes: `0`
- ImageGen calls: `0`

The fresh v02 tool contains the three required analytic concepts and selects
the heavy-fabrication works for its broad high-bay hall, lower
assembly/control wing, overhead gantry, pipe bridge, paired stacks, silos,
three oversized freight openings, separate staff entrance, and warm/dark
weathered material system. The rejected v01 tool, descriptors, materials, and
evidence remain unchanged.

The standalone tool compiles with:

```text
swiftc -module-cache-path /tmp/play027-l4hero-module-cache-7 \
  -parse-as-library -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4HeroPrepixel.swift \
  -o /tmp/build-industrial-l4-hero-prepixel-v7
```

The bounded replay stopped before review-panel generation:

```text
incomplete west bounds: [[-28.0, 0.0, -28.5], [28.0, 75.0, 28.0]]
```

Exact failing invariant:

- required root X/Z: `[-28, 28]`;
- observed West minimum Z: `-28.5`;
- contributing primitive: `w-assembly-roof`;
- primitive center Z: `-19`;
- primitive depth: `19`;
- resulting minimum Z: `-19 - 19/2 = -28.5`.

Earlier structural-owner failures were repaired without weakening the
validator. The latest replay reached the West footprint gate and did not run
the concept panels, descriptor packet, review manifest, or any pixel process.
The next checkpoint must correct the real roof extent and replay the complete
pre-pixel gate; it may not relax the footprint invariant or import rejected
v01 massing.
