# PLAY-075 Industrial L3 replacement R2 validation

## Live route

1. Stage the isolated attached checkout at exact `472ffa85`.
2. Copy the immutable directional mature-city fixture into the unique candidate
   data root as `quicksave.json`.
3. Launch regular content at 1278 x 768, dismiss the first-run welcome, and
   invoke player-visible **Load City**.
4. Verify the paused Day 212 state and select West by direct pointer.
5. Move away and back by keyboard to prove parity, then visit North, East, and
   South and inspect the affected AX path.
6. Exercise city, neighborhood, and block zoom commands.
7. Save, demolish the South L3 parcel, invoke Command-Z, save again, and compare
   exact bytes.
8. Load the published pressured and construction fixtures and inspect visible
   and AX lifecycle meaning.
9. Terminate only the exact regular PID.
10. Relaunch the unchanged staged app at exact 900 x 600 content with Reduce
    Motion proof enabled, reload the directional fixture, repeat four-direction
    selection and three LODs, then terminate only the compact PID.
11. Rehash candidate, executable, packaged resources, and fixture.

## Direction and interaction ledger

| Direction | Canonical block | Regular | Compact | Interaction/AX |
|---|---|---|---|---|
| North | 11, 11 | Pass | Pass | Industrial Level 3, 89/330, road connected |
| East | 4, 10 | Pass | Pass | Industrial Level 3, 89/330, road connected |
| South | 5, 9 | Pass | Pass | Industrial Level 3, 89/330, road connected |
| West | 18, 12 | Pass | Pass | Direct pointer and keyboard parity; Industrial Level 3 |

The direct pointer actions exercised the map's hover/hit-test path before
selection. The retained evidence records the resulting selected state; it does
not claim a separate pre-click hover-only screenshot.

## LOD and layout ledger

| Layout | City | Neighborhood | Block | Result |
|---|---|---|---|---|
| Regular, 1278 x 768 | `regular-city-west-selected.png` | `regular-neighborhood-west-selected.jpeg` | direction-selected block captures | Pass |
| Compact, 900 x 600 content | `compact-loaded-reduce-motion.jpeg` | `compact-neighborhood-south-selected-reduce-motion.jpeg` | `compact-block-south-selected-reduce-motion.jpeg` | Pass |

Every capture is nonblank and the selected tile remains registered. The
generated-v4 manifest contains four L3 logical identities and twelve distinct
LOD payloads, with direction-specific `source_key`, `frontage_edge`,
`view_direction`, and `supported_orientation` fields and no mirror, rotation,
recolor, alias, or fallback field.

## State and accessibility ledger

- Maintained L3: completed, maintained, 55-57% vitality.
- Pressured L3: completed, distressed, 35% vitality.
- Construction: Industrial Level 1, construction site, 0%, 0 workers; visibly
  a foundation/site rather than the completed L3 family.
- Demolition: treasury `$67,999 -> $67,743`, cashflow `+$644 -> +$377`, job
  openings `963 -> 633`, selection cleared, structure removed.
- Undo: the visible state and metrics return; saved bytes before demolition and
  after Undo both hash to
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`.

## Resource and performance proof

The current exact-candidate Renderer record was consumed rather than rerunning
its already-current full suite:

- full Swift: 312 executed, 2 expected caller-input skips, 0 failures;
- focused renderer: 66 executed, 0 failures;
- external fixture: 1 executed, 0 failures;
- staged/source parity: pass, zero failures;
- four pack pages, 216 payload digests, 216 extrusion checks, 6,472 overlap
  checks;
- 12 Industrial directional identities and 36 normalized LOD hashes;
- zero fallback;
- cold total render 7.017 ms and cold world update 4.199 ms;
- repeated-LOD high-water decoded bytes: 26,807,376;
- pack active-plus-adjacent high-water: 50,331,648 bytes;
- live compact QA process RSS: 57,232 KiB.

The post-run worktree remained clean at exact `472ffa85`, all staged/source
manifests remained byte-identical, and the exact compact PID was absent after
termination.
