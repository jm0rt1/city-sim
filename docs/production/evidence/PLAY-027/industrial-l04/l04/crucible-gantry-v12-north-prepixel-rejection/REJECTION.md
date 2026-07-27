# PLAY-027 Industrial L4 North v12 pre-pixel rejection

Disposition: `REJECTED_PREPIXEL_GATE`

Base: `e209309bc105b1ab49deec77032ca145a54591a6`

The bounded Crucible Gantry Works reset exhausted its two materially distinct
North layouts without passing the governed semantic frontage visibility gate.
This checkpoint is durable rejected evidence, not a source candidate.

## Attempt results

1. `layout-01-parallel-road-court` retained the broad hall, gantry, crucible,
   grouped freight zone, staff annex, and subordinate stack. The exact builder
   failure was:

   `FAIL v12 semantic regions missing: ["freight1", "freight2"]`

2. `layout-02-perpendicular-l-court-final-sightline-correction` changed to the
   authorized perpendicular/L-court concept. One final sightline-only geometry
   correction was applied to expose the governed North frontage. The exact
   final failure remained:

   `FAIL v12 semantic regions missing: ["freight1", "freight2"]`

The second result is the final allowed layout-02 outcome. No third concept,
threshold change, or post-failure reinterpretation was attempted.

## Commands and tool identity

Warnings-as-errors compile:

```text
xcrun swiftc -module-cache-path /tmp/play027-v12-module-cache -parse-as-library -warnings-as-errors Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV12NorthPrepixel.swift -o /tmp/build-industrial-l4-v12-north-prepixel
```

The attempt form was:

```text
/tmp/build-industrial-l4-v12-north-prepixel --repository-root /Users/James/.codex/worktrees/0648/city-sim --artifact-root <attempt-artifact-root> --evidence-root <attempt-evidence-root>
```

- Builder source SHA-256:
  `98b2060ba48e476da52526990d5df6a43c7316aed4592e0fef0c3da6d5c2dd8b`
- Compiled binary SHA-256:
  `a444795893df71c48fc986c901a93d5a15fbb6098caf95cefa0fa6882843f919`
- Both attempts use material SHA-256:
  `d2784ddde15fdc458cfec44090ccbcdd6f9c941c7d2aff6cff76447341471c33`
- Layout 01 descriptor SHA-256:
  `69d216ed2c7ac02f2211c3f8f7c2191273aeef40af2a8f376232d05240cac64e`
- Layout 02 descriptor SHA-256:
  `fd1e78574a583dceca1dd14ed7023ddde53b3f5a514e74e6c65abe21af2baac5`

## Bound visual evidence

Each attempt retains its persisted descriptor/material artifact and 23
descriptor-camera analytical panels. Key exact-192 hashes:

| Attempt | Color | Grayscale | Semantic |
|---|---|---|---|
| Layout 01 | `b37c31daad4b4b46b619f015e70ea42bbb0c17852fbf21421683bdc12ab8a1f7` | `3672d71c372211d133bd762407f7906cbd2cdfa872f6f47f2578e4aa2d0bcd80` | `f737b430060fb967f88d32b1e48eb16161f4f4744a8d9a0aab5ab7363083439c` |
| Layout 02 | `d4eb57128ba84268776aa2f31ec224ed44d1b8804103bb8d20cba4846d4a2b0c` | `d02d14209a02a7dc46bad2a23510ce9a5ed87ce7dfc7d6cda2b9c3ce0aecc86a` | `3db4cae1a2e58b49a9c24828c0120ae06e5a711dd4cadddd2c20811ca687e02e` |

The panels are analytic proof only. Neither attempt reached the complete gate,
so no replay identity claim is made. Raw, SceneKit, Metal, and normalizer
process counts are all zero.

`sourceAuthority=false`

`productionSelected=false`
