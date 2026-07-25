# PLAY-027 third calibration redesign plan

**Authority:** independent rejection recorded at
`920cb1315c7a32027e20d0fcf2a670f70c4fed89`

**Prior candidate:** `fda4a15ead47b37f3610e4b3d7f07bb7ff102d8a`

**Scope:** residential L1 variant-zero N/E/S/W only

**Production selected:** no

## Frozen input changes

- North and west replace rooftop-tower dependence with 22-world-unit covered
  porches, six-step approaches, outer columns, and side rails that extend
  beyond the occluding mass at the declared frontage socket. Their entry
  pavilions are lowered into the wall/roof envelope.
- East and south retain their independently authored passing frontage
  topology, with larger doors, broader porches, and stronger trim separation.
- Every direction adds one explicit grounded domestic bay-window projection.
  Window openings and first-floor planting boxes are enlarged.
- The wall palette is warmer and lighter, masonry relief is less contrasty,
  and the main roof becomes a lower charcoal hip roof rather than the
  oversized pale custom-plane roof.
- The renderer preserves native oversampled object coverage when applying the
  required flat `#ff00ff` field. The existing normalizer remains unmodified
  and exclusively owns final transparent-alpha output and edge despill.
- The normalized validator now rejects visible magenta-dominant pixels.
- Native-2x, grayscale, footprint, and zoom review sheets consume the existing
  deterministic normalized-alpha block outputs, never the raw chroma preview.

## Frozen revisions

| Direction | Scene geometry | Planned raw revision |
|---|---|---|
| north | `residential-l01-v0-north-geometry-v6` | `source-v11` |
| east | `residential-l01-v0-east-geometry-v4` | `source-v07` |
| south | `residential-l01-v0-south-geometry-v4` | `source-v07` |
| west | `residential-l01-v0-west-geometry-v6` | `source-v08` |

The four descriptors validate with unique descriptor hashes and geometry IDs.
Camera, pivot, footprint, contact, socket, light, shadow, and orientation
contracts remain frozen. No sibling is mirrored, rotated, or transformed.

North `source-v05` proved that depth alone did not defeat far-edge occlusion.
It is preserved and rejected in `ATTEMPT-REJECTIONS.md`; the revised north and
west descriptors independently declare grounded lateral porch returns.

The first complete raw pass proved that SceneKit could alternate one shaded
sample by an 8-value color interval across separate native processes. The
task-owned compositor now canonicalizes each 32-value RGB bucket to its
midpoint after compositing. This absorbs the observed bounded drift while
retaining eight stable levels per channel. All four final revisions advance
because the canonicalizer is a shared source-rendering input.

The first 32-bucket probe still exposed two PBR states in twelve south chimney
pixels, including samples that crossed bucket boundaries. The source material
model therefore advances from stochastic SceneKit PBR to deterministic
Lambert illumination. Lambert preserves the descriptor-owned northwest key
and ambient hierarchy while removing runtime-oriented roughness sampling from
the offline authoring result. All four revisions advance together again.

Rendering must not begin until this redesign input is committed. The resulting
pixels remain review candidates only and cannot authorize the remaining 44
sources, renderer ingestion, or production selection.
