# PLAY-027 Industrial L4 Turbine Works translation authority

- Published concept packet on integration:
  `3e10a567a20aea8f5ab1b581bbacd90d3387a136`
- Original World Art concept commit:
  `c71bd191846ba7b99f24b658c3b8e7845164174f`
- Selected concept: `turbine-works`
- Integration disposition: `SELECT_TURBINE`
- Independent player-recognition disposition: `SELECT_TURBINE`
- Independent renderer-feasibility disposition: `SELECT_TURBINE`
- Owning lane: World art generation cell
- Current authority: pre-pixel directional translation only
- Raw source, normalization, renderer, and production authority: `false`

## Art direction

Industrial L4 is a wide, grounded advanced foundry, not another tower. Preserve
the Turbine Works identity in every separately authored direction:

- one long high-bay hall with a strong sawtooth or monitor-roof rhythm;
- one singular offset stack in the rear third, visibly secondary to the hall;
- three deep freight openings and a readable frontage apron;
- one distinct staff/control entrance in a low warm-masonry wing;
- an overhead gantry and turbine/process court that support, rather than break,
  the main silhouette;
- warm brick, dark blue-green or charcoal steel, oxidized machinery, restrained
  green, orange heat, believable glazing, roof plant, joints, stains, and deep
  service shadows.

Do not import pseudo-text, signage, detached concept noise, paired Riversteel
stacks, Atlas corporate-campus cleanliness, or Copperline's fragmented open
court. This is a single selected concept, not a hybrid.

## Directional and gameplay constraints

Author North, East, South, and West as independent scene descriptions. Never
mirror or rotate a sibling.

- Keep invariant building massing, scale, materials, light, and southeast
  contact shadow across all four views.
- Move the three freight openings and separate staff entrance to the
  authoritative road-facing edge in each direction.
- Fit the grounded mass inside the exact 56×56 footprint with a centered pivot
  and a visibly clear frontage apron.
- Keep the stack in the rear third and below the visual dominance of the broad
  hall.
- Freight openings must remain at least eight gameplay pixels wide in the
  compact proof.
- Block LOD must retain freight bays, gantry, staff entrance, and roof material.
- Neighborhood LOD must retain sawtooth rhythm, offset stack, control wing, and
  dark freight recesses.
- City LOD must retain the long hall, offset stack, and warm control-wing
  silhouette in grayscale.
- The eventual renderer representation remains one packed sprite node per LOD;
  twelve directional/LOD payloads must fit the existing atlas and 50.3 MiB
  residency limits.

## Authorized slice

World Art may now:

1. synchronize its clean branch to this published authority without rewriting
   preserved history;
2. author a new task-owned Turbine Works massing/material architecture for
   N/E/S/W;
3. create deterministic silhouette, frontage, pivot/socket, shadow, compact
   192×128, grayscale, and L3-versus-L4 differentiation validators;
4. preserve a four-direction pre-pixel review packet with exact scene and
   material hashes; and
5. commit one clean review candidate with `sourceAuthority=false` and
   `productionSelected=false`.

No raw source render or normalization process is authorized in this slice.
Stop after the pre-pixel packet for independent integration, renderer, and
player-recognition review.

## Return conditions

Return the slice if any direction:

- reads as a compact orthogonal tower or generic box;
- loses the broad-hall, offset-stack, and low-control-wing hierarchy;
- aliases another direction or accepted Industrial level;
- fragments the building at compact scale;
- obscures freight or staff frontage;
- exceeds the footprint, pivot, shadow, or atlas constraints; or
- relies on micro-detail to compensate for a weak silhouette.
