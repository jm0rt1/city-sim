# PLAY-027 Industrial L2 quality-reset art-direction audit

Status: pre-pixel audit; no source-authority render; `productionSelected: false`.

## Evidence reviewed

- Accepted Industrial L1 source-v05 N/E/S/W scenes and normalized-alpha review
  sheets at candidate `79668c347e58d602f9627c73cb09e3272a83ef57`.
- Rejected Industrial L2 source-v03 through source-v08 descriptors, raw
  attempts, repeat diagnostics, and frozen review sheets.
- Literal native-2x color and grayscale sheets for accepted Industrial L1 and
  rejected Industrial L2 source-v05.
- Accepted Residential L1-L4 and Commercial L1-L4 family sheets as the
  cross-family non-alias baseline.

## Binding quality findings

1. Industrial L1 and the rejected L2 vocabulary is dominated by rectangular
   mass blocks, thin trim bands, pyramidal roof caps, and oversized gantries.
   The authored node count is technically non-trivial, but most parts merge
   into a few coarse cuboids at native scale.
2. The accepted L1 dark palette has broad luma range but a compressed dominant
   midtone. Its own retained evidence records block-LOD interquartile spreads
   as low as six luma values. L2 must create value hierarchy through surface
   and depth structure, not merely more saturated trim.
3. Loading frontage is signaled mainly by a high hazard header. Human-scale
   dock doors, seals, bumpers, stairs, canopies, bollards, and apron joints are
   too shallow or sparse to carry the industrial reading without the header.
4. Roofs read as large plain slabs with isolated boxes. Membrane seams,
   parapet coping, drainage, screened HVAC, vents, pipes, and process equipment
   do not form a believable service system.
5. Accepted L1 and rejected L2 share nearly the same squat central-block
   silhouette. The L2 height increase does not yet tell a convincing story of
   greater throughput, administration, production capacity, or logistics.
6. The literal source-v05 native-2x sheet exposes magenta/chroma presentation
   and flat constant-material color as technical diagnostics, not production
   art. Deterministic identity work did not address material realism.

## Reset target

Industrial L2 becomes a medium logistics/manufacturing campus within the same
72 x 72 world footprint:

- a two-storey administration bar establishes human scale;
- a taller clear-span production hall establishes industrial capacity;
- a stepped process bay and screened plant deck create a recognizable L2
  skyline;
- three recessed loading positions, dock seals, bumpers, a deep canopy,
  apron scoring, bollards, stairs, and guardrails make frontage readable
  without an oversized sign;
- cast concrete plinth and administration walls, blue-gray painted steel,
  galvanized corrugated production cladding, dark membrane roofs, muted
  glazing, and restrained safety yellow form a realistic material hierarchy;
- gutters, downpipes, roof drains, HVAC, exhaust, tanks, pipes, foundations,
  service doors, and weathering are grouped into native-scale clusters rather
  than scattered tiny greebles.

## Non-alias tests declared before pixels

- L2 must exceed L1 in stepped volume count, occupied vertical envelope,
  loading-bay count, roof-service grouping, and visible administration
  frontage.
- L2 must remain lower and more horizontally operational than Commercial L3-L4
  and must not adopt storefront glazing, retail awnings, residential roofs,
  balconies, porches, or domestic window rhythm.
- Each direction must be recognizable without labels by the socket-aligned
  dock/apron system and a unique skyline/service grouping.
- At native-2x, the minimum authored feature is 2.0 world units except for
  grouped rail, seam, mullion, and pipe strokes whose combined cluster is at
  least 6.0 world units.

## Frozen boundaries

The source-v03 through source-v08 Industrial L2 trails remain rejected and
byte-immutable. The accepted Industrial L1, Residential, and Commercial
sources remain byte-immutable. This reset produces only non-authority design
descriptors, diagnostic mockups, material studies, validation, and a later
raw-gate plan.
