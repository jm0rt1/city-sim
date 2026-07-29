# PLAY-073 source-stage-to-renderer adapter proposal

## Decision requested

Integration should publish one canonical, deterministic adapter from an exact
`source-stage-v2` candidate to the existing Renderer direction-packet-v2
shape, then publish `assembly-input-manifest-v1` only after all four directions
have separate Integration source-admission and Renderer-quarantine receipts.

This packet is task-owned evidence, not shared authority. It admits no source,
does not inspect or activate pixels, and changes no runtime, resource, atlas,
shipping manifest, package, fixture, or production-selection surface.

## Closed mapping

The adapter must consume one strictly validated source-stage handoff plus the
Integration-owned governing contract, direction bridge, and appearance lock.
It maps source identity, source hashes, three LOD identities, provenance,
registration, and D4 fingerprints without inference or directory discovery.
The worker remains `source_candidate`; only Integration may issue the
subsequent admission receipt.

The six assembly locators are closed:

1. `raw` — the selected source raster;
2. `provenance` — the selected process provenance;
3. `normalization` — the PASS validation receipt proving repeat identity;
4. `descriptor` — the frozen input manifest;
5. `contact` — the source-stage handoff containing authoritative registration;
6. `review` — the completed review manifest.

East, South, and West prelock inventories remain intentionally incomplete.
Reserved paths, null values, predesign descriptors, dry fixtures, and
path-safety receipts cannot be promoted into Renderer packets. Missing values
produce a direction-local blocking receipt, not a partial packet.

## Candidate-neutral fixture

Assembly binds the published PLAY-075 directional mature-city fixture and
manifest. The exact state coordinates, player blocks, sole-road coordinates,
and canonical CitySim source-pixel sockets are declared in `PROPOSAL.json`.
Camera proof uses player-visible Frame Developed City, scales
`0.74 / 0.66 / 0.50`, and the published regular and compact window sizes.
Numeric centers are derived only in the future admitted live journey and must
remain bit-identical within a width.

## Atomic boundary

Zero through three valid directions remain inactive or
`quarantined_incomplete`. Exact North/East/South/West parity is an immediate
trigger: Integration publishes the assembly manifest and Renderer invokes the
existing 4/4 join once. The resulting ledger remains nonshipping with 12 unique
LOD identities, 32 unique D4 identities, and every activation/selection flag
false.

If the manifest or serialized product authority is absent at the fourth
receipt, Renderer emits a blocking receipt naming that missing authority. It
must not wait silently, infer paths, or mutate shipping surfaces.

## Integration-owned publication order

1. Publish canonical packet/manifest schemas and the deterministic adapter.
2. Adapt and independently admit each complete source-stage candidate.
3. Let Renderer quarantine each exact admitted packet.
4. Publish the accepted-L3 binding and exact 4/4 assembly input manifest.
5. Run the nonshipping atomic join.
6. Authorize product packing/runtime/staging separately.
7. Submit one exact candidate to PLAY-075.

Any schema ambiguity, provisional input, hash/path/containment failure,
authority drift, alias/transform/fallback, registration error, fixture/camera
drift, or premature activation is a hard stop.
