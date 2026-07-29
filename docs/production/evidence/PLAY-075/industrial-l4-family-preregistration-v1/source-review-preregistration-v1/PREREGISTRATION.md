# PLAY-075 Industrial L4 direction-local source-review preregistration v1

- **Disposition:** `PREREGISTERED_NO_SOURCE_REVIEW`
- **Lane:** `codex/citysim-playtest-quality`
- **Claim:** `PLAY-075`
- **Published authority:** `9950906e8dbbc3cf48a0dc5b05e9a7d38b7a76d8`
- **QA carrier after authority merge:**
  `b8683874a49cd23b52d08cedc4230255f203325e`
- **Source-stage schema:** `industrial-l04-source-stage-handoff-schema-v2.json`
- **Source-stage schema SHA-256:**
  `93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7`

This freezes one candidate-neutral, read-only rubric for future North, East,
South, and West Industrial L4 source review. No source candidate, author
assessment, live app, renderer candidate, or production resource was inspected
to set these rules.

Direction-local review may produce only:

- `QA_RECOMMEND_PASS_TO_INTEGRATION`;
- `QA_RECOMMEND_RETURN_TO_DIRECTION_CELL`; or
- `BLOCK_INPUT_IDENTITY`.

Those are recommendations, not source admission, renderer ingestion,
production acceptance, staged-app evidence, or a PLAY-075 score.

## Exact input boundary

Before literal-pixel inspection, the QA assembler must bind one exact committed
v2 packet:

1. schema version `2`, stage `source_candidate`;
2. `candidateReadyForIndependentReview: true`;
3. `sourceReady`, `integrationAdmitted`, `rendererQuarantined`, and
   `productionSelected` all `false`;
4. exact packet path, SHA-256, content commit, published baseline, direction,
   task, branch, logical ID, source key, and source-pixel frontage socket;
5. exact v2 schema path and SHA-256 above;
6. exact accepted bridge, appearance-lock, material-map, production-profile,
   non-alias, semantic-validator, and canonical-decoder authorities carried by
   the packet;
7. exact selected source, A/B/C process identities, three LOD identities,
   registration, D4 fingerprints, validation receipt, review manifest, and
   rejected-attempt inventory; and
8. zero fallback source key and orientation transform `none`.

The packet must be byte-identical at its declared content commit. A local-only,
mutable, v1, `launch_bound`, incomplete, stale, aliased, transformed,
production-selected, or direction-mismatched packet is `BLOCK_INPUT_IDENTITY`.

Integration owns the separate source-admission receipt. It is a required
review input: if it is not yet published, the slot remains
`BLOCK_INPUT_IDENTITY` and literal-pixel review does not begin. The receipt
must be byte-identical at a published Integration commit and must name the
same direction, packet path, packet SHA-256, content commit, selected-source
identity, and v2 schema identity. The worker packet itself remains immutable
with `integrationAdmitted: false`; QA never writes admission into the packet
or shared ledger.

## Fresh no-coaching review

The identity assembler verifies inputs before the visual reviewer begins. The
reviewer receives only:

- the declared runtime-cardinal direction and road/frontage context;
- untouched committed literal `192 x 128` color and literal grayscale;
- untouched committed native-2x color and grayscale;
- the packet-bound City/Neighborhood/Block LOD color and grayscale panels;
- registration/contact and alpha-silhouette panels; and
- an unlabelled same-scale exact accepted Industrial L3 comparison.

The reviewer does not inspect author disposition, self-assessment, prompt,
process ranking, validator thresholds, prior reviewer reasoning, sibling
recommendations, implementation, hidden coordinates, or annotated defect
coaching before sealing observations.

No image may be rerendered, resized, sharpened, recolored, cropped, annotated,
or substituted. Zoomed inspection may diagnose a defect only after the
untouched literal-scale first read is sealed; it cannot rescue a failed
actual-scale read.

## Review sequence

For exactly one direction:

1. seal the two-second unaided literal-color read;
2. seal the two-second unaided literal-grayscale read;
3. inspect native-2x color and grayscale for material/value cause;
4. inspect City, Neighborhood, and Block LOD survival;
5. inspect frontage/contact and alpha silhouette;
6. compare against exact accepted L3 at the same scale;
7. record every rubric gate as `supports_pass`, `supports_return`, or
   `blocked_input`; and
8. issue one recommendation with exact panel and packet hashes.

Reviewing a sibling direction is a new fresh review in its disjoint slot.
Sibling evidence may not coach or cure the current direction.

## Serialized production boundary

Direction-local recommendations never activate a partial family. The final
focused staged-app gate remains `BLOCKED_AWAITING_EXACT_4_OF_4_RENDERER`.
It may begin only when Integration supplies one exact renderer candidate that
contains all four exact source-admitted packet identities and satisfies the
existing atomic admission contract. No direction cell receives separate QA
production acceptance.
