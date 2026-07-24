# PLAY-022 Round 1 visual candidate checkpoint

**Disposition:** exact visual candidate and live proof retained; independent
scoring is deferred pending the PLAY-051 shared active-placement-target
contract. This checkpoint is not self-accepted.

**Task status:** PLAY-022 remains active. This record does not accept Round 1,
authorize Round 2 or PLAY-023, or itself authorize merge or push. Integration
owns the placement-target contract, acceptance, and any subsequent
implementation dispatch.

## Authority and exact candidate

- Claim base: `74b694de50e5ee021ea3d0512cfcad3e8f9c3e30`.
- Rejected comparison baseline: `8cb45b5848f070c25803213ee48b2523e8057d09`.
- Round 1 authority: `313a16b35765748c5ed3451177352f6c4440ddc6`.
- Authority merge: `a69e927df62735c3c4324f82b968fbd6db278034`.
- Product candidate: `3c44905467de4a6629098f6be51d0ac90f56f5f0`.
- Branch: `codex/citysim-world-rendering`.
- The evidence-record commit is reported in the lane handoff. Candidate
  isolation and independent scoring are deferred until integration resolves
  the PLAY-051 shared-target dependency.

## Player-visible Round 1 outcome

The staged starting city now uses one physical 2:1 grammar: quiet macro
terrain, deterministic connected asphalt/curb/sidewalk/crossing topology,
frontage-aware generated-v4 places, northwest light and southeast contact
shadows, bounded vegetation/pedestrian/service life, and three useful camera
stops. The city, neighborhood, and block stops progressively reveal network
shape, frontage/family identity, and material/entrance/prop detail. Selection,
placement, and diagnostics remain grounded and subordinate to the place.

This is a review observation, not an acceptance score. Integration and playtest
must review the shipping staged start and independently meet the controlling
17/20, no-category-below-3 threshold.

## Ordered Round 1 commits

1. `ae6c2ba6c8b693f73dd18f24026104ad536830be` — `PLAY-022: Register physical world asset geometry`.
2. `78a6aa385a86a47c2b4b90bc42c298002b276c71` — `PLAY-022: Compose the production city corridor`.
3. `57910210ac7e1e783ae041b62da994bad1457525` — `PLAY-022: Complete the generated visible set`.
4. `2e77ee0393e8c60fe057434c410cdf46629833a1` — `PLAY-022: Restrain world interaction emphasis`.
5. `fce135bc69f3578cc6ba724f82fce2de90280156` — `PLAY-022: Align renderer acceptance expectations`.
6. `ae1e2730b7d73c75774353a778d01f7d849143ed` — `PLAY-022: Fill the shipping city frame`.
7. `95c801b5265a8d1121f0f33b502e86f6a65367b1` — `PLAY-022: Lock the compact neighborhood LOD`.
8. `e06ccdd1ecabf78b72999dbf19be3f5b7fa7e2b1` — `PLAY-022: Keep the city planning stop readable`.
9. `2da401ccba3bac448fb5edbf87bdfd65b19c3192` — `PLAY-022: Art-direct the strategic camera LODs`.
10. `3c44905467de4a6629098f6be51d0ac90f56f5f0` — `PLAY-022: Make the city LOD inspectable`.

The exact 62-file product/evidence surface inventory is retained in
`CHANGED-SURFACES.txt`. No integration-owned `Views/`, public
store/snapshot/command, save schema, Package.swift, build script, gameplay, or
legacy Python surface changed.

## Milestone results

### 1. Physical asset geometry

- Descriptor-driven footprint, pivot, opaque/shadow bounds, overhang,
  frontage, depth-role, collision, and bounded-residency plumbing is active.
- Maximum pivot drift: 0.000001 source pixel.
- Maximum LOD opaque-bound registration error: 1.128907 world points.
- Reciprocal ground collision checks: 324; collisions: 0.
- Building/road setback checks: 36; collisions: 0.
- Entrance/prop exclusion checks: 256; collisions: 0.
- Orphan inventory entries and missing references: 0.
- Evidence: `milestone-1-physical-geometry.json` and
  `milestone-3-geometry.json`.

### 2. Coherent corridor

- Macro terrain replaces the repeated per-cell plate.
- All 16 road masks per LOD have deterministic sockets, intentional termini,
  curbs, sidewalks, and useful-detail crossings/frontage joins.
- Final thresholds are block at or below 0.60, neighborhood 0.61-0.70, and city
  above 0.70; proof stops are 0.50, 0.66, and 0.74.
- Final shipping-harness developed occupancy is 64.0% by 62.7% at 1280 by 800
  and 61.6% by 56.6% at exact 900 by 600.
- Evidence: `milestone-2-road-topology-seam-mosaic.png`, historical milestone
  harness JSON/PNGs, and the final `live-3c44905` three-LOD sequences/mosaic.

The milestone 2 and 3 JSON camera values are historical checkpoint evidence;
their 0.784722 compact value pre-dates the final threshold correction and must
not be used to label the final staged stop. The scale sheet and final live
record hold current authority.

### 3. Complete visible set

- Generated-v4 pack: schema 4, 12 semantic assets, 84 inventory entries.
- Round 1 added one built-in ImageGen source each for a pedestrian pair,
  neutral maintenance object, and vegetation cluster. Raw sources, exact
  prompts, immutable appearance/template reference hashes, normalization
  records, cleanup commands, registrations, and rejection arrays are retained.
- New raw source SHA-256 values:
  - pedestrian pair: `335290e1e81bb9a46ab6b059f96ad6e7b6365c48d5e6abae55c281ae8d7ce30b`;
  - service object: `bfac1b625f79978a5e598c35e43b35a65238c68d5a950efda27b6be2ada55181`;
  - vegetation: `99a11b2cdda5b2d471bf041d920d57e70e46dd72ee63c77b62b997de378e16ca`.
- Corresponding prompt hashes:
  `9d4ba52851615d6c25af8e8a3091af0442e0c037e9afc5cbe21966fad76ed3e0`,
  `5fdb7e88e9a5a77cb14eb5055a34a24b1f7a047f9a6ea9323a589623bb8e5237`,
  and `32f88e26df8d25635e03d7849a61d177a455d10186d5b623727c80d2b08cdf1c`.
- Ambient objects are decorative only and make no occupancy, traffic,
  prosperity, pollution, service, capacity, or employment claim.
- Generated-v4 manifest SHA-256:
  `afedf49fc0df87fa67733dd1b6a990aabcf22e77051425c78da222153353c93a`;
  source and staged resource-bundle bytes match.

### 4. Interaction restraint

- One grounded selection boundary and one frontage anchor; no floating world
  label or duplicated rejection copy.
- Valid placement uses boundary plus semantic ghost. Invalid placement adds a
  low-alpha ghost and three non-color hatches; the store remains sole reason
  authority.
- Utilities and pollution use sparse approved coordinate truth. Land value,
  traffic, and happiness abstain without approved spatial truth.
- Selection, hover, and placement visuals remain distinct at regular and exact
  compact dimensions. Pointer and keyboard each act on an exact coordinate in
  isolation; simultaneous hover-versus-selection target agreement is the
  PLAY-051 shared-contract blocker documented below.

## Exact staged identity and save

- App: `dist/CitySim-world-rendering-w5f893ad1da1b.app`.
- Executable SHA-256:
  `3a834dee98eddbf7d03536611a9918474372fa19212b4815f1df9d39075b1b02`.
- Candidate ID: `world-rendering-w5f893ad1da1b`.
- Bundle/preference domain:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`.
- Data root: `dist/test-data/world-rendering-w5f893ad1da1b`.
- Final staged-verification PID: 8173; verified and then terminated by exact PID.
- Live capture/RSS PIDs: compact 52697, regular 64411, final interaction 69597;
  each terminated by exact PID after capture.
- Save: `quicksave.json`, file SHA-256
  `935df087123ff0468eb36a0de77b9178e23f71166ca55a3e60f99ca4c51bdab7`,
  state digest
  `4d78ec5b9ef24043c41cefe50c41bf98d71027fb3725b616ce24ccde8d028b81`,
  tick 38.

## Automated validation

- `swift test --package-path Native/CitySimNative --filter CitySimNativeTests.WorldRenderingTests`:
  30/30 passed in 20.995 seconds.
- Final camera/LOD/keyboard focused group:
  3/3 passed in 1.145 seconds.
- `swift test --package-path Native/CitySimNative`: 127/127 passed in 71.268
  seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed at exact product candidate
  `3c449054`; packaged generated-v4 manifest exists and matches source bytes.
- `git diff --check`: rerun after evidence staging and reported in the final
  handoff.
- Candidate isolation: deferred with independent scoring until the PLAY-051
  shared active-placement-target contract is resolved.

## Live journeys

- Pointer: selected Commercial 14,12 and retained the authoritative accessible
  condition, utility, pollution, and vitality announcement.
- Keyboard: selected Road 14,13; selection survived camera changes.
- Invalid: Residential on occupied Industrial 15,12 showed the grounded hatch
  and one store-owned demolition reason.
- Valid: Residential on open 16,14 showed an unobscured boundary, frontage
  anchor, cost, and upkeep.
- Commit/construction: the same 16,14 parcel showed prepared foundation,
  50-percent frame, and 75-percent finishing.
- Undo: removed the construction and restored treasury from 19,930 to 21,730
  with cashflow unchanged at -89.
- Save/load: staged Save then File > Load City restored a paused tick-38 city
  at treasury 25,432.1, cashflow -66, population 309, and jobs 190.
- Overlays: utility and pollution marks remained sparse and readable.
- Pan/zoom: 44.183 seconds of continuous app input represented by a 41-second
  app-only H.264 proof and exact event trace.

## Accessibility and Reduce Motion

- Map remains an accessibility group with coordinate, kind, lifecycle,
  condition, and consequence descriptions.
- Pending placement announces validity, cost, upkeep, and the one invalid
  reason; construction stages are announced.
- Custom map actions remain available; no duplicate unknown labels were found.
- Reduce Motion proof suppresses actions while preserving static meaning.
  Paused exact-compact frames three seconds apart measure SSIM 0.999762 and
  average PSNR 50.819494 dB.

## Performance and residency

- Shipping frame: 3,616 nodes / 1,398 drawables; Reduce Motion actions 0.
- Changed pulses, three fresh processes: 1.499, 1.241, 1.507 ms; mean 1.415667,
  median 1.499, all below 2.1 ms and mean 23.44% faster than the accepted
  PLAY-021 1.849-ms changed-pulse average. Reuse/update count remained
  5,759/1 across ten pulses.
- Unchanged 4,286-pulse soak, three fresh processes: 0.0005, 0.0004, 0.0004 ms
  average; nodes/drawables/actions stayed 3,616/1,398/1.
- Resident texture high water across repeated LOD cycles: 28 textures,
  41,959,424 decoded bytes, 336 evictions, zero fallbacks. City,
  neighborhood, and block decoded bytes are 2,625,536; 10,502,144; and
  41,959,424.
- Compact RSS after three cycles: 87.28125 MiB. Regular RSS: 94.234375 MiB.
  Both are below the explicit 333.8-MiB Round 1 RSS ceiling.
- Separately sampled compact/regular macOS footprints were 362/397 MiB, with
  peaks 382/402 MiB. They are lower than the rejected candidate's 475-MiB
  fresh and 707.7-MiB traversal footprints, but remain above 333.8 MiB if the
  RSS ceiling is also applied to `footprint`. No exception is claimed.
- The historical cold golden-fixture marker is 48.452-64.641 ms (median
  52.822) after adding generated-v4 block-detail loading, versus 5.025 ms in
  PLAY-021. Pulse timings remain inside their gates; integration should review
  the cold-load increase before acceptance.

## Retained proof and limitations

The complete artifact mapping, dimensions, derivation notes, and honest proof
limitations are in `live-3c44905/EVIDENCE.md`; exact hashes are in
`live-3c44905/SHA256SUMS`.

Important limitations submitted for reviewer disposition:

- the exact-coordinate construction sequence omits separate 25-percent and
  100-percent frames;
- compact LOD captures are same-seed but not same-state; regular LOD captures
  are same-state;
- pan/zoom evidence is 1-fps app-only capture rather than fluid video;
- no bytewise pre/post digest was retained for the live save/load and undo
  journey, although native persistence/undo equality tests pass;
- allocator footprint and cold golden-fixture time remain disclosed review
  concerns as quantified above;
- the Round 1 visual result requires independent review and has not been
  scored by this lane.

## Blocking cross-lane disposition

The renderer preview and click currently use `CityScene.hoveredCoordinate`.
Accessibility, Return, and command availability use
`CityGameStore.selectedCoordinate`. Both call the same
`CitySimulation.validateBuild` truth, but they can truthfully describe
different tiles at the same time. Resolving which coordinate is authoritative
for pointer hover versus keyboard selection changes player-intent policy and
crosses the renderer/store boundary. Exact surfaces and the smallest proposal
are retained in `PLAY-051-PLACEMENT-TARGET-PROPOSAL.md`.

## Independent dispositions

- Integration: **deferred pending PLAY-051 target contract**.
- Playtest: **deferred pending PLAY-051 target contract**.
- Required: each reviewer at least 17/20 with no category below 3.

PLAY-022 remains active. Renderer product mutation and scoring are paused until
integration resolves the shared-target contract.
