# Industrial L1 source-v03 raw gate disposition

Disposition: **rejected before normalization**.

Renderer source commit: `31007343311f71fbb97e5371e7230f2af5bb1db0`.
All attempted outputs use the descriptor-bound schema-2 v3 sampling contract.

## Retained results

- north primary/B/C are byte-identical:
  `d73b3d2dff6a2e6ad605c9454c5d0c5313500f39c440204db22e0889e9c4857f`;
- east primary/B/C are byte-identical:
  `a050f3930037254047109f857c21cfc9c98602f54edd5ce3753fb80b05d83999`;
- south primary/B/C are byte-identical:
  `d316eb2728131ca564bed3e0aa8366b6f8c8dd995269b710e7f7fd78186d6fdf`;
- the three retained primary pixel identities are unique;
- exact decoded RGB and alpha-visible occupancy match for all three retained
  directions, with ratio `1.0` and zero hidden non-magenta pixels.

West failed during the first fresh process before the renderer wrote a PNG or
provenance record:

```text
raw occupied area cannot contain a complete building, footprint, and shadow:
pixels=60423, bounds=410x253, required=50000/400x260
```

The absence of a west source-v03 PNG and record is intentional evidence of
that hard gate, not missing inventory.

## Visual rejection

Direct alpha-respecting review of the exact retained raws and
`EXACT-RGBA-OCCUPIED-CROPS-PARTIAL.png` shows:

- east and south expose grounded loading-bay frontage;
- north still hides the centered far-edge dock house behind the high-bay mass,
  leaving the canopy/roof cue detached from a readable loading entrance;
- west cannot be reviewed because the complete-output gate rejected it;
- the template therefore does not yet provide complete, unmistakable N/E/S/W
  industrial frontage at actual scale.

No source-v03 pixel is normalized, selected, ingested, or treated as a review
candidate. The exact descriptors remain frozen at commit `3100734`; any later
repair must begin from this retained failure and must change the authored
far-frontage massing rather than relax the occupied-bounds validator.
