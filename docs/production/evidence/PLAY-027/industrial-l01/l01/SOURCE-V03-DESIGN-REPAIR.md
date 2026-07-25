# PLAY-027 Industrial L1 source-v03 design repair

## Frozen cause and boundary

Industrial L1 source-v01 and source-v02 are retained as rejected evidence.
Source-v01 proved deterministic rendering but hid the north and west road
frontages. Source-v02 attempted renderer-created corner returns; north remained
visually weak, west failed the raw occupied-bounds gate, and east/south exposed
one-quantum depth/material winner splits. After those two directional failures,
the family geometry template was frozen and redesigned instead of prompting or
iterating the same return treatment.

This revision changes only task-owned offline source inputs and renderer
vocabulary. It does not normalize, select, ingest, or mutate accepted
Residential or Commercial sources.

## Source-v03 authored geometry

Each direction now owns an explicit scene-authored setback high-bay hall and a
grounded brick dock house on its named road-facing edge:

- north: main hall set toward positive Z; dock house grounded on negative Z;
- east: main hall set toward negative X; dock house grounded on positive X;
- south: main hall set toward negative Z; dock house grounded on positive Z;
- west: main hall set toward positive X; dock house grounded on negative X.

The dock house carries its own parapet roof, hazard header, target-face
clerestory rhythm, loading doors, personnel door, canopy, and dock apron. The
main hall retains the industrial family anchor through corrugated sage metal,
three sawtooth-like hip roof bays, concrete datum, HVAC, exhaust stack, and
service tank. The four descriptors use unique geometry IDs and independently
specified mass, roof, trim, chimney, entrance, and facade records; no sibling
transform, raster rotation, or mirror is used.

Source-v03 suppresses only the rejected renderer-created corner-return helper.
The source-v01/source-v02 path remains available for exact evidence
reproduction.

## Contract invariants

- outer 56-by-56 footprint envelope, pivot, frontage socket, target edge,
  projection, camera, northwest light, southeast shadow, and source canvas are
  unchanged;
- schema-2 v3 deterministic sampling remains descriptor-bound;
- `productionSelected` remains `false`;
- all four descriptor hashes and geometry IDs are unique;
- the structural-boundary validator reports zero coincident overlapping
  boundaries in all four directions;
- no accepted Residential or Commercial descriptor, raw, normalized,
  provenance, or review byte is changed.

The next gate is exactly three fresh native render processes per direction.
Normalization is forbidden until the retained PNGs are repeat-identical,
RGBA-visible, complete, and visually show their named loading frontage.
