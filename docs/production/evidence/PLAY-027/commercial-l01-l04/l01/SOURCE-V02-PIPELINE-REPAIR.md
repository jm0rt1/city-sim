# PLAY-027 Commercial L1 source-v02 pipeline repair

**Scope:** Commercial L1 variant-zero N/E/S/W only

**Production selected:** no

## Diagnosis

The four source-v01 descriptors contain byte-identical building, camera, and
light definitions. Their complete building object hashes match, while only
the separately authored frontage, registration socket, and prop placement
differ. A fresh process could nevertheless present a complete or incomplete
raw for the same direction, and three directions failed canonical-pixel
repeat identity. The defect is therefore at the SceneKit snapshot/presentation
boundary, not in the fixed camera, footprint dimensions, or sibling-derived
geometry.

## Frozen exporter repair

Before preparing or retaining a frame, the task-owned offline exporter now:

1. flushes pending `SCNTransaction` work;
2. pauses the scene and fixes renderer time at zero;
3. synchronously prepares the complete scene graph;
4. renders and discards two fixed-time warm-up snapshots; and
5. retains only the third fixed-time snapshot.

The warm-up frames are never source-art authority. No sleep, runtime
dependency, camera change, transform, mirror, rotation, product package,
shipping surface, or shared manifest participates.

All four descriptors advance together to `source-v02`; their four unique
scene geometry IDs and direction-specific entrances remain independently
authored. The repaired renderer source SHA-256 is
`37760f29e9dbe21d82700e2fd2babeeacf2425f31b07f2f2fee381bf734b238b`.

## Hard validation

The repair is not sufficient unless fresh processes produce:

- byte-identical raw PNG files per direction;
- four unique N/E/S/W canonical pixel hashes;
- complete building, footprint plate, southeast shadow, and target frontage
  in every raw;
- normalized-alpha native-2x color and grayscale review panels with stable
  pivot/socket registration.

Failure in any direction rejects source-v02 and stops Commercial L1.
