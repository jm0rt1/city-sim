# PLAY-073 Claim

- **Title:** Replace the board with an authored district
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base authority:** Published Wave 008 product candidate
  `87e1e682566b68d20deb1a9e2028e2b885e0423a`; iteration-two branch authority
  is the clean rejected-evidence checkpoint
  `b11391891d412c40741c8466c3e4bd5d6026ab1c`, whose product ancestor
  `1c590e446e718024f4848d22b33b05db4c73555a` is integrated on local
  integration candidate `fbbff0c7a633be81ae7779709a76ff3202d928fb`
- **Planned surfaces:** renderer-owned camera composition, terrain/public-realm/parcel/place/activity rendering, deterministic variation and collision tooling, renderer tests/diagnostics, staged proof, and `docs/production/evidence/PLAY-073/`
- **Dependencies:** accepted PLAY-024/062/065/066 product; PLAY-072 fixtures when available; separately accepted PLAY-027 art only
- **Validation/proof:** same-state regular/compact early/pressure/recovery/upgraded/terminal comparisons at all LODs; developed-district occupancy; light/shadow/material/value/outline coherence; repetition ledger; zero seams/overlaps/fallback; pointer/keyboard/AX/Reduce Motion; pack parity; residency/RSS/frame budgets; PLAY-075
- **Status:** returned after integration's real-app visual rejection; focused
  iteration two is preserved cleanly through
  `bfcd46cc361f04f38c35c7c463b8a42dfb000351`, with its accepted integration
  repair published through `4e5d79f43c8213e86d58a9cfe0c0bc1f98c8b3c1`.
  The task remains open because the production opening is still visibly sparse.
  Wave 010 R1 Industrial L2 is accepted at exact renderer product
  `d41c2c68d5584c990e271af06c0b93ab50722f5e` with focused PLAY-075 approval
  `74f2164da506a246af9335cab2d3a9e977624097`. Further composition mutation
  remains paused. Exact R2 candidate
  `b4191d98ee7c526bc08a6fe272521588572e27fd` is clean and preserved and passed
  the 271-test integration gate, but integration returned it before publication
  because the L3 material/value/outline language fails the mixed-fidelity stop.
  The lane now preserves replacement R2 plus its candidate-bound external
  fixture intake. Integration's exact audit confirms that replacement R2 was
  blocked by an incomplete independent journey, not visually rejected, and
  authorizes one current-master reconstruction and technical proof under
  `INDUSTRIAL-L03-R2-REPLACEMENT-RECOVERY-AUTHORITY.md`. Renderer may prepare
  one new exact candidate; PLAY-075 remains the sole player-facing scorer.
  Industrial L4 non-shipping direction-quarantine preparation is separately
  active under
  `INDUSTRIAL-L04-RENDERER-QUARANTINE-PREP-AUTHORITY.md`.
  File-backed packet-intake and baseline-neutral semantic-slot preparation are
  additionally active under
  `INDUSTRIAL-L04-ARRIVAL-GATE-PREP-AUTHORITY.md`; this remains test/evidence
  only and cannot ingest or activate actual source art. The canonical
  admission-receipt harness is integrated through
  `b72272e1a41b272c9ba549f05760a72f8ed92fd8`. Industrial L4 shipping
  ingestion is now explicitly deferred while its source cells continue, and
  Renderer was released for the bounded authored-opening R4-A slice under
  `PLAY-073-R4-A-AUTHORITY.md`. Exact R4-A candidate
  `0e89914566ba4593b25e2cd52b4b788d204b7331` is preserved but returned by
  independent PLAY-075 at clean evidence commit
  `35ff256581d8f5f14c74309f52ee0853658c937a`: it scored 18/20 and failed the
  broad-green-terrain and adjacent-building-repetition automatic returns. Its
  product was explicitly rolled back on Integration master while the QA packet
  remains durable. Renderer is now released for the bounded R4-B return repair
  under `PLAY-073-R4-B-RETURN-REPAIR-AUTHORITY.md`.

Recompose the visible world as one authored district. The developed city must
dominate the intended camera while retaining useful buildable context. Roads,
curbs, sidewalks, parcels, entrances, parks, service yards, terrain,
vegetation, props, activity, and buildings must share one coherent visual
language and ground plane.

Do not invent simulation facts, ingest unaccepted PLAY-027 art, mirror/rotate
or alias buildings, hide interaction, change gameplay/UI/persistence rules, or
trade compact/LOD quality for one hero frame. Stop on mixed fidelity, obvious
adjacent repetition, broken seams, floating/detached places, fallback,
collision, or resource regression. Do not push, integrate, self-score,
self-accept, or pin.

## Iteration-two return authority

The first returned product is technically admissible but visually rejected.
Integration operated exact staged master `fbbff0c` at the default Day 11
opening and exact compact size. The developed district occupied only
`0.3689999848900444` of regular safe width and `0.5100866307358453` of compact
safe width. A seven-building crossroads remained surrounded by the largest
visual mass: repetitive undifferentiated green. Roads still read as isolated
black strips, while building, park, utility, outline, material, shadow, and
ground-contact fidelity remained mixed.

Iteration two must correct that exact production opening systemically:

- the connected authored district and public-realm envelope occupies at least
  `0.60` of safe map width at both regular and compact sizes;
- useful expansion context remains visible, including at least one complete
  buildable parcel band beyond the developed edge, so the result is not a
  crop-only improvement;
- no single plain-grass region is the largest authored visual mass or exceeds
  `0.25` of the safe map aperture;
- every occupied place has continuous road, curb, sidewalk or service-edge,
  entrance/frontage, parcel-ground, and contact-shadow geometry;
- roads no longer read as isolated black strips at any governed LOD;
- the same early, pressured, recovered, upgraded, and terminal states prove
  one coherent value, outline, material, light, shadow, and ground-contact
  language in color and grayscale;
- city, neighborhood, and block LODs remain materially composed at regular
  and compact sizes, with zero fallback, overlap, clipped interaction,
  adjacent aliasing, or invented simulation truth; and
- pointer and keyboard targeting, placement preview, invalid placement,
  overlays, selection, Focus City, Reduce Motion, AX, frame time, node/draw
  count, RSS, residency, and deterministic two-build identity remain exact.

Start with an exact candidate-bound audit of the default Day 11 opening, not a
fixture-only hero state. Preserve the first iteration and its rejection packet.
Commit a corrected renderer product before evidence, then retain real staged
regular/compact default-opening proof plus the full authoritative state/LOD
matrix. Return the slice if any automatic reject remains; do not describe
technical green as visual acceptance.

## Wave 010 art-first ingestion authority

Follow `docs/production/WAVE-010-ART-FIRST-RELEASE-SPRINT.md`. Preserve exact
R1 product `d41c2c68` until synchronized to the next published baseline. Do not
begin a second composition iteration while World Art authors Industrial L3.
Use the R2 window to ingest only exact independently approved PLAY-027 source
candidate `5e019c3e7b7992cabeae179641a0f6748a971666`. Source repair remains World
Art-owned.

For R2, run focused pack/runtime/frontage/LOD/resource checks and one staged
candidate build. Integration owns the single full-suite and staged-identity
gate; PLAY-075 owns the single focused independent real-app disposition.
The replacement-recovery authority supersedes the earlier instruction to
ingest only the historical source candidate: reconstruct only the exact
accepted-L2-to-cohesive-replacement net delta on its enumerated paths, with new
candidate-bound proof. Do not cherry-pick the historical product carrier.
Industrial L4 source ingestion, runtime/shipping activation, unaccepted source
work, gameplay changes, UI repair, and broad composition mutation are not
authorized by this claim. The Integration-published L4 quarantine-preparation
addendum authorizes only its explicit test/evidence-owned non-shipping packet
schema, validator, mutation matrix, and handoff.

The arrival-gate addendum additionally authorizes a caller-path file-backed
packet harness and a baseline-neutral repair of the preserved semantic-slot
fixture. Neither change may adopt R2 product state, accept a real L4 source, or
mutate runtime/shipping resources.

After the accepted Industrial batches publish or are explicitly deferred, R4
is governed by `docs/production/WAVE-010-R4-COHESION-CLOSEOUT.md`. Its
rendered-pixel composition, terrain-mass, ground-contact, cross-fidelity,
repetition, LOD, interaction, and resource criteria replace vague polish
language and require the full independent PLAY-075 20/20 disposition.
