# PLAY-073 R4-A candidate handoff

This packet binds the renderer-only R4-A authored-opening candidate to product
commit `570f4c8d4598a05ad3ef263e28c5df24722d6558`.

This is an author evidence checkpoint, not acceptance or a PLAY-075
player-facing disposition. The exact Industrial L3 candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f` and its same-SHA QA gate remain
isolated. R4-A did not launch, replace, or rebind the shared staged app.

## Ordered commits

1. `b69a9b7c83156ebdd9d0d126198942becdacafc3` — merge published R4-A authority
2. `0ad167ae` — freeze the pre-mutation rendered-pixel baseline
3. `e0f989f2` — implement smooth terrain grounding, continuous authoritative
   road/lot context, and placement-depth/footprint safeguards
4. `570f4c8d4598a05ad3ef263e28c5df24722d6558` — canonicalize the fixture digest
   used by separate-build evidence

## Classification boundary

The candidate ledger records 34 authoritative road coordinates, 12
authoritative occupied coordinates, and 11 road-enclosed empty coordinates.
The empty coordinates remain
`empty_buildable_natural_decoration_excluded_from_district_public_realm`.
They are not counted as occupied, special, or public-realm mass. Their nodes
retain the `district.commons.*` namespace; the district mask admits only
`district.ground.*`, authoritative roads, frontage, LOD, and lot-context nodes.

## Composition and terrain evidence

The generated field uses smooth low-frequency deterministic value variation,
not per-pixel grain. Texture dimensions derive from grid dimensions and colors
derive from the renderer palette.

| Layout | District safe-width share | Largest plain component | 32 px low-frequency plain component | District edge-energy share |
|---|---:|---:|---:|---:|
| Regular | 0.716315 | 0.097922 | 0.198625 | 0.853215 |
| Compact | 1.000000 | 0.065160 | 0.153086 | 0.959071 |

The low-frequency component measurement is the binding guard against passing
the terrain gate through high-frequency chroma or noise.

## Placement and LOD proof

- Roads retain exact scale, position, socket, and ground footprint.
- Building previews use restrained ghost scaling; road previews do not inherit
  that rule.
- Residential, road, power-plant/tall-lot, and bulldoze paths are covered at
  front/behind depth in regular and compact layouts, including valid outline
  and invalid hatch meaning.
- City, Neighborhood, and Block matrices retain one camera center and use
  distinct threshold scales, rendered hashes, grayscale hashes, and visible
  semantic-role sets. Hidden stacked nodes are not used as LOD proof.

## Determinism and resource disclosure

Two fresh scratch builds, `/private/tmp/play073-r4a-build-a.0N0zEI` and
`/private/tmp/play073-r4a-build-b.PwgiIF`, produced byte-identical frame, mask,
measurement-ledger, and LOD-receipt outputs. The canonical measurement ledger
SHA-256 is
`02d735403298d821d7c35917f22b6a102665a91c2b3ab426eee2d7946141b2b7`.

Fresh-process terrain cache observations:

- build A cold/warm: 35.906 ms / 0.196 ms
- build B cold/warm: 37.696 ms / 0.215 ms
- cache state in each process: 0 entries before cold render, 1 after cold, 1
  after warm

Renderer diagnostics from the exact product:

- cold world update: 3.996 ms against the 6.03 ms ceiling
- total render: 6.510 ms
- unchanged pulse average: 0.0006 ms against the 2.1 ms ceiling
- city nodes/drawables: 1611 / 678
- compact nodes/drawables: 1631 / 692
- generated-v4 residency/high-water: 50,331,648 bytes
- fallback count: 0

The separately sampled technical XCTest process peaked at 469,600 KiB RSS.
That is test-harness RSS, not staged-app RSS. Staged-app RSS and the
player-facing interaction journey remain outside this isolated R4-A checkpoint.

## Validation

- R4-A focused renderer tests: 5/5
- macro-terrain regression: 1/1
- service-campus regression: 1/1
- complete `WorldRenderingTests`: 71/71, 0 failures
- technical three-LOD export route: 1/1
- `git diff --check`: clean before evidence staging

The full machine-readable result and command ledger is in `VALIDATION.json`.
All retained frame, mask, and receipt hashes are in `FILES.sha256`.
