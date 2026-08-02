# PLAY-073 R4-B Current-Master Implementation Addendum

**Status:** Integration-published frontier clarification

This addendum narrows the reconstruction authority after independent semantic
review of the returned candidate. It does not authorize more paths or broader
composition work.

## Frozen implementation details

1. Runtime context and the diagnostic placement ledger use the same
   deterministic material variant derived from current tile truth.
2. Visible variant counts are residential `4`, commercial `2`, industrial and
   service `3`, and civic/park `1`. Selection uses normalized modulo of
   `coordinate.x + coordinate.y`, so both east-west and north-south adjacent
   ordinary lots alternate whenever the family has a visible alternative.
3. Contact shadows and variant ground treatments are limited to residential,
   commercial, and industrial/service families. Do not add a second treatment
   beneath civic landmarks or parks.
4. Frontage treatment orientation must derive its perpendicular from a
   normalized road-socket vector. The returned candidate's raw-socket
   perpendicular multiplication is forbidden because it can place the swatch
   outside the authoritative lot.
5. Treatment geometry must remain inside the 72-by-36 lot diamond, remain
   ground-only, expose no label/action/hit-target semantics, and repeat
   deterministically.
6. Focused tests must cover east-west and north-south adjacent commercial
   pairs, compare actual geometry/position/fill rather than names alone, prove
   in-footprint bounds, and prove repeat identity.
7. Terrain tests retain the existing exact `121` patch assertion, add the exact
   three-region assertion, and prove repeated backdrops retain identical region
   geometry.

Do not import `ContextSignature`, the returned template-cache rewrite, the
continuous terrain texture, R4-A composition, or returned evidence metrics.
Fresh measurements belong to the reconstructed candidate.
