# PLAY-073 R4-A renderer handoff

Status: **ready for independent Integration review; not self-accepted**.

## Exact identity

- Renderer product: `76bec82739c8487d170c8725af45fe6f1025aacb`
- Source/test evidence parent: `565cf32df59d755bbf745fbf6446cf6328ed020c`
- Product foundation: `d7cdf8f57fed20b952f3eb637cc0a96b336dd1c8`
- Published operating authority consumed at the clean checkpoint:
  `a12f5fd71a8a3a846cd82cae7c204eacdfb539ed`
- PLAY-073 claim SHA-256:
  `47a260aea5ab9d38a98ceaaefb61e89e00322110b5a833e964a59d13157d7a49`
- Branch: `codex/citysim-world-rendering`

The evidence directory is named for the exact renderer product. Later commits
in the candidate chain alter tests/evidence accounting only; they do not alter
the product pixels or resource payloads.

## Outcome

The opening renderer now prepares the first grid deterministically, retains all
576 logical tile identities while avoiding presentation roots for structurally
empty cells, caches exact map-edge/backdrop prototypes, and extends only
authoritative road-adjacent buildable frontage ground. No road, occupied lot,
commons classification, hit target, gameplay fact, or accepted art byte is
invented.

The final color-independent persisted-mask gate matches the live raster:

| Layout | District width | District pixel share | Largest coarse plain component |
|---|---:|---:|---:|
| Regular | 1.000000 | 0.432979 | 0.238350 |
| Compact | 1.000000 | 0.512389 | 0.182716 |

Both layouts retain empty buildable frontage bands. The category ledger binds
12 authoritative occupied places, 34 roads, 11 empty enclosed commons excluded
from district/public-realm credit, and 29 empty road-adjacent frontage cells
counted as public-realm ground but never as occupied or special.

## Performance

Five fresh processes were retained in order with no replacement. All receipts
use schema 2 / `play073-r4-a-governed-cold-path-v2`, bind the exact product and
one XCTest binary SHA, begin at backdrop cache count zero, and end `0 -> 1 -> 1`.

- Cold world update: median `0.057167 ms`, maximum `0.059708 ms`
  (`6.03 ms` ceiling).
- First-grid preparation: median `11.663958 ms`, maximum `12.527208 ms`
  (one 60 Hz frame, `16.666667 ms`, ceiling).
- Cold total render: median `238.587458 ms`, maximum `245.593792 ms`.
- Cold asset decode: median `198.082167 ms`, maximum `204.801834 ms`.
- Preparation is included in total render; no duplicate first-grid
  construction survives after the update.

The older v1 receipts are retained under `rejected/pre-v2-definition/`.
They are not cited as passing because v1 did not distinguish the separately
budgeted scene-initialization preparation interval.

## Validation

- WorldRenderingTests: 74 executed, 1 expected skip, 0 failures.
- Full native suite: 321 executed, 3 expected skips, 0 failures.
- Two full atlas roots: 79 files each and byte-identical inventories.
- Pack validation: pass; source/staged temporary atlas parity true.
- Geometry validation: pass; zero reciprocal ground, road, or entrance
  collisions.
- Active decoded residency: city `1,746,024`, neighborhood `6,818,288`,
  block `26,807,376` bytes.
- Repeated LOD diagnostics: zero fallback.
- Regular and compact City/Neighborhood/Block color and grayscale frames are
  distinct and share one center.
- 16 road masks across three LODs, lifecycle/recovery, construction, typed
  consequence overlays, selection, and preview evidence are retained.

Commit `4d8322a7` updates one stale camera-scale expectation in
`CityCommandCatalogTests.swift`, a UI/input-owned test surface. It changes no
UI or product source: the assertion now binds the renderer's accepted regular
and compact Focus City scales. This cross-lane test-only adoption is disclosed
for Integration review rather than treated as independent UI acceptance.

`staged_matches_source` in the pack validator means parity between the two
temporary complete atlas roots. It is not a shared staged-app run.

## Deliberately unrun

The isolated Industrial L3 PLAY-075 lease remained active, so this task did
not replace or launch a shared staged bundle. Player-facing staged-app AX and
Reduce Motion journeys are therefore explicitly unrun. The Swift suite covers
renderer Reduce Motion semantics and accessibility contracts, but those tests
are not represented as the independent staged-app acceptance gate.

## Rejected evidence

All known non-candidate receipts remain under `rejected/`, including:

- the pre-depth visual and full-suite packet;
- the `0.25210084` persisted coarse-mask near miss;
- the pre-v2 cold receipts;
- the incomplete temporary-atlas validator invocation.

No rejected receipt contributes to the passing summaries.

## Internal parallel work accounting

The lane used four slots: one visible-lane owner and three read-only helpers.
The helpers overlapped the exact-product exporters/renderer gate and audited:

1. baseline/candidate semantic masks and category truth;
2. cold-path timing/accounting and cache identity;
3. evidence completeness, resource binding, and integration risk.

They made no files, commits, builds, or renderer processes. Git, governed
evidence, source/tests, and final validation remained serialized under the
visible lane owner. Their audits caused the persisted-mask orientation fix,
the v1-to-v2 timing-definition correction, stricter one-frame preparation
ceiling, test-binary binding, and rejected-evidence curation.

## Deferred

- Independent Integration review and any later QA same-SHA staged journey.
- Sync to newer published master until Integration reviews this frozen
  candidate.
- Asset-rich commons/landscape source art.
- All Industrial L4 source quarantine or atomic assembly.
