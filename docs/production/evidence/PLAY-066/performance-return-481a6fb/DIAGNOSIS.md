# PLAY-066 cold-update return diagnosis

- Returned product:
  `481a6fbf09b8a31dff85941b3b9ebce0ca11715d`
- Durable evidence:
  `bdcc7210d44c06e152c478185dd35f69e57b53a3`
- Claim: PLAY-066 world rendering
- Disposition: active renderer performance repair; not ready for completion

## Reproduction

Two unchanged focused renderer rechecks each executed 60 tests with one
failure:

| Run | Golden world update | Golden total | Ceiling |
|---|---:|---:|---:|
| first | 6.912 ms | 9.801 ms | update <= 6.03 ms |
| second | 7.288 ms | 9.683 ms | update <= 6.03 ms |

Both runs had zero asset decode loads and passed the other 59 tests. The
failure is therefore reproducible renderer construction cost, not a source
decode, fallback, collision, or identity failure.

## Profile boundary

`CityScene.updateWorld` measures backdrop, render preparation, and the complete
tile-record build. Ambient selection/rebuild and the final runtime-tree recount
occur after that measured world-update boundary. The failing metric therefore
cannot be repaired by hiding work in activity selection or by weakening
runtime diagnostics.

The PLAY-066 public-realm commit added the only large new cold tile-build
surface:

- every completed lot constructs city, neighborhood, and block context at
  once so camera changes remain allocation-free;
- each context repeatedly rebuilds identical immutable paths, palette blends,
  and SpriteKit subtrees for the same bounded
  family/variant/frontage/geometry identity; and
- the historical golden test constructs four separate scenes in one process,
  so the same immutable context identities are rebuilt for city,
  neighborhood, block, and compact frames.

The final activity-correctness repair remains outside the failing
`updateWorld` timing boundary and must not be weakened.

## Smallest authorized repair

Add a renderer-owned, bounded immutable lot-context template cache keyed by:

- family;
- deterministic variant;
- authoritative frontage; and
- physical tile geometry.

Templates retain the exact existing node names, paths, colors, z-order,
placement ledger, and per-LOD composition. A lot receives a deep copy of the
cached city/neighborhood/block template, so later visibility or node mutation
cannot change the source template. The finite key space prevents residency
growth. No pixels, camera/LOD rules, truth, assets, simulation, UI, or package
surfaces are intentionally changed.

Acceptance requires five fresh-process focused runs on the repaired commit,
all 60/60 with the governed update <=6.03 ms, plus unchanged-pulse average
<2.1 ms, full native/staged/resource/geometry validation, and zero visible or
interaction regression.
