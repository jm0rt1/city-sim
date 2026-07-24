# PLAY-023 Generated-v4 Production Pipeline Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** clean candidate ready for integration; not pushed or self-integrated
- **Accepted beauty baseline:** `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Product:** `38e2134dd700a3d32c2bae201acbd4b0cca3aa38`
- **Evidence:** `24f07cd8b4d0fdbc1ebd5997fb3e230cee682322`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Manifest SHA-256:** `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72`

## Ordered task commits

1. `38e2134dd700a3d32c2bae201acbd4b0cca3aa38` — build the deterministic
   generated-v4 production pipeline, runtime page loader, bounded LOD cache,
   validation tools, rollback diagnostics, resources, and tests.
2. `24f07cd8b4d0fdbc1ebd5997fb3e230cee682322` — retain exact deterministic,
   geometry, staged-bundle, memory, default, compact, and three-LOD evidence.
3. This completion commit updates the active claim and records the consumer
   handoff; it changes no product source or resource.

## Delivered outcome

The accepted Round 1E pixels are now compiled into four stable,
power-of-two RGBA pages with deterministic shelf packing, four-pixel padding,
two-pixel edge extrusion, canonical manifest ordering, descriptor-owned
texture rectangles, and one ground pivot shared across all three LODs. The
manifest retains raw-source, prompt, provenance, normalization, payload-pixel,
page, and rollback digests without absolute development paths.

The SpriteKit loader reads those exact pages from `Bundle.module`, validates
page SHA-256, creates deterministic subtextures, prefetches only one adjacent
LOD, evicts outside the active set, and publishes named page/cache high-water
diagnostics. Missing assets and unknown pack selections emit bounded explicit
failures. `CITYSIM_WORLD_ASSET_PACK=legacy-v2` remains a working staged rollback.

The previous fragile workflow can no longer recreate unpacked shipping
payloads: its compatibility entry point delegates to the production packer,
and road compilation writes retained sources without mutating the shipping
atlas. No new art was generated, and all 84 accepted payload pixel digests
remain unchanged.

## Validation

- Two independent fresh builds produced byte-identical manifests and all four
  pages.
- Pack validation passed 84 payload, 84 extrusion, 974 overlap, 133
  source/provenance, all-road-mask, all-three-LOD, zero-drift, memory, and
  rollback checks.
- Geometry validation passed 324 reciprocal ground, 36 building/road setback,
  and 256 entrance/prop checks with zero collision, orphan, or missing
  references.
- Focused `WorldRenderingTests`: 41/41 passed.
- Full native suite: 190/190 passed in 90.983 seconds.
- Exact staged `./script/build_and_run.sh --verify`: passed.
- Source/staged manifest and page bytes: identical.
- Repeated live LOD cycles: zero visible breakage or hit-test loss; default
  settled at 149,792 KiB RSS and exact compact at 207,456 KiB after more than
  60 seconds, below the 333.8 MiB ceiling.
- The exact staged default, city/neighborhood/block, and 900 x 600 content
  frames retain the accepted connected district and composition.

The immutable packet is
`docs/production/evidence/PLAY-023/candidate-38e2134/VALIDATION.md`.

## Consumer handoff

- **UI/input:** no SwiftUI, command, player-intent, hit-test, or accessibility
  contract changed. Continue to consume `CityScene` normally; the page loader
  is renderer-internal.
- **Quality:** score the staged candidate identified above. The default and
  compact live frames are in the packet, and the accepted 17/20 visual pixels
  are protected by 84 payload-pixel digests.
- **Simulation/platform:** no snapshot, gameplay, save, replay, or deterministic
  simulation contract changed. No migration is required.
- **Integration:** adopt the two preceding commits plus this completion commit
  in order. The renderer-local validator records and compares source/staged
  pack digests. The integration-owned staging script was intentionally not
  changed; if integration wants pack fields embedded in its own candidate
  manifest, it can consume the same validator output without a renderer
  contract change.

No shared-contract proposal is required. PLAY-024 was not started.
