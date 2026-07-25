# PLAY-027 Industrial L1 source-v05 far-edge representation repair

## Authorized representation change

Source-v05 implements the one repair authorized after the retained source-v04
failure at `16181e2`. The fixed 45-degree/30-degree 2:1 isometric camera,
directional frontage sockets, footprint, pivot, contact, northwest light,
southeast shadow, schema-2 v3 sampler, and accepted Residential/Commercial
bytes remain frozen.

The far-edge target is no longer an exposed door plane. North and West retain
their independently authored split high-bay halls as a recessed loading
throat. Every direction now independently declares:

- two grounded steel gantry posts connected to its road-facing dock house;
- a concrete gantry header and yellow hazard crown rising above the roof
  silhouette;
- a concrete service apron that crosses the exact named frontage socket;
- a yellow apron stripe beyond that socket;
- a centered loading canopy and door geometry with no sibling transform.

The gantry crown reaches a common 59.8-world-unit vertical envelope in all
four directions. This is authored industrial mass, not canvas padding,
footprint-plate manipulation, scale adjustment, camera rotation, or validator
relaxation. The West raw gate remains exactly 50,000 occupied pixels and
400-by-260 occupied bounds.

## Pre-pixel gate

- four unique descriptor hashes and four unique geometry IDs;
- independently authored N/E/S/W scene records with no mirror, rotation,
  sibling source, or orientation transform;
- exact N/E/S/W entrance bases at `[0,2,-28]`, `[28,2,0]`, `[0,2,28]`, and
  `[-28,2,0]`;
- two grounded gantry posts, one header, one hazard crown, one socket-crossing
  apron, and one apron stripe per direction;
- zero coincident structural boundaries;
- `productionSelected:false`.

The next gate is one fresh raw process per direction only. Repeat rendering and
normalization remain forbidden until integration reviews the literal exact-byte
four-view occupied crop. Any single-render failure freezes Industrial L1 with
no source-v06.
