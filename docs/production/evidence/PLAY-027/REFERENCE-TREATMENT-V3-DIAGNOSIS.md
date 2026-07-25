# PLAY-027 reference treatment v3 diagnosis

**Date:** July 24, 2026

**Disposition:** deterministic reference repair validated; one north v03 probe
may follow only after this checkpoint is committed

## Diagnosed v2 bias

The v2 reference treatment did not merely leave the named frontage
underspecified. It actively privileged the near screen-facing edge in two
ways:

1. The template generator painted faces in fixed north, west, east, south
   order. East and south faces were therefore painted last and visually
   dominated the volume regardless of the named target edge.
2. The accepted residential family anchor showed a complete building with a
   prominent entrance on its near facade. Although the prompt denied that
   image camera authority, its full composition remained a stronger visual
   cue than the small v2 edge/socket marks.

This explains the north source-v02 result: the model corrected the gross
projection but retained the near-facade entrance prior.

## Deterministic v3 repair

The task-owned v3 generator changes the visual inputs, not the adjectives:

- the named target face is painted last as one dominant green plane;
- its doorway base is centered exactly on the declared frontage socket;
- the other three faces are subordinate and contain no entrance mark;
- the complete accepted residential anchor is no longer a reference image;
- five fixed crops from that accepted anchor are assembled into a
  material-and-scale board with no camera, composition, footprint, or
  registration authority;
- no rejected source pixels are used.

The four direction templates retain the same 1536 x 1024 canvas, 1 x 1
footprint polygon, 768 x 896 pivot, and `orientationTransform: none`. They are
non-shipping ImageGen inputs only.

## Validation

`validate_reference_treatment.py` recomputes every declared PNG and source
anchor SHA-256, requires four unique direction hashes, and checks:

- exact canvas, footprint polygon, and pivot;
- exact edge-midpoint frontage socket;
- exact door-base midpoint registration;
- flat `#ff00ff` canvas corners;
- a target-green pixel on the declared frontage edge;
- absence of rejected references and shipping selection.

The retained report passes with zero failures and four unique template hashes:

| Direction | Template SHA-256 | Socket |
|---|---|---|
| north | `1f673ba686e11e06d1f41de55f779ef477bc0d45ae0cf25344a6af823570872e` | `(896,704)` |
| east | `d5a9da59c1ded82981908565fe3bee59339e35225b0e87b7918db61853f222fb` | `(896,832)` |
| south | `ce9058ca529c5f188a7dabaa3f35975e756ecc77ed2742468892e820abbb1c21` | `(640,832)` |
| west | `a218e79ea87608c0cc3a983bbbad833996695bbc48aa6035235487d3b0511a49` | `(640,704)` |

The manifest hash is
`2f56d758acf4ff0337c20502c117bc84dd5ff8e6c12fb9d267d43aa46b89d4ce`.
The material-and-scale board hash is
`850d91d071dc7ce490c1af99d20d697158d2eaf33492609999dc633ad21b8437`.
A second generator/validator run reproduced these hashes exactly.

## Probe boundary

The frozen v3 inputs authorize exactly one independently reviewed built-in
ImageGen call for
`residential_l01/variant-0/north/source-v03`. No east, south, or west sibling
call is authorized from the repair alone.

If that attempt does not place its only primary entrance on the north
template plane and socket, the built-in model has failed the authored socket
after both an edge-mark repair and a target-face-dominant repair. PLAY-027 must
then preserve the attempt, checkpoint the exact capability limit, and propose
a separately authored, contract-compliant alternate pipeline for integration
approval. Prompt iteration is not authorized.
