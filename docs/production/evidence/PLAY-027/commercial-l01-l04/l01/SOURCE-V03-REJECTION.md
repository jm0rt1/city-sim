# PLAY-027 Commercial L1 source-v03 rejection

**Disposition:** deterministic but visually rejected before normalization

**Production selected:** no

The non-coplanar corner-pier repair removed the two-state native depth result.
Three fresh processes produced byte-identical raw PNG files in every direction,
and the four retained N/E/S/W canonical pixel hashes are unique.

Integration's exact-raw inspection nevertheless found a binding visual failure:
north and south present complete buildings, while east and west present only a
thin facade/roof slice in the review decoder, without a reliably visible full
volume, footprint plate, or southeast shadow. Byte stability cannot waive
source completeness.

All run-A/B/C raw files, render records, scene validation, repeat reports, and
four-view uniqueness evidence are retained. No source-v03 image is normalized,
selected, ingested, packaged, or shipped.

The next exporter revision must:

- record and validate complete rendered-node world bounds before snapshot;
- emit review-decoder-safe native PNG bytes deterministically;
- enforce minimum non-chroma occupied area and bounds invariants;
- prove full volume, footprint plate, shadow, and target frontage visually for
  all four directions before normalization.
