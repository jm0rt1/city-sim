# Industrial L1 source-v04 raw gate disposition

Disposition: **rejected; Industrial L1 frozen for integration disposition**.

Renderer source commit: `675c605c87d8925e0bc617d3c32923dd1b2640e7`.
All attempted outputs use the descriptor-bound schema-2 v3 sampling contract.

## Retained deterministic results

- north primary/B/C are byte-identical:
  `452bc6879f56ae8f84fb5c4b893ce93c435e9c1ce8457eb051054e8cc172e28e`;
- east primary/B/C are byte-identical:
  `21f09801e8f47fa8970bea8a4be1d2ca1bcf6b12caec55645bcddaa6c7f04dc6`;
- south primary/B/C are byte-identical:
  `b9e45df2c9ff4fd4342f0809047d97641a01c7a0bf41ea643b4cd2285ae382e9`;
- the three retained primary pixel identities are unique;
- decoded RGB and alpha-visible occupancy match, with ratio `1.0` and zero
  hidden non-magenta pixels.

West again failed during the first fresh process before a PNG or provenance
record was written:

```text
raw occupied area cannot contain a complete building, footprint, and shadow:
pixels=60579, bounds=410x253, required=50000/400x260
```

The absence of a west source-v04 PNG and record is the exact hard-gate outcome.
The validator floor was not relaxed.

## Direct visual finding

`EXACT-RGBA-OCCUPIED-CROPS-PARTIAL.png` proves that the split-hall geometry
changed the north silhouette, but the centered road-facing loading door still
does not read through the far-edge sightline. East and south remain complete
and readable. West remains unavailable for direct review because it does not
clear the complete-output invariant.

The bounded source-v04 probe therefore fails both four-direction completeness
and far-frontage readability. Per `SOURCE-V04-DESIGN-REPAIR.md`, no source-v05
is authored and no source-v04 pixel is normalized, selected, ingested, or
presented as a candidate. Further work requires integration direction on the
far-edge scene/camera/frontage representation rather than another local prompt
or geometry iteration.
