# PLAY-027 canonicalizer v2 calibration disposition

Disposition: **FAIL — 12-process byte/pixel identity did not pass**.

The authorized schema-2-only canonicalizer implementation and eight unit tests
are frozen. Twelve fresh Residential L3 West processes were then run from the
same descriptor, materials, renderer source authority, camera, and sampling
contract with no CLI sampling override.

## Repeat outcome

Every process reports exactly 802 qualified RGB channel mutations:

```text
red:   128
green: 525
blue:  149
total: 802
```

The retained PNGs divide into two exact identities:

```text
10 runs: 23f9a952eaa5650babeb2efea11b4f66215dc31162bc305a45ec719da392b2e7
 2 runs: 52011ce067bad07dcca911dbf40cef6b2f9c8c843c8f136859027e21d8f02830
```

The identities differ at one decoded RGBA pixel:

```text
source coordinate: x=732, y=778
majority RGBA:     [16,48,16,255]
minority RGBA:     [16,16,16,255]
differing channel: green
alpha difference:  none
```

The original v1 split at `(733,778)` is no longer the retained difference.
The residual is the adjacent foliage pixel. The exact authorized rule does not
converge that pixel in every process, and the integration authorization permits
no broader threshold, second canonicalizer, median, coarsening, chroma-edge
repair, or geometry change.

## Invariants that still pass

The majority and minority outputs both retain:

- identical RGB and alpha-visible occupied bounds `[619,569,1029,906]`;
- alpha visibility ratio 1.0;
- zero hidden non-magenta pixels;
- flat opaque chroma corners;
- unchanged complete building, footprint, shadow, and registration occupancy.

These invariants do not waive the failed byte/pixel identity gate.

## Stop boundary

No Residential L4 diagnostic render, normalization, full regression restart,
review-candidate panel set, Commercial L4 source-v03, production selection, or
shipping/runtime mutation followed this failure. A further algorithm change
requires new integration authority because the one authorized canonicalizer
revision has been implemented exactly and did not make the raw gate
deterministic.

Binding evidence:

- `run-01.json` through `run-12.json` and matching PNGs;
- `RESIDUAL-PIXEL-SPLIT.json`;
- `RESIDUAL-PIXEL-SPLIT-ZOOM.png`;
- `EXACT-RGBA-VISIBILITY.json`;
- `EXACT-RGBA-OCCUPIED-CROPS.png`.

`productionSelected` remains false.
