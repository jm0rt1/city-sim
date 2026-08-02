# PLAY-073 R4-C first technical return

**Disposition:** `RETURN`

**Exact candidate:** `51f6a4f52cc50d46c4884570b86d18ce1fbd0eb5`

**Product commit:** `5e8ea7e5168c6cf315d54f5463eb9a7dd9da2fa0`

**Evidence commit:** `51f6a4f52cc50d46c4884570b86d18ce1fbd0eb5`

**Exact candidate path hashes:**

- `LotContextRenderer.swift`:
  `725b4855b7d08aec0c709292a4fec68733a4a7a0659d16d6d4996471f8da9c51`
- `WorldRenderingTests.swift`:
  `1490eabf9d4abf1b3481e65d6391f02573dcd03a1a61cc36cc068ce009cced20`
- version-1 `RESULT.json`:
  `edd78f88d98992e7dec67d46f0e9f0079fb3d01977e553434381aa0a56016c64`
- version-1 `HANDOFF.md`:
  `d4a5e4446d1871723e465d6bfe08bf0e86e2496adec9308fb9677698790bf910`

**Frozen visual authority:**
`docs/production/evidence/INTEGRATION/PLAY-073-R4-C-ADJACENT-RESIDENTIAL-REPETITION-AUTHORITY.md`

**Classification for the final bounded repair:**
`LUNA_IMPLEMENTATION / gpt-5.6-luna / high`

## Preserved work

The candidate is clean, descendant-only, and changes exactly the two authorized
renderer/test files plus its two task-owned evidence files. Preserve both
commits and all accepted behavior: source sprite bytes and identity, authored
direction, frontage, tint, scale, pivot, registration, terrain, interaction,
deterministic variant selection, and the garden-grove versus terraced-court
semantic split.

The focused `WorldRenderingTests` result is retained as 71/71 passing. It is
useful implementation evidence, but it does not prove the frozen visible-scale
or combined-world collision requirements.

## Reproduced technical blockers

1. The variant-0 city `large-canopy` is only `7.2 * 0.72 = 5.184` render
   points wide and `4.8 * 0.72 = 3.456` points high. The companion canopy is
   only `3.456` by `2.016` points. These are tiny ground marks beside the
   approximately 80–100-point accepted residential building, not the frozen
   unmistakable large-plus-small tree silhouette.
2. The variant-1 city court spans only about `10.36` by `4.14` render points.
   It cannot materially open or differentiate the dominant building
   silhouette at city and neighborhood LOD.
3. The targeted test renders the two starter coordinates independently. Its
   evidence reports `adjacentContextCollision: false` without placing both
   lots at their actual isometric world positions in one container, so that
   claim is unproven.
4. All four variants and four frontages receive repeat-signature checks, but
   containment and entrance-clearance checks apply only to the exact starter
   pair. The result overstates all-variant/all-frontage geometry coverage.
5. Role presence is partly established from node names. The test does not bind
   the player-visible screen-space dimensions, raised canopy/trunk silhouette,
   combined pair separation, or material area required by the authority.
6. No deterministic technical color or grayscale comparison export was
   retained, despite the authority requiring both before handoff.

No full Swift suite, staged build, or subjective real-app gate is warranted
for this returned candidate. Those aggregate costs remain deferred until the
focused technical proof is materially credible.

## Frozen final repair

Create a descendant of exact clean candidate
`51f6a4f52cc50d46c4884570b86d18ce1fbd0eb5`; do not amend or rewrite either
preserved commit.

1. Make the garden-grove visibly material at city and neighborhood detail:
   - large canopy accumulated bounds at least `18 x 12` render points;
   - companion canopy accumulated bounds at least `10 x 8` render points;
   - combined canopy silhouette at least `28` points wide and `14` points high;
   - visible grounded trunks at least `6` points high, with canopy centers
     raised above their contact points rather than flattened into the ground;
   - the grove is asymmetrically offset to one side of the accepted building
     and remains inside its own lot/canopy envelope.
2. Make the terraced-court materially open and visible at city and
   neighborhood detail: warm-stone accumulated bounds at least `22 x 8`
   render points, plus visibly distinct hedge and planted-strip geometry, with
   no tree canopy.
3. Derive every anchor from the authoritative frontage socket. Keep every
   ground contact inside the 72-by-36 lot diamond, keep the entrance corridor
   clear, and do not overlap the adjacent building sprite or road envelope.
4. Place exact tiles `(6,10)` North/variant 0 and `(6,11)` South/variant 1 in
   one test container at their actual isometric world positions. Prove the
   context envelopes do not collide with each other, the sibling building
   contact envelope, or either road/frontage envelope.
5. Table-test all four residential variants by all four frontages for actual
   accumulated geometry, containment, entrance clearance, repeat identity,
   no labels/actions/hit targets, and deterministic non-aliasing. Do not use
   node-name inequality as visual proof.
6. Add one deterministic target-pair technical render test covering regular
   city, neighborhood, and block plus exact 900-by-600 compact neighborhood.
   Export a color contact sheet and a deterministic Rec.709 grayscale contact
   sheet into the version-2 evidence root. Bind exact hashes in the result.
7. Correct every evidence claim to the exact proof actually run. Preserve the
   version-1 packet as historical returned evidence.

## Exact mutable surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-073/r4-c-adjacent-repetition-v2/`

Everything else is read-only. In particular, do not edit any accepted source
sprite, `LotRenderer.swift`, `TerrainRenderer.swift`, `CityScene.swift`, asset
or manifest, package/build file, app/UI/gameplay/simulation/save surface,
claim, backlog, shared authority, or prior evidence.

## Gate and stop condition

Run the targeted technical export, the complete focused
`WorldRenderingTests`, JSON/hash validation, and candidate-range diff check.
Return one product repair commit followed by one evidence/handoff commit.

This is the second and final implementation attempt. Stop and escalate on any
failed repair, path expansion, shared-contract need, source-art need,
performance/resource regression, unresolved visual decision, or other
mandatory trigger. Do not run the aggregate full suite or staged app, score or
accept the result, merge, push, integrate, or pin.
