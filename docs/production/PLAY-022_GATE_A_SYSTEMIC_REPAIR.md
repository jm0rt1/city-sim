# PLAY-022 Gate A systemic repair

## Decision

The exact staged candidate at product commit
`7c54d2c48888f621260d12791e0a578328810048`, with evidence commit
`5f97317fa381baa57cb46055a055754edd1d7ddd`, is **rejected** at 12/20 by the
independent playtest-quality lane. It may not be integrated, treated as an
accepted Gate A, or used to authorize bulk generated-v4 production.

The authored district's interior is nevertheless the strongest visual
direction produced so far. Its material richness, northwest light and southeast
shadow, architectural density, foliage treatment, and civic focal hierarchy are
approved as a **provisional style reference only**. Its geometry, perimeter,
roads, LODs, camera composition, and monolithic rendering method are rejected.

## Why the candidate failed

- Default and city views still read as a small toy island in empty terrain.
- The plate has a conspicuous hard perimeter against legacy grass.
- Legacy roads terminate, pass behind, or fail to align with authored streets.
- City detail collapses under downsampling; compact and neighborhood evidence
  are byte-identical instead of proving distinct LOD behavior.
- Ambient life, continuous pan/zoom, interaction priority, and Reduce Motion
  were not retained in live evidence.
- The reported 1.1980 ms unchanged-pulse average is roughly 36 percent over the
  comparable 0.8778 ms baseline, beyond the unapproved 20-percent allowance.

These are structural failures. Enlarging, cropping, feathering, or adding more
detail to the monolithic plate cannot resolve them.

## Authorized next slice

The world-rendering lane keeps the active PLAY-022 claim. Before PLAY-023 or
bulk generation, it may implement one **systemic Gate A calibration spine**:

1. Synchronize the published integration contracts and keep the existing Gate A
   source as a non-shipping visual reference.
2. Build only the manifest-v4 and normalization/registration plumbing needed to
   ingest the calibration assets. A complete packer/cache migration remains
   PLAY-023 work after Gate A acceptance.
3. Commit exact transparent 2:1 registration templates for 1 x 1, 2 x 1, and
   2 x 2 parcels plus authoritative road sockets, ground pivots, height bands,
   northwest light, and southeast shadow bounds.
4. Use built-in ImageGen, one distinct call per source, to produce exactly this
   nine-source calibration set:
   - grass material;
   - road material;
   - residential frontage;
   - level-one residential, commercial, and industrial buildings;
   - park;
   - city hall;
   - water tower.
5. Reference the provisional Gate A source for appearance and the deterministic
   template for geometry. Retain every accepted raw source, complete prompt,
   reference hash, cleanup command, provenance record, and rejection reason.
6. Compile terrain boundaries, all required road connections, curbs,
   sidewalks, crossings, and frontage joins deterministically. ImageGen does
   not decide topology.
7. Compose the nine assets in the shipping `CityScene` as individual semantic
   objects. The monolithic plate must be disabled for the scored candidate and
   must never mask changed state, build mode, overlays, or hit testing.

This is a calibration prototype inside PLAY-022, not Batch 1 acceptance and not
permission to generate variants, higher levels, consequence states, ambient
families, or the remaining catalog. If an asset fails twice for the same
projection, scale, edge, or lighting drift, stop that family and repair the
template or prompt contract.

## Required Gate A-R proof

The exact staged candidate must provide:

- an internally and externally continuous road/curb/sidewalk network with no
  visible seams, overlaps, unexplained ends, or raised placemat boundary;
- developed land occupying 55--70 percent of the available world viewport at
  default and compact size;
- genuinely distinct city, neighborhood, and block LOD presentation with a
  stable ground pivot and no synchronized disappearance;
- uncropped same-seed baseline/candidate frames, exact candidate identity, a
  continuous pan/zoom recording, and a grayscale contact sheet;
- live normal, selected, valid and invalid placement, overlay, and Reduce
  Motion states;
- no resource fallback, stable hit testing and accessibility, full focused and
  native suites, exact staged verification, and comparable renderer timing no
  more than 20 percent above baseline unless integration explicitly approves a
  measured exception.

Integration and playtest quality independently score the same five categories.
Both must award at least 17/20 with no category below 3. Only then may
integration freeze the style anchor, accept Gate A, close this repair, and
authorize PLAY-023 followed by the remaining generated-v4 batches.

## Ownership

- The renderer lead is the only ingestion authority and owns the calibration
  candidate, source review, deterministic cleanup, semantic composition, tests,
  and exact staged proof.
- Generation cells may produce individual source attempts only in unique inbox
  paths. They never edit the shipping atlas, catalog, renderer, or manifest.
- Playtest quality remains read-only and independent until an exact candidate is
  submitted.
- Integration owns contracts, the 17/20 gate, performance exceptions, merge,
  publication, rollback, and authorization of every later batch.

No worker pushes, no generated calibration reaches `master` before acceptance,
and no CLI/API transparency fallback is authorized without explicit user
approval.
