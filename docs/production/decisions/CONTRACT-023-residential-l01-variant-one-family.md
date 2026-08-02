# CONTRACT-023: Residential L1 variant-one directional family

**Status:** Approved for governed source production after publication

**Owner:** Integration

## Decision

CitySim will resolve the opening city's dominant adjacent residential
duplication with one genuinely distinct Residential L1 variant-one family,
authored independently for North, East, South, and West frontage. The solution
is source art, not a renderer-owned court, grove, facade overlay, recolor,
runtime transform, or prop-only disguise.

This contract extends CONTRACT-010, CONTRACT-018, CONTRACT-019, CONTRACT-020,
and CONTRACT-021. It changes no simulation, save, command, parcel, frontage,
camera, or gameplay contract.

## Family identity

The logical family key is:

```text
residential_l01/variant-1/<north|east|south|west>/<source-revision>
```

Variant one must remain recognizably Residential L1 while materially differing
from production variant zero in all of these ways:

- primary massing and roofline;
- road-facing entrance composition;
- facade rhythm and occupied silhouette;
- material-role balance and value structure; and
- at least one structural secondary volume visible at literal game scale.

Color shifts, landscaping, chimneys, signs, awnings, or small props do not
count as the required structural difference. No accepted source, normalized
pixel payload, packed rectangle, or geometry identity may alias variant zero,
another direction, another level, or another building type.

## Frozen geometry and presentation

All four directions retain the existing Residential L1 authoritative:

- one-tile 72 x 36 basis, footprint, pivot, contact polygon, and vertical
  envelope;
- direction-specific road-facing socket and entrance exclusion zone;
- 2:1 orthographic camera, northwest key light, and southeast contact shadow;
- city, neighborhood, block, native-2x, and literal-192 registration; and
- construction, condition, selection, overlay, and hit-test separation.

North freezes only the family vocabulary and appearance lock. East, South,
and West independently author their own road-facing massing and occlusion; no
sibling scene geometry, raster, mask, transform, or camera-facing facade layout
may be copied, mirrored, rotated, or derived.

## Parallel production gate

1. Integration publishes claims, a family-bound parallel validator, and a
   prelock six-row ledger.
2. North authors the hero design and one explicitly granted Process A.
3. East, South, and West concurrently author zero-pixel blockouts and
   socket/camera/scale proofs; Renderer prepares non-shipping intake; QA
   preregisters the exact fixture and rubric.
4. Independent frontier review either returns North or publishes the immutable
   appearance lock.
5. North B/C and East/South/West A/B/C run concurrently under exact grants.
6. Each direction is admitted and quarantined independently. A failure returns
   only that direction.
7. Renderer may activate variant one only after exact 4/4 admission and one
   atomic assembly. No partial fallback, transform, or variant-zero alias is
   permitted.
8. Independent frontier QA operates one exact staged candidate at regular and
   900 x 600 layouts across city, neighborhood, and block views.

## Deterministic runtime selection

Renderer selection uses stable logical identity, authoritative level, world
visual seed, and tile coordinate. Variant choice must be repeatable across
launch, save/load, replay, Undo, camera state, LOD transitions, and process
order. The opening fixture must select different variants for the currently
duplicated northwest adjacent pair while never changing its simulation state
or frontage.

## Acceptance

- Four independently authored, non-aliased directional sources pass three
  fresh-process decoded-RGBA identity, registration, alpha/chroma/padding,
  source/native-2x/literal-192 color and grayscale, provenance, and contact
  sheet gates.
- Variant one is recognizable as the same family but clearly distinct from
  variant zero within two seconds at regular and exact compact city,
  neighborhood, and block views.
- The northwest adjacent pair reads as an intentional mixed residential block,
  with no overlap, clipping, float, facade/socket drift, mixed-fidelity seam,
  or loss of pointer/keyboard/accessibility behavior.
- Production selection is atomic 4/4 and deterministic; missing or rejected
  sources fail explicitly rather than falling back.
- Full native, staged build/resource, performance, interaction, and independent
  real-app gates pass on one exact integrated candidate.

## Ownership and stop conditions

World Art owns direction-local source scenes, renders, provenance,
normalization, validators, and evidence. Renderer owns quarantine, atlas/runtime
mapping, deterministic selection, and staged assembly after source admission.
QA owns candidate-neutral preparation and the independent final disposition.
Integration alone owns this contract, claims, shared ledger, appearance lock,
source admission, production selection, integration, publication, and push.

Stop on stale identity, shared-file collision, sibling derivation, alias,
wrong frontage, source-scale failure, nondeterminism, ImageGen whole-building
composition, incomplete 4/4 activation, fallback, save/interaction drift,
mixed fidelity, or any attempt by a worker to self-accept, integrate, push, or
pin a task.
