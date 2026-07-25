# PLAY-027 Industrial L2 quality-collapse audit

Status: **proposal-only audit; no render or mutation authority**

This audit explains why the independently approved pre-pixel architecture
collapses into a low-detail, toy-like source raster. It does not reopen the
North-C determinism failure and does not recommend canonicalization, tuple
mapping, rerendering, or source-v11 work against the current pixels.

## Quantitative evidence

The source contract allocates a 512-pixel-wide source diamond, but the exact
retained alpha-visible bounds are only 410 pixels wide in every direction:

| View | Exact occupied bounds | Width × height | Occupied pixels | Source-diamond width use |
|---|---|---:|---:|---:|
| N | `[619,638)–[1029,906)` | 410 × 268 | 60,305 | 80.1% |
| E | `[619,578)–[1029,906)` | 410 × 328 | 63,556 | 80.1% |
| S | `[619,642)–[1029,906)` | 410 × 264 | 59,500 | 80.1% |
| W | `[619,626)–[1029,906)` | 410 × 280 | 63,279 | 80.1% |

At the frozen `0.28125` native-2x review scale, that entire occupied width is
about 115 pixels before separating the building from the footprint plate.
The building itself receives only part of that budget.

The authored descriptors contain many components, but roughly half have at
least one dimension at or below 1.2 world units:

| View | Counted mass/roof/trim/prop components | Minimum dimension ≤1.2 | Minimum dimension ≤2.0 | Facade window bays/rhythms |
|---|---:|---:|---:|---:|
| N | 44 | 21 | 27 | 0 / 0 |
| E | 42 | 21 | 25 | 0 / 0 |
| S | 40 | 20 | 24 | 0 / 0 |
| W | 45 | 21 | 27 | 0 / 0 |

Those thin rails, drains, seams, pipes, trim strips, and bollards commonly
arrive at native scale near or below a few pixels. They cannot carry the
facility's identity after 4x rendering, Lanczos reduction, step-32
quantization, and native-2x review reduction.

The final raw value ladder is also compressed:

| View | Luma p05 | p25 | p50 | p75 | p95 | p75−p25 | p95−p05 |
|---|---:|---:|---:|---:|---:|---:|---:|
| N | 46 | 48 | 71 | 80 | 84 | 32 | 38 |
| E | 43 | 48 | 71 | 80 | 84 | 32 | 41 |
| S | 48 | 48 | 71 | 80 | 84 | 32 | 36 |
| W | 46 | 48 | 71 | 80 | 84 | 32 | 38 |

Seventeen named material roles therefore resolve into a narrow, dark final
range. The material library is semantically richer than the raster result.

## Root causes

1. **Camera/envelope utilization is too conservative.** The fixed
   orthographic framing preserves registration but uses only 80.1% of the
   contracted source-diamond width. The dominant footprint plate consumes
   much of the remaining native panel while the actual facility reads small.

2. **The descriptor spends detail below the pixel budget.** Twenty or more
   components per view have a minimum dimension no larger than 1.2 world
   units. The pre-pixel clay/material mockups can show them, but the governed
   reduction chain cannot preserve them as meaningful staff-scale cues.

3. **Material and lighting separation collapses.** The Lambert/current-light
   result plus frozen quantizer compresses most visible building values into
   the 48–80 range. Concrete, steel, recess, roof, trim, glazing, and loading
   roles become adjacent dark blocks rather than a readable hierarchy.

4. **Frontage grammar is not carried by large forms.** East and South retain
   dock hints, but at native scale they are shallow and low contrast. North
   and West far-edge loading infrastructure reads primarily as a small bright
   roofline bar rather than a grounded logistics throat. Facade window
   bays/rhythms are empty, so no larger repeated human-scale rhythm supports
   the entrances.

5. **Alpha is technically correct but presentation is not.** Exact retained
   PNG review has alpha-visibility ratio 1.0, matching RGB/alpha bounds, and
   zero hidden non-magenta pixels. The dominant magenta plate is therefore
   not hidden-RGB corruption; it is an authored/composited presentation
   result that overwhelms the dark building in literal and alpha-masked
   review sheets.

6. **The pre-pixel gate measured authored complexity, not raster survival.**
   Unique descriptors, component counts, sockets, and geometry contracts
   passed, but there was no binding per-component source/native-2x survival
   budget before the expensive repeat gate.

## Proposal for any future authorized slice

Do not begin with repeatability. First freeze a single-process,
non-source-authority presentation proof that keeps the exact pivot, sockets,
2:1 projection, camera direction, and contact shadow while proving:

- materially higher source-diamond utilization without clipping or
  registration drift;
- a silhouette in which administration, production hall, process tower, and
  loading throat are distinguishable as large forms;
- dock canopies, doors, personnel entrance, rails, and bollards sized to
  survive at native-2x rather than represented by subpixel greebles;
- a broader deliberate grayscale ladder after the actual step-32 quantizer;
- frontages carried by recess depth, canopy mass, apron connection, and
  repeated large-scale rhythm, especially on North and West;
- a neutral, alpha-respecting review presentation in which the authored
  contact shadow remains legible but the saturated magenta plate does not
  dominate;
- component-to-pixel survival metrics and literal source/native-2x
  color/grayscale sheets before any multi-process identity gate.

Only an independently approved art proof should earn another governed
repeatability run.
