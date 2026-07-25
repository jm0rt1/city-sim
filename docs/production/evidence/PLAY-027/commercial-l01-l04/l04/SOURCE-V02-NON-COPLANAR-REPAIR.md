# PLAY-027 Commercial L4 source-v02 non-coplanar repair

## Scope

This is a descriptor-only repair from the preserved `source-v01` rejection at
`27e5dc70fac189ac6a146247500801bc29276ca5`. No raw `source-v02` render may
begin until this boundary passes scene, identity, registration, and structural
boundary validation and is durably committed.

## Diagnosis

Commercial L4 `source-v01` retained complete visible N/E/S/W towers, but east
and south each produced two pixel identities across three fresh processes.
The divergence was localized to the new multi-tier tower stack. Several
structural volumes shared exact Y planes at the podium, transfer, upper crown,
lantern, mechanical screen, and rooftop-prop boundaries.

## Repair

The four independently authored L4 descriptors advance to `source-v02` and
unique `geometry-v2` IDs. The repair changes only vertical positions within
the already frozen architecture:

- mass tiers use small controlled interior overlaps instead of exact boundary
  contact;
- roof envelopes and cornice bands use distinct structural Y boundaries;
- the executive lantern and mechanical screen no longer share a boundary;
- chimney and HVAC bases use distinct embedded elevations rather than sharing
  the mechanical-penthouse top plane.

The repair does not change the 56 x 56 footprint, pivot, contact polygon,
directional frontage socket, door base, camera, projection, light, shadow,
materials, facade/window authorship, entrance hierarchy, or production
selection. Sibling mirroring, rotation, transformation, and aliasing remain
closed.

## Required gate before pixels

1. Four scene descriptors decode and pass the governed scene validator.
2. Four descriptor hashes and four scene geometry IDs are unique.
3. Cross-direction building envelopes remain exactly equal.
4. Directional socket and door-base registration remain exact.
5. The task-owned structural-boundary validator reports zero coincident
   structural Y planes in every direction.
6. Accepted Commercial L1-L3 owned files remain byte-identical to
   `71655d5dbaf8a56fa287e68b5b99159ee4ba6144`.

`productionSelected` remains `false`. Normalization, renderer ingestion, and
shipping/runtime mutation are not authorized by this repair.
