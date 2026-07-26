# PLAY-027 Industrial L3 East cohesion disposition

- Exact worker candidate:
  `232e37476d32e81b4fbd08b3d548895e78d9ea4a`
- Integration disposition: `ACCEPT_TREATMENT_FOR_SIBLING_AUTHORING`
- Source authority: `false`
- Family authority: `false`
- Production selected: `false`
- Siblings authorized: North, South, and West only
- Renderer or shipping mutation: none

Independent review compared the exact source-v02 and source-v04 East raw,
block, neighborhood, city, compact, native-2x, frontage, color, grayscale, and
staged-catalog panels.

The candidate passes the A0 calibration because:

1. camera, geometry, footprint, pivot, frontage socket, contact, shadow, and
   occupied bounds are unchanged;
2. nineteen material roles use new authored patterns, physical scales, surface
   response, warm/dark value hierarchy, and structural-edge treatment rather
   than a post-process tint or recolor-only alias;
3. raw luma IQR increases from 37 to 57 while seven occupied luma bins remain;
4. saturated safety-accent share remains 3.0–3.4 percent, below the 10-percent
   Wave 011 ceiling;
5. frontage grayscale contrast is 96 points against a 15-point minimum;
6. block, neighborhood, and city outputs are file- and pixel-identical across
   two normalization runs; and
7. compact color/grayscale proof retains a darker industrial silhouette,
   legible frontage, warm concrete/oxide accents, and stronger fit beside the
   accepted warm/dark staged catalog.

The exact branch-bound packet is under
`docs/production/evidence/PLAY-027/industrial-l03/l03/cohesion-a0-east-v01/`
at the candidate above.

North, South, and West must preserve their accepted directional geometry and
registration while applying the accepted material-role system through their
own authored scene descriptors. Each direction still requires raw safety,
two-run normalization identity, compact/color/grayscale/frontage proof, and
the final four-direction cross-family review. Do not claim source/family
authority, ingest the renderer, or select production before that review.
